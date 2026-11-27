// Teste de ponta a ponta da versão Web: abre o jogo num "iPhone" virtual (toque real via CDP),
// usa o joystick e a câmera, tira capturas REAIS e verifica que a imagem muda e não é preta.
import { chromium } from 'playwright';
import { PNG } from 'pngjs';
import fs from 'fs';

const OUT = process.argv[2] || 'build/web';
const W = 844, H = 390;
const browser = await chromium.launch({
  headless: true,
  args: ['--enable-webgl', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
const context = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, hasTouch: true, isMobile: true });
const page = await context.newPage();
const errors = [];
page.on('pageerror', e => errors.push('PAGE: ' + e.message));
page.on('console', m => { if (m.type() === 'error') errors.push('CONSOLE: ' + m.text()); });

const touch = async (cdp, type, points) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: points });
const luma = (png, x0, y0, x1, y1) => {
  let sum = 0, n = 0;
  for (let y = Math.floor(y0 * png.height); y < Math.floor(y1 * png.height); y += 4) {
    for (let x = Math.floor(x0 * png.width); x < Math.floor(x1 * png.width); x += 4) {
      const i = (png.width * y + x) << 2;
      sum += 0.2126 * png.data[i] + 0.7152 * png.data[i + 1] + 0.0722 * png.data[i + 2];
      n++;
    }
  }
  return sum / n;
};
const diffFraction = (a, b) => {
  let diff = 0, n = 0;
  for (let i = 0; i < a.data.length; i += 16) {
    n++;
    if (Math.abs(a.data[i] - b.data[i]) + Math.abs(a.data[i + 1] - b.data[i + 1]) + Math.abs(a.data[i + 2] - b.data[i + 2]) > 30) diff++;
  }
  return diff / n;
};

const problems = [];
try {
  await page.goto('http://127.0.0.1:8765/', { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(45000);
  const cdp = await context.newCDPSession(page);

  const beforeBuf = await page.screenshot();
  fs.writeFileSync(`${OUT}/ci-1-parado.png`, beforeBuf);

  // Joystick: dedo na metade esquerda, arrasta para cima (frente) e segura.
  await touch(cdp, 'touchStart', [{ x: 120, y: 280, id: 1 }]);
  await touch(cdp, 'touchMove', [{ x: 120, y: 235, id: 1 }]);
  await page.waitForTimeout(8000);
  const walkBuf = await page.screenshot();
  fs.writeFileSync(`${OUT}/ci-2-andando.png`, walkBuf);

  // Segundo dedo ao mesmo tempo: gira a câmera (multitoque) com o joystick ainda ativo.
  await touch(cdp, 'touchStart', [{ x: 120, y: 235, id: 1 }, { x: 600, y: 150, id: 2 }]);
  for (let i = 1; i <= 10; i++) {
    await touch(cdp, 'touchMove', [{ x: 120, y: 235, id: 1 }, { x: 600 - i * 30, y: 150, id: 2 }]);
    await page.waitForTimeout(100);
  }
  await page.waitForTimeout(3000);
  const turnBuf = await page.screenshot();
  fs.writeFileSync(`${OUT}/ci-3-camera-girada.png`, turnBuf);
  await touch(cdp, 'touchEnd', []);

  const before = PNG.sync.read(beforeBuf);
  const walk = PNG.sync.read(walkBuf);
  const turn = PNG.sync.read(turnBuf);
  const groundLuma = luma(before, 0.30, 0.68, 0.70, 0.90);
  const skyLuma = luma(before, 0.30, 0.02, 0.70, 0.25);
  const moved = diffFraction(before, walk);
  const turned = diffFraction(walk, turn);
  console.log('WEB_METRICS=' + JSON.stringify({ groundLuma, skyLuma, moved, turned, errors }));

  if (groundLuma < 22) problems.push(`Terreno parece preto (luminância ${groundLuma.toFixed(1)}).`);
  if (moved < 0.02) problems.push(`A imagem quase não mudou ao usar o joystick (${(moved * 100).toFixed(2)}% dos pixels).`);
  if (turned < 0.05) problems.push(`A câmera não mudou a imagem com o segundo dedo (${(turned * 100).toFixed(2)}%).`);
  if (errors.some(e => /wasm|webgl|uncaught|failed to load|cannot open file|failed loading|script error|parse error|out of memory/i.test(e))) {
    problems.push('Erros no navegador: ' + errors.slice(0, 5).join(' | '));
  }
} finally {
  await browser.close();
}
if (problems.length) {
  console.log('WEB_TEST: FAIL\n- ' + problems.join('\n- '));
  process.exit(1);
}
console.log('WEB_TEST: PASS');
