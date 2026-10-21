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
- **Conexões (match geossocial, H3)**: cartas no estilo do Tinder com quem frequenta os mesmos locais. A afinidade combina o Jaccard ponderado das visitas por local (70%) com o Jaccard dos "gostos de rolê" (30%). A fila alterna uma sugestão por afinidade e uma sorteada (grupo controle), e cada decisão guarda a fonte, para comparar a reciprocidade das duas no TCC. Curtida recíproca vira match. A carta mostra o que vocês têm em comum, não a nota.
- **Perfil com foto, bio e gostos de rolê** (até 8). A foto pode ser escolhida já no cadastro e aparece nos posts, stories e respostas. O perfil tem capa, cartões de números, gostos de rolê e "Onde mais vou" (locais com mais check-ins). A grade mostra só posts com foto ou vídeo, e a lista só os de texto.
- **Busca** por pessoas (nome, @, bio e gostos) e por posts com foto ou vídeo (texto, autor e local marcado), sem diferença de acentos ou maiúsculas. Posts só de texto ficam no feed.
- **Perfis de demonstração** (`tools/demo_profiles/`): seis pessoas fictícias, com avatar, bio, gostos, visitas e posts, criadas no Firebase para o app não parecer vazio. Precisam ser removidas antes do teste de campo.
- **Coleta de dados do experimento** (só com consentimento, no ícone de frasco do perfil): transições de geocerca e check-ins, qualidade do GPS, quadros do mapa, bateria por estado do app, modelo do aparelho e tempo do mapa até escolher um local. Nada de coordenadas. Os eventos sobem em lotes a cada 5 minutos e funcionam offline. O **diário de campo** ("Cheguei agora" / "Saí agora", também no mapa) é o gabarito para medir o acerto das geocercas. O participante pode sair e apagar os dados a qualquer momento.
- **Exportação para o TCC** (`tools/experiment_export/`): baixa os dados, pseudonimiza (P01, P02...) e gera CSVs e um resumo das hipóteses H1 a H4.

## Estrutura principal

- `lib/models/` — `User`, `Posts`, `Reply`, `Story`, `MediaRef`/`MediaDraft`, `Venue` (local + geocerca), `CheckIn` e `Swipe`/`UserMatch`
- `lib/data/` — camada de dados:
  - `repositories.dart` — contratos (auth, usuários, presença, posts, stories, mídia) e os limites de mídia
  - `firebase/` — implementação com Firebase Auth + Cloud Firestore (estrutura do banco no topo dos arquivos)
  - `mock/` — implementação em memória, com lotação simulada (testes, Windows e demonstração offline)
  - `venue_catalog.dart` — locais monitorados e suas geocercas
  - `interest_catalog.dart` — os "gostos de rolê" do perfil
- `lib/services/` — lógica em Dart puro, testável sem aparelho:
  - `geo.dart` — distância pela fórmula de Haversine
  - `geofence_engine.dart` — máquina de estados das geocercas (enter/dwell/exit)
  - `kernel_density.dart` — estimativa de densidade por kernel (KDE) do mapa de calor
  - `location_service.dart` — GPS real e posição simulada
  - `media_chunks.dart` — divide fotos/vídeos em pedaços para o Firestore
  - `media_drafts.dart` — galeria, compressão de fotos e limites de vídeo
  - `crowd_simulator.dart` — lotação simulada do modo mock
  - `affinity.dart` — afinidade entre pessoas e a fila de sugestões das Conexões
  - `frame_stats.dart` — resumo do tempo de quadro do mapa (H4)
- `lib/providers/` — estado do app (`AuthProvider`, `PostsProvider`, `StoriesProvider`, `VenuesProvider`, `PresenceProvider`, `MatchProvider`, `ExperimentProvider`, `MediaLoader`)
- `lib/view/` — telas: `auth_gate.dart`, `compose_screen.dart` (novo post), `camera_screen.dart`, `story_viewer.dart`, `post_detail_screen.dart` (respostas), `edit_profile_screen.dart`, `user_profile_screen.dart`, `matches_screen.dart`, `experiment_screen.dart` (consentimento e diário de campo); `screen/` — abas; `widgets/` — post, stories, mídia, avatar e mapa de calor
- `firestore.rules` — regras de segurança do banco; `firestore_tests/` — testes dessas regras no emulador
- `test/` — testes de Haversine, geocercas, KDE, mídia, afinidade, quadros, conexões, coleta do experimento e da camada de dados (`flutter test`)
- `tools/experiment_export/` — exportação e análise dos dados do teste de campo (Node; veja o README da pasta)
- `tools/demo_profiles/` — cria e remove os perfis de demonstração no Firebase (Node; veja o README da pasta)
- `assets/` — imagens e recursos visuais

