/// Versão do app, escolhida na compilação com `--dart-define=MODE=...`.
///
/// - (sem MODE): app completo, com Firebase, conta e GPS real.
/// - `demo`: versão de demonstração entregue a quem avalia o app (H1 e H3).
///   Não cria conta, não pede localização, não inicializa o Firebase e usa
///   só dados sintéticos em memória. Nada do que a pessoa faz sai do
///   aparelho ou fica guardado depois que o app fecha.
/// - `bancada`: a demonstração mais a bancada de testes do pesquisador, que
///   repete trajetos sintéticos para medir precisão das geocercas (H2),
///   quadros e bateria (H4).
enum AppMode {
  full,
  demo,
  bench;

  /// Sem conta, sem GPS e sem Firebase.
  bool get isDemo => this != full;

  bool get hasBench => this == bench;
}

const _mode = String.fromEnvironment('MODE');

/// Conta do visitante na versão de demonstração. Não é um cadastro: existe
/// só na memória do aparelho e é a mesma para todo mundo.
const demoGuestEmail = 'visitante@demo.onrole';
const demoGuestPassword = 'demonstracao';

const appMode = _mode == 'demo'
    ? AppMode.demo
    : _mode == 'bancada'
        ? AppMode.bench
        : AppMode.full;
