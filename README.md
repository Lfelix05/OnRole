# OnRolê

OnRolê: Onde o pulso da cidade acontece.

O OnRolê é a fusão entre geolocalização e rede social, criada para quem não quer perder tempo em lugares vazios ou sem energia. Com um mapa interativo em tempo real, o app mostra os pontos mais movimentados da cidade por meio de ícones dinâmicos que ganham vida conforme a galera chega.

## O que o OnRolê faz por você

- **Mapa de Calor Social**: Visualize instantaneamente quais bares, festas e picos estão com mais movimento sem precisar clicar em nada.
- **Feed em Tempo Real**: Veja o que está acontecendo agora através de fotos e vídeos curtos postados por quem já está lá. É o “Instagram do agora”.
- **Check-in Inteligente**: Com tecnologia de geofencing, o app detecta sua presença no local, permitindo que você valide o rolê e compartilhe a vibe com seus seguidores automaticamente.
- **Conexão Tinder-Style**: Descubra quem são as pessoas que frequentam os mesmos tipos de lugares que você e faça novas conexões baseadas nos seus picos favoritos.

## Status do app (atual)

- Telas de boas-vindas, login, cadastro, feed, mapa, busca e perfil.
- **Back-end no Firebase** (projeto `onrole-tcc`), só no plano gratuito: login por e-mail, perfis, presença, check-ins, posts, stories e mídia no Cloud Firestore (São Paulo), em tempo real. O login fica salvo entre aberturas do app.
- **Feed no estilo do Threads**: qualquer pessoa logada posta texto e até 4 fotos/vídeos, para combinar rolês, chamar a galera e avisar de eventos. Tem curtidas, respostas e local opcional. Os posts ficam, e o feed mostra os mais recentes primeiro.
- **Stories no estilo do Instagram** no topo do feed: foto ou vídeo que some em 24 h, com anel colorido para os não vistos.
- **Câmera do app**: toque para foto, segure para vídeo (até 15 s, em 480p, para caber no banco gratuito). Também dá para escolher da galeria.
- **Selo "no rolê agora"**: quem tem check-in ativo num local pode marcar o post/story com esse selo, verificado pelo servidor (H2). Ninguém precisa de check-in para postar.
- **Mapa real de Colatina** (OpenStreetMap com filtro escuro) com **mapa de calor por KDE** e lotação real de cada local (quantas pessoas têm check-in ativo agora).
- **Localização por GPS** (`geolocator`) e **check-in automático por geocerca**: entrada, permanência mínima (dwell) e saída, com histerese e descarte de leituras imprecisas.
- **Modo simulação** (só em builds de depuração) para testar o check-in sem sair de casa.

## Estrutura principal

- `lib/models/` — `User`, `Posts`, `Reply`, `Story`, `MediaRef`/`MediaDraft`, `Venue` (local + geocerca) e `CheckIn`
- `lib/data/` — camada de dados:
  - `repositories.dart` — contratos (auth, usuários, presença, posts, stories, mídia) e os limites de mídia
  - `firebase/` — implementação com Firebase Auth + Cloud Firestore (estrutura do banco no topo dos arquivos)
  - `mock/` — implementação em memória, com lotação simulada (testes, Windows e demonstração offline)
  - `venue_catalog.dart` — locais monitorados e suas geocercas
- `lib/services/` — lógica em Dart puro, testável sem aparelho:
  - `geo.dart` — distância pela fórmula de Haversine
  - `geofence_engine.dart` — máquina de estados das geocercas (enter/dwell/exit)
  - `kernel_density.dart` — estimativa de densidade por kernel (KDE) do mapa de calor
  - `location_service.dart` — GPS real e posição simulada
  - `media_chunks.dart` — divide fotos/vídeos em pedaços para o Firestore
  - `media_drafts.dart` — galeria, compressão de fotos e limites de vídeo
  - `crowd_simulator.dart` — lotação simulada do modo mock
- `lib/providers/` — estado do app (`AuthProvider`, `PostsProvider`, `StoriesProvider`, `VenuesProvider`, `PresenceProvider`, `MediaLoader`)
- `lib/view/` — telas: `auth_gate.dart`, `compose_screen.dart` (novo post), `camera_screen.dart`, `story_viewer.dart`, `post_detail_screen.dart` (respostas); `screen/` — abas; `widgets/` — post, stories, mídia e mapa de calor
- `firestore.rules` — regras de segurança do banco; `firestore_tests/` — testes dessas regras no emulador
- `test/` — testes de Haversine, geocercas, KDE, mídia e da camada de dados (`flutter test`)
- `assets/` — imagens e recursos visuais

## Como testar

