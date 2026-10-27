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
- **Versão de demonstração** (`MODE=demo`), a que vai para quem avalia o app: sem conta, sem localização e sem Firebase. Mapa de calor, feed e Conexões usam pessoas e check-ins sintéticos, e nada sai do aparelho. Veja [docs/protocolo_experimento.md](docs/protocolo_experimento.md).
- **Bancada de testes** (`MODE=bancada`, só para o pesquisador): mede a precisão das geocercas (H2) com trajetos sintéticos de gabarito conhecido, e os quadros do mapa e a bateria (H4) repetindo um trajeto em tempo real.
- **Conexões (match geossocial, H3)**, só na demonstração: cartas no estilo do Tinder com quem frequenta os mesmos locais. A afinidade combina o Jaccard ponderado das visitas por local (70%) com o Jaccard dos "gostos de rolê" (30%). A fila alterna uma sugestão por afinidade e uma sorteada (grupo controle), e cada decisão guarda a fonte, para comparar a reciprocidade das duas no TCC. Curtida recíproca vira match. A carta mostra o que vocês têm em comum, não a nota.
- **Perfil com foto, bio e gostos de rolê** (até 8). A foto pode ser escolhida já no cadastro e aparece nos posts, stories e respostas. O perfil tem capa, cartões de números, gostos de rolê e "Onde mais vou" (locais com mais check-ins). A grade mostra só posts com foto ou vídeo, e a lista só os de texto.
- **Busca** por pessoas (nome, @, bio e gostos) e por posts com foto ou vídeo (texto, autor e local marcado), sem diferença de acentos ou maiúsculas. Posts só de texto ficam no feed.
- **Perfis de demonstração** (`tools/demo_profiles/`): seis pessoas fictícias, com avatar, bio, gostos, visitas e posts, criadas no Firebase para o app completo não parecer vazio.
- **Experimento anônimo**: o app não coleta dados de participantes. A antiga coleta de campo (telemetria, diário de campo e exportação pseudonimizada) foi removida, e `tools/purge_experiment/` apaga o que ela deixou no Firebase.

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
  - `check_in_tracker.dart` — decide onde está o check-in a partir das transições das geocercas (o app e a bancada usam o mesmo)
  - `crowd_simulator.dart` — lotação do modo mock e a `SyntheticCrowd` da demonstração (check-ins de uma população sintética)
  - `synthetic_population.dart` — pessoas e posts fictícios da demonstração
  - `synthetic_trajectories.dart` — trajetos sintéticos com modelo de erro do GPS e gabarito
  - `geofence_benchmark.dart` — compara os check-ins com o gabarito (H2)
  - `affinity.dart` — afinidade entre pessoas e a fila de sugestões das Conexões
  - `frame_stats.dart` — resumo do tempo de quadro do mapa (H4)
- `lib/app_mode.dart` — app completo, demonstração ou bancada (`--dart-define=MODE=...`)
- `lib/providers/` — estado do app (`AuthProvider`, `PostsProvider`, `StoriesProvider`, `VenuesProvider`, `PresenceProvider`, `MatchProvider`, `BenchProvider`, `MediaLoader`)
- `lib/view/` — telas: `auth_gate.dart`, `compose_screen.dart` (novo post), `camera_screen.dart`, `story_viewer.dart`, `post_detail_screen.dart` (respostas), `edit_profile_screen.dart`, `user_profile_screen.dart`, `matches_screen.dart`, `bench_screen.dart` (bancada de testes); `screen/` — abas; `widgets/` — post, stories, mídia, avatar e mapa de calor
- `firestore.rules` — regras de segurança do banco; `firestore_tests/` — testes dessas regras no emulador
- `test/` — testes de Haversine, geocercas, KDE, mídia, afinidade, conexões, dados sintéticos, bancada e da camada de dados (`flutter test`)
- `tools/geofence_bench.dart` — bancada de precisão das geocercas na linha de comando
- `tools/purge_experiment/` — apaga do Firebase os dados da antiga coleta de campo (Node; veja o README da pasta)
- `tools/demo_profiles/` — cria e remove os perfis de demonstração no Firebase (Node; veja o README da pasta)
- `../docs/protocolo_experimento.md` — desenho anônimo do experimento e questionário
- `assets/` — imagens e recursos visuais

## Como testar

1. Rode o app em modo debug e entre: no Firebase, crie uma conta pelo app; no modo mock, use `demo@onrole.com` / `123456`.
2. **Post:** toque em "O que tá rolando?" (ou no lápis), escreva, adicione fotos/vídeos e, se quiser, um local. Toque num post para ver e escrever respostas.
3. **Story:** toque no "+" de "Seu story", tire uma foto (toque) ou grave um vídeo (segure), e publique.
4. **Selo "no rolê agora":** na aba **Mapa**, ligue o **modo simulação** (botão laranja) e toque dentro de um local. Em ~10 s o check-in é confirmado; o próximo post ou story já vem com o local e o selo.
5. **Demonstração e Conexões:** rode com `--dart-define=MODE=demo` e toque em "Explorar a demonstração". Na aba **Conexões**, arraste a carta para a direita (curtir) ou para a esquerda (passar). Parte das pessoas sintéticas já curtiu o visitante, então curtindo de volta pode sair um match.
6. **Bancada:** rode com `--dart-define=MODE=bancada` e abra **Perfil → frasco**. Também dá para medir a precisão sem aparelho: `dart run tools/geofence_bench.dart --nights 1000`.

