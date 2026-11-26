# O Último Refúgio — protótipo Godot 4

Esta pasta inicia uma trilha nativa separada para Android/iOS. O jogo web existente permanece intacto.

## Abrir
1. Instale Godot 4.x (versão estável).
2. Importe a pasta `godot/` como projeto existente.
3. Execute `scenes/main.tscn`.

## O que este primeiro marco contém
- Mundo 3D procedural com relevo e iluminação direcional com sombras.
- Sobrevivente em terceira pessoa, colisão, gravidade, salto e movimentação.
- Controles de teclado para desenvolvimento e controles de toque para celular.
- Botões de pulo e ataque na interface.
- Carregamento opcional dos modelos GLB já presentes no repositório (árvore, rochas e samambaia), com fallback procedural.

## Estado e limitações
Este é um protótipo técnico inicial, não uma versão final nem um build Android/iOS. O personagem ainda usa malha provisória; animações, combate funcional, inventário, áudio, otimização por dispositivo e integração completa dos sistemas do jogo web serão etapas seguintes. Os modelos GLB do projeto web precisam ser validados no importador Godot antes de considerar o conteúdo final.

## Exportação mobile
A exportação Android exige os templates de exportação do Godot e SDK/JDK configurados. A exportação iOS requer macOS e Xcode. Nenhum custo de licença do motor é cobrado.