1. Rode o app em modo debug e entre: no Firebase, crie uma conta pelo app; no modo mock, use `demo@onrole.com` / `123456`.
2. **Post:** toque em "O que tá rolando?" (ou no lápis), escreva, adicione fotos/vídeos e, se quiser, um local. Toque num post para ver e escrever respostas.
3. **Story:** toque no "+" de "Seu story", tire uma foto (toque) ou grave um vídeo (segure), e publique.
4. **Selo "no rolê agora":** na aba **Mapa**, ligue o **modo simulação** (botão laranja) e toque dentro de um local. Em ~10 s o check-in é confirmado; o próximo post ou story já vem com o local e o selo.

Parâmetros das geocercas (em `GeofenceConfig`; são variáveis do experimento de campo):

| | Permanência mínima | Confirmação de saída | Histerese | Precisão máxima |
|---|---|---|---|---|
| GPS real | 2 min | 60 s | 25 m | 60 m |
| Simulação | 10 s | 5 s | 15 m | 60 m |

## Como executar

1. Instale o Flutter e configure o ambiente.
2. Baixe as dependências:

	```bash
	flutter pub get
	```

3. Execute o app (os comandos rodam dentro de `on_role/`):

	```bash
	flutter run                              # Android/Web com Firebase
	flutter run --dart-define=BACKEND=mock   # sem Firebase: dados de demonstração em memória
	```

	Em plataformas sem Firebase configurado (ex.: Windows), o app usa o modo mock automaticamente.

4. Rode os testes:

	```bash
	flutter test
	```

5. Testes das regras de segurança (emulador local, precisa de Java; não toca o banco real):

	```bash
	npm --prefix firestore_tests install
	firebase emulators:exec --only firestore --project demo-onrole "npm --prefix firestore_tests test"
	```

## Observações

- Para imagens, use caminhos relativos e garanta que estejam declaradas no `pubspec.yaml`.
- Para telas com teclado, prefira conteúdo rolável para evitar overflow.
- **Locais de demonstração:** as praças e a Área de Eventos são espaços públicos com coordenadas do OpenStreetMap. Os bares (Boteco Central, Lounge Beira-Rio, Esquina do Chopp) são fictícios. Troque-os pelos 5 estabelecimentos parceiros em `lib/data/venue_catalog.dart`, com coordenadas medidas no local.
- **Tiles do mapa:** vêm do servidor público do OpenStreetMap, dentro da [política de uso](https://operations.osmfoundation.org/policies/tiles/) (ok para protótipo e teste com poucos usuários). A CARTO passou a exigir chave de API. Para um estilo escuro "de verdade" ou para escalar, troque `_tileUrl` em `map_screen.dart` por um provedor com chave (CARTO, Stadia, MapTiler).
- **Privacidade:** coordenadas nunca saem do aparelho. O servidor só conhece o local do check-in, o mapa de calor usa contagens por local (`HeatPoint`), e presenças sem renovação por 15 min deixam de contar.
- O modo simulação e as posições de apps de "GPS falso" só são aceitos em builds de depuração. Use build release/profile no teste de campo.
- **Fotos e vídeos sem plano pago:** o Cloud Storage do Firebase exige o plano Blaze, então a mídia fica no próprio Firestore (`media/{id}` + pedaços de até 900 KB em `media/{id}/chunks`). Limites: 10 MB por arquivo, 4 por post; vídeo gravado no app até 15 s em 480p (~3-5 MB), da galeria até 60 s. O app lê a mídia primeiro do cache do aparelho e só baixa vídeos do feed quando a pessoa toca no play, para poupar a cota gratuita (1 GB guardado, 10 GB/mês de download). Stories vencidos e suas mídias são apagados pelo próprio autor ao abrir o app (a exclusão automática, TTL, também é do plano pago).

## Próximos passos

- [x] Mapa com heatmap (KDE) e lotação atualizada periodicamente (simulada).
- [x] Check-in automático com geofencing (app aberto).
- [x] Back-end no Firebase (Auth + Firestore) com regras de segurança testadas no emulador.
- [x] Ativar o login por e-mail no console do Firebase (Authentication > Get started > Email/Password).
- [x] Feed no estilo Threads (texto, fotos, vídeos, curtidas, respostas) aberto a todos, com selo "no rolê agora".
- [x] Stories de 24 h com câmera no app.
- [ ] Testar posts com vídeo e stories num celular real (câmera, microfone e o tamanho real dos vídeos gravados).
- [ ] Seguir pessoas (hoje o feed mostra todo mundo) e notificações de curtidas/respostas.
- [ ] Geofencing em segundo plano (check-in com o app fechado).
- [ ] Match geossocial por afinidade de locais (ex.: similaridade de Jaccard dos históricos de check-in).
- [ ] Coleta de métricas do experimento: exportar o log de eventos das geocercas (`PresenceProvider.events`), FPS e consumo de bateria.
- [ ] Testar em aparelho Android real, andando até um local.
