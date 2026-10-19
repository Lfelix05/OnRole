import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/venue_catalog.dart';
import '../models/venue.dart';
import '../providers/experiment_provider.dart';
import '../providers/presence_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

/// Participação no experimento de campo do TCC: consentimento, diário de
/// campo e direito de apagar os próprios dados.
class ExperimentScreen extends StatelessWidget {
  const ExperimentScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ExperimentScreen()));
  }

  Future<void> _toggle(BuildContext context, bool enrolled) async {
    final experiment = context.read<ExperimentProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (enrolled && !await showExperimentConsent(context)) return;
    final error = await experiment.setEnrolled(enrolled);
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _deleteData(BuildContext context) async {
    final experiment = context.read<ExperimentProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('Apagar seus dados do experimento?'),
        content: const Text('Tudo o que você enviou até agora será apagado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await experiment.deleteMyData();
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? 'Seus dados do experimento foram apagados.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final experiment = context.watch<ExperimentProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Experimento do TCC')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'O OnRolê é tema de um TCC de Sistemas de Informação (UNESC). '
              'Participando, você ajuda a medir se o check-in automático acerta '
              'e se o app roda bem nos celulares.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              child: SwitchListTile(
                value: experiment.isEnrolled,
                onChanged: experiment.isLoading
                    ? null
                    : (value) => _toggle(context, value),
                title: const Text(
                  'Participar do experimento',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  experiment.isEnrolled
                      ? 'Registrando. Obrigado!'
                      : 'Nada é registrado enquanto estiver desligado.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _Collected(),
            if (experiment.isEnrolled) ...[
              const SizedBox(height: 24),
              const Text(
                'Diário de campo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Toque quando chegar ou sair de um local, na hora em que '
                'acontecer. É o que permite conferir se o check-in automático '
                'acertou.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              GradientButton(
                label: 'Abrir diário de campo',
                onPressed: () => showFieldDiary(context),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      experiment.pendingEvents == 0
                          ? 'Tudo enviado.'
                          : '${experiment.pendingEvents} registros aguardando envio.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: experiment.flush,
                    child: const Text('Enviar agora'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _deleteData(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Apagar meus dados do experimento'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Collected extends StatelessWidget {
  const _Collected();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primarySoft, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        item(
          Icons.location_on_outlined,
          'Entradas e saídas dos locais, nunca a sua posição',
        ),
        item(Icons.gps_fixed, 'Precisão das leituras de GPS'),
        item(Icons.speed, 'Fluidez do mapa de calor (quadros por segundo)'),
        item(Icons.battery_std, 'Nível de bateria e se o app está aberto'),
        item(Icons.phone_android, 'Modelo do celular e versão do sistema'),
        item(
          Icons.favorite_border,
          'Curtidas e passes nas Conexões (sem nomes, só códigos)',
        ),
      ],
    );
  }
}

/// Pop-up de consentimento do experimento. Devolve se a pessoa aceitou.
/// [newAccount]: convite logo depois do cadastro, que só fecha com uma
/// escolha explícita e explica onde mudar de ideia depois.
Future<bool> showExperimentConsent(
  BuildContext context, {
  bool newAccount = false,
}) async {
  const details =
      'O OnRolê vai registrar, até você sair: entradas e saídas dos locais '
      '(sem coordenadas), a qualidade do GPS, o desempenho do mapa, o nível '
      'de bateria e o modelo do aparelho. Suas decisões nas Conexões (curtir '
      'ou passar) também entram na análise. Os dados são usados só no TCC, '
      'com você identificado por um código (P01, P02...). Você pode sair e '
      'apagar tudo a qualquer momento';
  final text = newAccount
      ? 'O OnRolê é tema de um TCC de Sistemas de Informação (UNESC). '
            '$details, no ícone de frasco do seu perfil.'
      : '$details.';

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: !newAccount,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: Text(
        newAccount
            ? 'Quer participar do experimento do TCC?'
            : 'Participar do experimento?',
      ),
      content: SingleChildScrollView(child: Text(text)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Agora não'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Aceito participar'),
        ),
      ],
    ),
  );
  return accepted == true;
}

/// Convite mostrado a toda conta nova, logo depois do cadastro.
Future<void> inviteToExperiment(BuildContext context) async {
  final experiment = context.read<ExperimentProvider>();
  final messenger = ScaffoldMessenger.of(context);
  if (!await showExperimentConsent(context, newAccount: true)) return;
  final error = await experiment.setEnrolled(true);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        error ?? 'Obrigado! Você está participando do experimento.',
      ),
    ),
  );
}

/// Folha rápida do diário de campo (também aberta pelo mapa).
Future<void> showFieldDiary(BuildContext context) {
  final presence = context.read<PresenceProvider>();
  final checkedIn = presence.checkedInVenue;
  // O local do check-in primeiro, depois os mais próximos.
  final venues = [...venueCatalog]
    ..sort((a, b) {
      if (a.id == checkedIn?.id) return -1;
      if (b.id == checkedIn?.id) return 1;
      final distanceA = presence.distanceTo(a) ?? double.infinity;
      final distanceB = presence.distanceTo(b) ?? double.infinity;
      return distanceA.compareTo(distanceB);
    });

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceHigh,
    isScrollControlled: true,
    builder: (sheetContext) => _FieldDiarySheet(venues: venues),
  );
}

class _FieldDiarySheet extends StatefulWidget {
  const _FieldDiarySheet({required this.venues});

  final List<Venue> venues;

  @override
  State<_FieldDiarySheet> createState() => _FieldDiarySheetState();
}

class _FieldDiarySheetState extends State<_FieldDiarySheet> {
  late Venue _venue = widget.venues.first;

  void _mark(bool arrived) {
    context.read<ExperimentProvider>().markGroundTruth(
      venueId: _venue.id,
      arrived: arrived,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${arrived ? 'Chegada' : 'Saída'} em ${_venue.name} registrada às '
          '${TimeOfDay.now().format(context)}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Diário de campo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Venue>(
              initialValue: _venue,
              dropdownColor: AppColors.surfaceHigh,
              items: [
                for (final venue in widget.venues)
                  DropdownMenuItem(value: venue, child: Text(venue.name)),
              ],
              onChanged: (venue) {
                if (venue != null) setState(() => _venue = venue);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedDarkButton(
                    label: 'Saí agora',
                    onPressed: () => _mark(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    label: 'Cheguei agora',
                    onPressed: () => _mark(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
