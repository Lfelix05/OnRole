import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/venue_catalog.dart';
import '../../models/match.dart';
import '../../providers/auth_provider.dart';
import '../../providers/match_provider.dart';
import '../../services/affinity.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../edit_profile_screen.dart';
import '../matches_screen.dart';
import '../widgets/media_view.dart';

/// Conexões no estilo Tinder: pessoas que frequentam os mesmos rolês (H3).
///
/// Pausada: fora da navegação até a retomada (ver home_view.dart).
class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final _topCard = GlobalKey<_SwipeCardState>();

  Future<void> _decide(MatchCandidate candidate, SwipeDecision decision) async {
    final match = await context.read<MatchProvider>().decide(
      candidate,
      decision,
    );
    if (match == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('É um match! 🎉'),
        content: Text(
          'Você e ${candidate.user.name} se curtiram. '
          '${_commonLine(candidate.affinity)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              MatchesScreen.open(this.context);
            },
            child: const Text('Ver conexões'),
          ),
        ],
      ),
    );
  }

  static String _commonLine(Affinity affinity) {
    final venue = findVenue(affinity.sharedVenueIds.firstOrNull);
    if (venue != null) return 'Que tal marcar no ${venue.name}?';
    if (affinity.sharedInterests.isNotEmpty) {
      return 'Vocês curtem ${affinity.sharedInterests.first.toLowerCase()}.';
    }
    return 'Que tal combinar um rolê?';
  }

  @override
  Widget build(BuildContext context) {
    final matches = context.watch<MatchProvider>();
    final me = context.watch<AuthProvider>().currentUser;
    final deck = matches.deck;
    final profileEmpty =
        me != null && me.interests.isEmpty && me.visits.isEmpty;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Conexões',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Suas conexões',
                      onPressed: () => MatchesScreen.open(context),
                      icon: Badge(
                        isLabelVisible: matches.matches.isNotEmpty,
                        label: Text('${matches.matches.length}'),
                        backgroundColor: AppColors.primary,
                        child: const Icon(
                          Icons.people_alt_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 2, 20, 12),
                child: Text(
                  'Gente que frequenta os mesmos rolês que você.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              if (profileEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      leading: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primarySoft,
                      ),
                      title: const Text(
                        'Marque seus gostos de rolê',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Com eles e seus check-ins, as sugestões ficam com a '
                        'sua cara.',
                      ),
                      onTap: () => EditProfileScreen.open(context),
                    ),
                  ),
                ),
              Expanded(
                child: !matches.isReady
                    ? const Center(child: CircularProgressIndicator())
                    : deck.isEmpty
                    ? _EmptyDeck(onRefresh: matches.refreshDeck)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Stack(
                          children: [
                            if (deck.length > 1)
                              Positioned.fill(
                                child: Transform.scale(
                                  scale: 0.95,
                                  child: _CandidateCard(candidate: deck[1]),
                                ),
                              ),
                            Positioned.fill(
                              child: _SwipeCard(
                                key: _topCard,
                                // Cada pessoa tem a própria carta: ao trocar,
                                // o arraste recomeça do centro.
                                candidateKey: deck.first.user.id,
                                onDecision: (decision) =>
                                    _decide(deck.first, decision),
                                child: _CandidateCard(candidate: deck.first),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (matches.isReady && deck.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundButton(
                        icon: Icons.close,
                        color: const Color(0xFFEF4444),
                        tooltip: 'Passar',
                        onPressed: () =>
                            _topCard.currentState?.flyOut(SwipeDecision.pass),
                      ),
                      const SizedBox(width: 36),
                      _RoundButton(
                        icon: Icons.favorite,
                        color: AppColors.success,
                        tooltip: 'Curtir',
                        onPressed: () =>
                            _topCard.currentState?.flyOut(SwipeDecision.like),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carta arrastável: soltar longe do centro decide; perto, ela volta.
class _SwipeCard extends StatefulWidget {
  const _SwipeCard({
    super.key,
    required this.candidateKey,
    required this.onDecision,
    required this.child,
  });

  final String candidateKey;
  final ValueChanged<SwipeDecision> onDecision;
  final Widget child;

  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Offset _offset = Offset.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  SwipeDecision? _pending;

  @override
  void initState() {
    super.initState();
    _animation.addListener(() {
      setState(() => _offset = Offset.lerp(_from, _to, _animation.value)!);
    });
    _animation.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      final decision = _pending;
      _pending = null;
      if (decision != null) widget.onDecision(decision);
    });
  }

  @override
  void didUpdateWidget(_SwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidateKey != widget.candidateKey) {
      _animation.stop();
      _offset = Offset.zero;
      _pending = null;
    }
  }

  /// Joga a carta para fora (usado também pelos botões).
  void flyOut(SwipeDecision decision) {
    if (_pending != null) return;
    final width = MediaQuery.sizeOf(context).width;
    _pending = decision;
    _animateTo(
      Offset((decision == SwipeDecision.like ? 1.5 : -1.5) * width, _offset.dy),
    );
  }

  void _animateTo(Offset target) {
    _from = _offset;
    _to = target;
    _animation.forward(from: 0);
  }

  void _onPanEnd(DragEndDetails details) {
    final width = MediaQuery.sizeOf(context).width;
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_offset.dx > width * 0.25 || velocity > 900) {
      flyOut(SwipeDecision.like);
    } else if (_offset.dx < -width * 0.25 || velocity < -900) {
      flyOut(SwipeDecision.pass);
    } else {
      _animateTo(Offset.zero);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final like = (_offset.dx / (width * 0.25)).clamp(0.0, 1.0);
    final pass = (-_offset.dx / (width * 0.25)).clamp(0.0, 1.0);

    return GestureDetector(
      onPanUpdate: _pending == null
          ? (details) => setState(() => _offset += details.delta)
          : null,
      onPanEnd: _pending == null ? _onPanEnd : null,
      child: Transform.translate(
        offset: _offset,
        child: Transform.rotate(
          angle: _offset.dx / width * 0.35,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              Positioned(
                top: 24,
                left: 24,
                child: Opacity(
                  opacity: like,
                  child: const _Stamp(label: 'CURTI', color: AppColors.success),
                ),
              ),
              Positioned(
                top: 24,
                right: 24,
                child: Opacity(
                  opacity: pass,
                  child: const _Stamp(label: 'PASSO', color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

  final MatchCandidate candidate;

  static const _gradient = LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final user = candidate.user;
    final photo = user.photo;
    final venues = [
      for (final id in candidate.affinity.sharedVenueIds.take(3))
        ?findVenue(id),
    ];
    final interests = candidate.affinity.sharedInterests.take(3).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null)
            MediaImage(media: photo)
          else
            DecoratedBox(
              decoration: const BoxDecoration(gradient: _gradient),
              child: Center(
                child: Text(
                  user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 48, 18, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user.bio != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.bio!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  if (venues.isNotEmpty || interests.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Em comum com você',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final venue in venues)
                          _Tag(icon: Icons.location_on, label: venue.name),
                        for (final interest in interests)
                          _Tag(icon: Icons.favorite, label: interest),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -math.pi / 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        shape: CircleBorder(side: BorderSide(color: color, width: 2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Icon(icon, color: color, size: 30),
          ),
        ),
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.nightlife,
              color: AppColors.textTertiary,
              size: 56,
            ),
            const SizedBox(height: 12),
            const Text(
              'Você já viu todo mundo por enquanto.\nVolte depois dos próximos '
              'rolês!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRefresh,
              child: const Text('Procurar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
