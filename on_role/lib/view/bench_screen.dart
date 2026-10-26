import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/bench_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

/// Bancada de testes do pesquisador (só no `MODE=bancada`): precisão das
/// geocercas com trajetos sintéticos (H2) e desempenho no aparelho (H4).
/// Nenhum participante: os resultados ficam no aparelho até serem copiados.
class BenchScreen extends StatefulWidget {
  const BenchScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BenchScreen()));
  }

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen> {
  int _nights = 200;
  int _minutes = 30;
  int _seed = 1;

  Future<void> _copyReport(String report) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: report));
    messenger.showSnackBar(const SnackBar(content: Text('Relatório copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    final bench = context.watch<BenchProvider>();
    final report = bench.report;

    return Scaffold(
      appBar: AppBar(title: const Text('Bancada de testes')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Tudo aqui usa trajetos sintéticos com gabarito conhecido. Nenhuma '
              'localização real é lida, e os resultados só saem do aparelho se '
              'você copiar o relatório.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Precisão das geocercas (H2)',
              description: 'Passa as noites sintéticas pelo mesmo rastreador de check-in do app, em '
                  'tempo simulado. Leva alguns segundos.',
              children: [
                _Choice(
                  label: 'Noites',
                  value: _nights,
                  options: const [100, 200, 500],
                  onChanged: (value) => setState(() => _nights = value),
                ),
                _Choice(
                  label: 'Semente',
                  value: _seed,
                  options: const [1, 2, 3],
                  onChanged: (value) => setState(() => _seed = value),
                ),
                const SizedBox(height: 8),
                GradientButton(
                  label: bench.precisionRunning ? 'Rodando...' : 'Rodar',
                  onPressed: bench.precisionRunning ? null : () => bench.runPrecision(nights: _nights, seed: _seed),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Desempenho no aparelho (H4)',
              description: 'Repete um trajeto sintético em tempo real, com os tempos reais das geocercas, '
                  'e mede os quadros do mapa e a bateria. Antes de iniciar: tire da tomada, aumente o '
                  'tempo de tela ligada e deixe o app na aba Mapa até o fim.',
              children: [
                _Choice(
                  label: 'Minutos',
                  value: _minutes,
                  options: const [15, 30, 60],
                  onChanged: bench.isRunning ? null : (value) => setState(() => _minutes = value),
                ),
                const SizedBox(height: 8),
                if (bench.isRunning) ...[
                  Text(
                    'Em andamento: ${bench.elapsed.inMinutes} de ${bench.duration.inMinutes} min.',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  OutlinedDarkButton(label: 'Parar agora', onPressed: bench.stopPerformance),
                ] else
                  GradientButton(
                    label: 'Iniciar',
                    onPressed: () =>
                        bench.startPerformance(duration: Duration(minutes: _minutes), seed: _seed),
                  ),
              ],
            ),
            if (report.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Section(
                title: 'Relatório',
                description: 'Em Markdown, pronto para o capítulo de resultados.',
                children: [
                  SelectableText(
                    report,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  OutlinedDarkButton(label: 'Copiar relatório', onPressed: () => _copyReport(report)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.description, required this.children});

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.value, required this.options, required this.onChanged});

  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Wrap(
            spacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text('$option'),
                  selected: option == value,
                  onSelected: onChanged == null ? null : (_) => onChanged!(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