Parâmetros das geocercas (em `GeofenceConfig`), escolhidos na bancada de trajetos sintéticos:

| | Permanência mínima | Confirmação de saída | Histerese | Detecção de parada | Precisão máxima |
|---|---|---|---|---|---|
| GPS real | 3 min | 60 s | 25 m | 30 m | 60 m |
| Simulação | 10 s | 5 s | 15 m | não | 60 m |

A **detecção de parada** faz a permanência contar só enquanto a pessoa está parada, isto é, com as leituras a até 30 m da média das anteriores. Sem ela, atravessar uma cerca grande andando (ex.: a Área Verde, de 120 m) já fazia check-in.

## Como executar

1. Instale o Flutter e configure o ambiente.
2. Baixe as dependências:

	```bash
	flutter pub get
	```

3. Execute o app (os comandos rodam dentro de `on_role/`):

	```bash
	flutter run                              # Android/Web com Firebase
	flutter run --dart-define=BACKEND=mock   # sem Firebase: dados de exemplo em memória
	flutter run --dart-define=MODE=demo      # versão de demonstração (sem conta, sem GPS, dados sintéticos)
	flutter run --dart-define=MODE=bancada   # demonstração + bancada de testes do pesquisador
	```

	Em plataformas sem Firebase configurado (ex.: Windows), o app usa o modo mock automaticamente.

4. Rode os testes:

	```bash
	flutter test
	flutter test --dart-define=MODE=demo test/demo_mode_test.dart   # a demonstração de ponta a ponta
	```

5. Testes das regras de segurança (emulador local, precisa de Java; não toca o banco real):

	```bash
	npm --prefix firestore_tests install
	firebase emulators:exec --only firestore --project demo-onrole "npm --prefix firestore_tests test"
	```

## Experimento do TCC

O desenho é anônimo, para a pesquisa poder dispensar o registro no Comitê de Ética (Resolução CNS 510/2016). O app não registra nem envia a localização de participantes. O protocolo completo, com o questionário, está em [docs/protocolo_experimento.md](docs/protocolo_experimento.md). Em resumo:

1. **H2 e H4 (bancada, só o pesquisador):** trajetos e check-ins sintéticos. Precisão com `dart run tools/geofence_bench.dart`, e quadros e bateria com a build `MODE=bancada` (`flutter build apk --release --dart-define=MODE=bancada`).
2. **H1 e H3 (avaliação de uso):** os voluntários, maiores de 18 anos, usam a build `MODE=demo` (`flutter build apk --release --dart-define=MODE=demo`), sem conta e sem dados pessoais. Depois respondem um questionário anônimo (TAM e utilidade percebida). Feche o app entre um participante e outro.
3. Divulgue só resultados agregados.
4. Os dados da antiga coleta de campo já foram descartados (`tools/purge_experiment`).

## Observações

- Para imagens, use caminhos relativos e garanta que estejam declaradas no `pubspec.yaml`.
- Para telas com teclado, prefira conteúdo rolável para evitar overflow.
- **Locais monitorados:** 11 estabelecimentos reais de Colatina, de acesso público e sem parceria nem patrocínio, em `lib/data/venue_catalog.dart`. O app mostra só nome, tipo e localização. O raio da geocerca segue o tamanho do local: 50 m para pequeno, 75 m para médio e 120 m para grande. Espetinho do Denis e DJ PUB ficam a 44 m um do outro, e o Bharem fica dentro da cerca da Área Verde. Nesses casos o check-in vai para o local mais próximo em que a pessoa está parada, e troca quando ela passa 3 minutos mais perto do vizinho (por mais de 25 m). Vale conferir no próprio local, antes do teste, se o check-in dispara na porta. A lotação do modo mock é inventada.
- **Tiles do mapa:** vêm do servidor público do OpenStreetMap, dentro da [política de uso](https://operations.osmfoundation.org/policies/tiles/) (ok para protótipo e teste com poucos usuários). A CARTO passou a exigir chave de API. Para um estilo escuro "de verdade" ou para escalar, troque `_tileUrl` em `map_screen.dart` por um provedor com chave (CARTO, Stadia, MapTiler).
- **Privacidade (app completo):** coordenadas nunca saem do aparelho. O servidor só conhece o local do check-in, o mapa de calor usa contagens por local (`HeatPoint`), e presenças sem renovação por 15 min deixam de contar. Mesmo assim, local e horário do check-in identificam uma pessoa, e por isso o app completo não é usado no experimento.
- No app completo, o modo simulação e as posições de apps de "GPS falso" só são aceitos em builds de depuração. Na demonstração, a simulação é a única fonte de posição.
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
- [x] ~~Coleta de métricas do experimento com participantes~~: trocada pelo desenho anônimo (bancada sintética + demonstração + questionário).
- [x] Publicar as regras novas do Firestore (`firebase deploy --only firestore`) antes do teste de campo.
- [x] Trocar os locais de demonstração por estabelecimentos reais de Colatina.
- [x] Apagar do Firebase os dados da antiga coleta de campo e os check-ins dos testes (`tools/purge_experiment`, feito em 26/10/2026).
- [ ] Montar o questionário anônimo no Google Forms (texto em `docs/protocolo_experimento.md`).
- [ ] Rodar a bancada (precisão com várias sementes; quadros e bateria em 2 ou 3 aparelhos).
- [x] Ajustar as geocercas pelo resultado da bancada: detecção de parada e 3 min de permanência (transições corretas de 57% para ~94% nos trajetos sintéticos).
