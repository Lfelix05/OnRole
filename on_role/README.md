# OnRolê

OnRolê: Onde o pulso da cidade acontece.

O OnRolê é a fusão entre geolocalização e rede social, criada para quem não quer perder tempo em lugares vazios ou sem energia. Com um mapa interativo em tempo real, o app mostra os pontos mais movimentados da cidade por meio de ícones dinâmicos que ganham vida conforme a galera chega.

## O que o OnRolê faz por você

- **Mapa de Calor Social**: Visualize instantaneamente quais bares, festas e picos estão com mais movimento sem precisar clicar em nada.
- **Feed em Tempo Real**: Veja o que está acontecendo agora através de fotos e vídeos curtos postados por quem já está lá. É o “Instagram do agora”.
- **Check-in Inteligente**: Com tecnologia de geofencing, o app detecta sua presença no local, permitindo que você valide o rolê e compartilhe a vibe com seus seguidores automaticamente.
- **Conexão Tinder-Style**: Descubra quem são as pessoas que frequentam os mesmos tipos de lugares que você e faça novas conexões baseadas nos seus picos favoritos.

## Status do app (atual)

- Telas iniciais em Flutter com layout, fundo e navegação inferior.
- Estrutura pronta para evoluir as telas: Início, Mapa, Procurar e Perfil.

## Estrutura principal

- `lib/view/` — telas do app
- `lib/view/screen/` — widgets reutilizáveis (ex.: background)
- `assets/` — imagens e recursos visuais

## Como executar

1. Instale o Flutter e configure o ambiente.
2. Baixe as dependências:

	```bash
	flutter pub get
	```

3. Execute o app:

	```bash
	flutter run
	```

## Observações

- Para imagens, use caminhos relativos e garanta que estejam declaradas no `pubspec.yaml`.
- Para telas com teclado, prefira conteúdo rolável para evitar overflow.

## Próximos passos

- Implementar mapa com heatmap em tempo real.
- Adicionar feed com posts curtos (foto/vídeo).
- Criar check-in inteligente com geofencing.
- Implementar o sistema de conexões por afinidade de lugares.
