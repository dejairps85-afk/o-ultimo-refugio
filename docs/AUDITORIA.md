# Auditoria técnica — O Último Refúgio

Data: 2026-11-27. Base auditada: `feature/next-gen-rebuild` (commit `6d2c3f6`).
Legenda: **[LIDO]** confirmado lendo o código/arquivos · **[HIPÓTESE]** plausível, ainda não comprovado em execução.

## O que NÃO foi possível fazer nesta auditoria
- Não rodei o Godot nem vi o jogo renderizado (o ambiente da auditoria não tem o Godot nem acesso à rede para baixá-lo). Tudo abaixo vem de leitura do código.
- Por isso nada aqui é declarado "funcionando". A prova será o workflow `core-validation.yml` (playtest + capturas reais).

## Achados

### 1. A versão publicada pode não ser a que você está testando [LIDO + HIPÓTESE]
- `web-build.yml` só dispara em *push* na branch `feature/godot-mobile-prototype`. Pushes em `feature/next-gen-rebuild` **não publicam** nada no GitHub Pages (só com execução manual).
- Hipótese: boa parte das "correções" recentes (câmera, joystick, terreno) nunca chegou ao seu iPhone, e você continuou testando uma build antiga. Confirmar: Actions → qual execução do "Gerar versão Web" gerou o Pages atual.

### 2. Arquitetura: um arquivo de 4.151 linhas [LIDO]
- `godot/scripts/main.gd` contém terreno, rio, barco, cidade, HUD, loja, IA, veículos, alienígenas, save etc. num único script, um único `_physics_process` de ~150 linhas que mistura câmera, combate, ondas, IA aliada e movimento.
- Impossível testar partes isoladas; qualquer bug de movimento é difícil de achar. Conclusão: não vale remendar; o núcleo precisa ser separado.

### 3. Movimento e joystick [LIDO]
- O joystick só inicia se o dedo tocar **dentro de 92 px** do centro de um botão fixo; qualquer toque um pouco fora é tratado como "olhar" ou ignorado. Em iPhone, com dedo grande, isso falha com frequência.
- O código do personagem gira o próprio `CharacterBody3D` (`player.rotation.y = lerp_angle(...)`) enquanto câmera, ataque, esquiva e IA aliada leem `player.global_transform.basis`. Muitos sistemas dependem da rotação do corpo que o input está alterando. É o tipo de acoplamento que gera "girar sem sair do lugar".
- A causa exata do giro **não foi comprovada** (precisaria rodar). No novo núcleo ela é eliminada por construção: o corpo nunca gira, só o visual, e o alvo de giro vem do input + yaw da câmera.

### 4. Tela [LIDO]
- `project.godot` usa `stretch/mode=canvas_items` com 1280×720 e **sem** `stretch/aspect=expand` → no iPhone (tela mais larga que 16:9) aparecem as **faixas pretas**. Corrigido na nova branch.

### 5. Modelos 3D [LIDO]
- Todos os `.glb` usam `EXT_meshopt_compression` + `KHR_mesh_quantization`. O importador do Godot 4.4 não lê isso diretamente; o CI contorna normalizando com `gltf-transform` só durante o build. Se alguém importar os arquivos como estão, os modelos falham.
- `tree_small_02_mobile.glb` tem **~6 MB** (nome "mobile" engana) — pesado para iPhone via navegador.
- Personagem: `survivor-soldier.glb` (CC BY 4.0, vinish.dev), com Idle/Walk/Run. É um modelo genérico, não "cinematográfico". Zumbis têm Attack/Hit/Death/Scream (úteis depois).

### 6. Terreno preto [LIDO + HIPÓTESE]
- O sentido dos triângulos do terreno está correto hoje (verifiquei o produto vetorial: faces voltadas para cima na convenção horária do Godot) e as normais estão coerentes. Então o "preto" provavelmente vinha de build antiga (achado 1), de textura/normal não carregada, ou de iluminação. **Não comprovado.**
- O novo teste web mede a luminância do chão em capturas reais e reprova se for preto.

### 7. Texturas ambientCG [LIDO]
- `Concrete012` e `Asphalt033` estão no repositório (Color, NormalGL, Roughness). Sem mapa metálico (não necessário para concreto/asfalto). São usadas no novo núcleo com mapeamento triplanar.

### 8. Testes existentes [LIDO]
- Os workflows validam importação e "o canvas existe". Não testam movimento, câmera, colisão nem se a imagem não é preta — por isso passavam enquanto o jogo estava quebrado no iPhone.

## Engine: Godot ou Unity?
Recomendação: **ficar no Godot 4.4**, por ora.
- Grátis, sem royalties; exporta Web/Android/iOS; compila inteiro no GitHub Actions (sem computador).
- Unity exigiria licença/serviços, builds iOS exigem macOS/Xcode (runner pago) e o fluxo remoto pelo iPhone seria bem pior.
- Limite honesto: o Godot não alcança o visual de GTA V/TLOU em celular. O ganho real virá de arte (modelos, materiais, luz) e escopo pequeno, não de trocar de engine.

## Novo núcleo (esta branch)
`core/` — scripts pequenos e testáveis: `player_controller`, `camera_rig` (SpringArm3D, independente do personagem), `touch_hud` (joystick flutuante + olhar + botões, multitoque por índice), `pbr`, `model_util`, `demo_world` (rua abandonada).
Fica **preservado** o código antigo em `godot/` (não foi alterado).

### Estado
| Item | Estado |
|---|---|
| Movimento relativo à câmera, sem girar o corpo | Escrito; **sem prova de execução ainda** |
| Câmera 3ª pessoa independente, anti-atravessar | Escrito; sem prova |
| Joystick flutuante + olhar + botões multitoque | Escrito; sem prova |
| Colisão com prédios/carros/postes | Escrito; sem prova |
| Rua com PBR, luz de fim de tarde, vegetação GLB | Escrito; **qualidade visual desconhecida** |
| Terreno com relevo | **Não feito** (chão plano de propósito) |
| Animações Idle/Walk/Run | Ligadas; transições simples |
| Veículos, combate, IA, sobrevivência | **Não reintegrados** (fase 4) |

### Como a prova será feita
`.github/workflows/core-validation.yml`:
1. Godot headless injeta toques reais e verifica: andar, direção, não girar, câmera, multitoque, pulo, colisão (`PLAYTEST: PASS/FAIL`).
2. Exporta Web e roda num "iPhone" virtual (toque via CDP), salvando capturas **reais** (`capturas-reais`) e reprovando se o chão for preto ou a imagem não mudar.
3. Opcional: `deploy=true` publica no Pages para você testar no iPhone.

### Limitações conhecidas do CI
- WebGL no CI usa renderização por software (SwiftShader): serve para detectar "preto/quebrado", **não** para avaliar desempenho nem beleza final no iPhone.
- `MODEL_YAW_OFFSET` em `player_controller.gd` pode precisar de ajuste (se o personagem andar de costas).
