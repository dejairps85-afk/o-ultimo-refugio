# O Último Refúgio — protótipo Godot 4

Esta é a trilha nativa separada do projeto. A versão web existente permanece preservada e não é substituída por este protótipo.

## Abrir no Godot
1. Instale uma versão estável do Godot 4.
2. Baixe ou clone o repositório.
3. No Godot, importe a **raiz do repositório**, onde está o arquivo `project.godot`.
4. Abra e execute `godot/scenes/main.tscn`.

O projeto fica na raiz para que os recursos em `assets/` sejam importados como recursos nativos do Godot.

## Recursos já integrados
- Terreno procedural com relevo, colisão e textura PBR de solo (albedo, normal e roughness).
- Céu procedural, iluminação direcional, sombras, tonemapping e neblina atmosférica.
- Sobrevivente 3D GLB real, com ajuste automático aproximado de altura e busca de animações.
- Infectados GLB em três variantes (walker, runner e brute), perseguição com desvio local de árvores, rochas e tocos, dano e sistema simples de vida.
- Vegetação, árvores, rochas, samambaias e tocos usando modelos 3D do próprio repositório, com fallback procedural.
- Câmera em terceira pessoa, movimentação, salto, ataque e colisão do personagem.
- Controles de teclado para desenvolvimento e controles por toque, com botões de pulo e ataque.
- HUD com barra de vida e contagem de infectados vivos.

## Melhorias recentes
- O controle de movimento por toque agora usa um ponto de origem fixo durante o arraste, evitando que o movimento dependa apenas da velocidade do dedo.
- As animações do sobrevivente alternam entre movimento e repouso, e a animação de ataque tem duração controlada.
- O HUD contabiliza somente infectados vivos.
- Os infectados calculam uma direção de desvio quando se aproximam de obstáculos do cenário, reduzindo a tendência de caminhar diretamente através deles.

## Estado real do projeto
Este ainda é um protótipo técnico em evolução. A validação automatizada no GitHub Actions importa os recursos e executa a cena em modo headless; isso verifica erros de importação/execução, mas **não comprova a qualidade visual, o desempenho ou a jogabilidade em um aparelho**.

Ainda precisam de validação visual no editor e em dispositivo: orientação e escala final dos modelos, qualidade das animações, colisões dos infectados, colisões físicas e navegação completa dos infectados, áudio, otimização por hardware e interface adaptada a diferentes proporções de tela.

## Exportação
- Android: exige templates de exportação do Godot e Android SDK/JDK configurados.
- iOS: exige macOS, Xcode e configuração de assinatura Apple.
- Ainda não há APK, IPA ou build instalável publicado por este projeto.

O projeto usa Godot, um motor gratuito e open-source. Nenhuma alteração desta trilha é aplicada automaticamente à branch principal.
