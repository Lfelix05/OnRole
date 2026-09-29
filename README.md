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
- **Back-end no Firebase** (projeto `onrole-tcc`): login por e-mail, perfis, presença, check-ins e posts no Cloud Firestore (São Paulo), em tempo real. O login fica salvo entre aberturas do app.
- **Mapa real de Colatina** (OpenStreetMap com filtro escuro) com **mapa de calor por KDE** e lotação real de cada local (quantas pessoas têm check-in ativo agora).
- **Localização por GPS** (`geolocator`) e **check-in automático por geocerca**: entrada, permanência mínima (dwell) e saída, com histerese e descarte de leituras imprecisas.
- **Feed vinculado ao check-in**: só posta quem está com presença validada no local, e isso é garantido também pelas regras do servidor. Os posts expiram em 12 h.
- **Modo simulação** (só em builds de depuração) para testar o check-in sem sair de casa.

## Estrutura principal

- `lib/models/` — `User`, `Posts`, `Venue` (local + geocerca) e `CheckIn`
- `lib/data/` — camada de dados:
  - `repositories.dart` — contratos (auth, usuários, presença, posts) usados por providers e telas
  - `firebase/` — implementação com Firebase Auth + Cloud Firestore (estrutura do banco no topo do arquivo)
  - `mock/` — implementação em memória, com lotação simulada (testes, Windows e demonstração offline)
  - `venue_catalog.dart` — locais monitorados e suas geocercas
- `lib/services/` — lógica em Dart puro, testável sem aparelho:
  - `geo.dart` — distância pela fórmula de Haversine
  - `geofence_engine.dart` — máquina de estados das geocercas (enter/dwell/exit)
  - `kernel_density.dart` — estimativa de densidade por kernel (KDE) do mapa de calor
  - `location_service.dart` — GPS real e posição simulada
  - `crowd_simulator.dart` — lotação simulada do modo mock
- `lib/providers/` — estado do app (`AuthProvider`, `PostsProvider`, `VenuesProvider`, `PresenceProvider`)
- `lib/view/` — telas (`auth_gate.dart` decide entre boas-vindas e início); `lib/view/screen/` — abas; `lib/view/widgets/` — camada do mapa de calor
- `firestore.rules` — regras de segurança do banco; `firestore_tests/` — testes dessas regras no emulador
- `test/` — testes de Haversine, geocercas, KDE e da camada de dados (`flutter test`)
- `assets/` — imagens e recursos visuais

## Como testar o check-in

1. Rode o app em modo debug e entre: no Firebase, crie uma conta pelo app; no modo mock, use `demo@onrole.com` / `123456`.
2. Na aba **Mapa**, toque no botão laranja (frasco) para ligar o **modo simulação**.
3. Toque no mapa dentro de um local (ex.: sobre o pino do Boteco Central). Em ~10 s o check-in é confirmado e o banner fica verde.
4. Na aba **Início**, o botão **+** agora permite postar. O post sai marcado com o local.

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

## Próximos passos

- [x] Mapa com heatmap (KDE) e lotação atualizada periodicamente (simulada).
- [x] Check-in automático com geofencing (app aberto).
- [x] Feed restrito a quem tem check-in ativo.
- [x] Back-end no Firebase (Auth + Firestore) com regras de segurança testadas no emulador.
- [x] Ativar o login por e-mail no console do Firebase (Authentication > Get started > Email/Password).
- [ ] Geofencing em segundo plano (check-in com o app fechado).
- [ ] Feed de mídia efêmera (foto/vídeo pela câmera, com expiração).
- [ ] Match geossocial por afinidade de locais (ex.: similaridade de Jaccard dos históricos de check-in).
- [ ] Coleta de métricas do experimento: exportar o log de eventos das geocercas (`PresenceProvider.events`), FPS e consumo de bateria.
- [ ] Testar em aparelho Android real, andando até um local.