## Como testar

1. Rode o app em modo debug e entre: no Firebase, crie uma conta pelo app; no modo mock, use `demo@onrole.com` / `123456`.
2. **Post:** toque em "O que tá rolando?" (ou no lápis), escreva, adicione fotos/vídeos e, se quiser, um local. Toque num post para ver e escrever respostas.
3. **Story:** toque no "+" de "Seu story", tire uma foto (toque) ou grave um vídeo (segure), e publique.
4. **Selo "no rolê agora":** na aba **Mapa**, ligue o **modo simulação** (botão laranja) e toque dentro de um local. Em ~10 s o check-in é confirmado; o próximo post ou story já vem com o local e o selo.
5. **Conexões:** em **Perfil → Editar perfil**, escolha foto, bio e gostos de rolê. Na aba **Conexões**, arraste a carta para a direita (curtir) ou para a esquerda (passar). No modo mock, a Ana já curtiu a conta demo: curtindo de volta, sai um match.
6. **Experimento:** toda conta nova recebe o convite logo depois do cadastro, e ele só fecha com "Agora não" ou "Aceito participar". Depois, dá para entrar ou sair no ícone de frasco do **Perfil**. O mapa ganha o botão do diário de campo. Em "Enviar agora" os eventos sobem na hora.

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

## Teste de campo

1. Instale a build **release** nos celulares dos participantes (`flutter build apk --release`). Nela o modo simulação e o GPS falso ficam desligados.
2. Cada participante cria a conta e aceita o convite do experimento, que aparece logo depois do cadastro. Quem recusar por engano pode entrar depois no ícone de frasco do perfil. Durante o teste, toca em "Cheguei agora" e "Saí agora" no diário de campo ao chegar e sair de cada local.
3. Depois, exporte os dados com `tools/experiment_export` (instruções no README da pasta). Use `--since` com a data de início para deixar os testes piloto de fora.

## Observações

- Para imagens, use caminhos relativos e garanta que estejam declaradas no `pubspec.yaml`.
- Para telas com teclado, prefira conteúdo rolável para evitar overflow.
- **Locais monitorados:** 11 estabelecimentos reais de Colatina, de acesso público e sem parceria nem patrocínio, em `lib/data/venue_catalog.dart`. O app mostra só nome, tipo e localização. O raio da geocerca segue o tamanho do local: 50 m para pequeno, 75 m para médio e 120 m para grande. Espetinho do Denis e DJ PUB ficam a 44 m um do outro, e o Bharem fica dentro da cerca da Área Verde. Nesses casos o check-in vai para o local mais próximo e troca quando a pessoa passa 2 minutos mais perto do vizinho. Vale conferir no próprio local, antes do teste, se o check-in dispara na porta. A lotação do modo mock é inventada.
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
- [x] Testar posts com vídeo e stories num celular real (câmera, microfone e o tamanho real dos vídeos gravados).
- [ ] Seguir pessoas (hoje o feed mostra todo mundo) e notificações de curtidas/respostas.
- [ ] Geofencing em segundo plano (check-in com o app fechado).
- [x] Match geossocial por afinidade de locais e gostos (Jaccard), com grupo controle para a H3.
- [x] Coleta de métricas do experimento (geocercas x diário de campo, GPS, quadros, bateria) e exportação pseudonimizada.
- [x] Publicar as regras novas do Firestore (`firebase deploy --only firestore`) antes do teste de campo.
- [x] Trocar os locais de demonstração por estabelecimentos reais de Colatina.
- [ ] Remover os perfis de demonstração antes do teste de campo (`node tools/demo_profiles/remove.js`), para não distorcer a H3.
- [ ] Conferir em cada local se o check-in dispara na porta, principalmente no Espetinho do Denis e no DJ PUB.
- [ ] Questionário TAM com os participantes depois do teste.
- [ ] Testar em aparelho Android real, andando até um local.
