# OnRolê

OnRolê: Onde o pulso da cidade acontece.

O OnRolê é a fusão entre geolocalização e rede social, criada para quem não quer perder tempo em lugares vazios ou sem energia. Com um mapa interativo em tempo real, o app mostra os pontos mais movimentados da cidade por meio de ícones dinâmicos que ganham vida conforme a galera chega.

## O que o OnRolê faz por você

- **Mapa de Calor Social**: Visualize instantaneamente quais bares, festas e picos estão com mais movimento sem precisar clicar em nada.
- **Feed em Tempo Real**: Veja o que está acontecendo agora através de fotos e vídeos curtos postados por quem já está lá. É o “Instagram do agora”.
- **Check-in Inteligente**: Com tecnologia de geofencing, o app detecta sua presença no local, permitindo que você valide o rolê e compartilhe a vibe com seus seguidores automaticamente.
- **Conexão Tinder-Style**: Descubra quem são as pessoas que frequentam os mesmos tipos de lugares que você e faça novas conexões baseadas nos seus picos favoritos.

## Status do app (atual)

- Telas de boas-vindas, login, cadastro, feed, mapa, busca e perfil. Os dados ainda são mock (`MockDatabase`).
- **Mapa real de Colatina** (OpenStreetMap com filtro escuro) com **mapa de calor por KDE** e lotação de cada local atualizada a cada 5 s. Por enquanto a lotação é simulada pelo `CrowdSimulator`.
- **Localização por GPS** (`geolocator`) e **check-in automático por geocerca**: entrada, permanência mínima (dwell) e saída, com histerese e descarte de leituras imprecisas.
- **Feed vinculado ao check-in**: só posta quem está com presença validada, e cada post mostra o local.
- **Modo simulação** (só em builds de depuração) para testar o check-in sem sair de casa.

## Estrutura principal

- `lib/models/` — `User`, `Posts`, `Venue` (local + geocerca), `CheckIn` e o `MockDatabase` (inclui os locais de demonstração)
- `lib/services/` — lógica em Dart puro, testável sem aparelho:
  - `geo.dart` — distância pela fórmula de Haversine
  - `geofence_engine.dart` — máquina de estados das geocercas (enter/dwell/exit)
  - `kernel_density.dart` — estimativa de densidade por kernel (KDE) do mapa de calor
  - `location_service.dart` — GPS real e posição simulada
  - `crowd_simulator.dart` — lotação simulada até o back-end existir
- `lib/providers/` — estado do app (`AuthProvider`, `PostsProvider`, `VenuesProvider`, `PresenceProvider`)
- `lib/view/` — telas; `lib/view/screen/` — abas da tela inicial; `lib/view/widgets/` — camada do mapa de calor
- `test/` — testes de Haversine, geocercas e KDE (`flutter test`)
- `assets/` — imagens e recursos visuais

## Como testar o check-in

1. Rode o app em modo debug (`flutter run`) e entre com `demo@onrole.com` / `123456`.
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

3. Execute o app:

	```bash
	flutter run
	```

4. Rode os testes:

	```bash
	flutter test
	```

## Observações

- Para imagens, use caminhos relativos e garanta que estejam declaradas no `pubspec.yaml`.
- Para telas com teclado, prefira conteúdo rolável para evitar overflow.
- **Locais de demonstração:** as praças e a Área de Eventos são espaços públicos com coordenadas do OpenStreetMap. Os bares (Boteco Central, Lounge Beira-Rio, Esquina do Chopp) são fictícios. Troque-os pelos 5 estabelecimentos parceiros em `MockDatabase._seedVenues`, com coordenadas medidas no local.
- **Tiles do mapa:** vêm do servidor público do OpenStreetMap, dentro da [política de uso](https://operations.osmfoundation.org/policies/tiles/) (ok para protótipo e teste com poucos usuários). A CARTO passou a exigir chave de API. Para um estilo escuro "de verdade" ou para escalar, troque `_tileUrl` em `map_screen.dart` por um provedor com chave (CARTO, Stadia, MapTiler).
- **Privacidade:** o app nunca recebe a posição crua de outros usuários. O mapa de calor usa contagens agregadas (`HeatPoint`), e o check-in guarda só local e horários.
- O modo simulação e as posições de apps de "GPS falso" só são aceitos em builds de depuração. Use build release/profile no teste de campo.

## Próximos passos

- [x] Mapa com heatmap (KDE) e lotação atualizada periodicamente (simulada).
- [x] Check-in automático com geofencing (app aberto).
- [x] Feed restrito a quem tem check-in ativo.
- [ ] **Decidir o back-end** (Firebase/Firestore ou Node.js) e trocar `MockDatabase` + `CrowdSimulator` por dados reais. O servidor agrega as posições em células, com mínimo de usuários por célula, antes de publicar.
- [ ] Geofencing em segundo plano (check-in com o app fechado).
- [ ] Feed de mídia efêmera (foto/vídeo pela câmera, com expiração).
- [ ] Match geossocial por afinidade de locais (ex.: similaridade de Jaccard dos históricos de check-in).
- [ ] Coleta de métricas do experimento: exportar o log de eventos das geocercas (`PresenceProvider.events`), FPS e consumo de bateria.
- [ ] Testar em aparelho Android real, andando até um local.
