import 'dart:math';

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Fundo padrão do app: preto arroxeado com uma trama sutil de pontos,
/// igual ao usado nas telas de boas-vindas e nas abas internas.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, this.child, this.withGlow = false});

  final Widget? child;
  final bool withGlow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _DotGridPainter()),
          if (withGlow)
            Align(
              alignment: const Alignment(0, -0.35),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.28),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  static const double _spacing = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (double y = 0; y < size.height; y += _spacing) {
      for (double x = 0; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}

/// Grade quadriculada (estilo mapa) usada na tela de Mapa.
class MapGridPainter extends CustomPainter {
  const MapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant MapGridPainter oldDelegate) => false;
}

/// Botão principal em roxo (gradiente), usado nas telas de auth e CTAs.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão secundário contornado (fundo escuro, borda sutil).
class OutlinedDarkButton extends StatelessWidget {
  const OutlinedDarkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Círculo com a inicial do nome, cor determinística por id/nome.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.ringColor,
  });

  final String name;
  final double radius;
  final Color? ringColor;

  static const _palette = [
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
  ];

  Color _colorFor(String seed) {
    if (seed.isEmpty) return _palette.first;
    final index = seed.codeUnits.fold<int>(0, (sum, c) => sum + c) % _palette.length;
    return _palette[index];
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: _colorFor(name),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
        ),
      ),
    );

    if (ringColor == null) return avatar;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ringColor!, width: 2)),
      child: avatar,
    );
  }
}

/// Placeholder listrado para mídia (foto/vídeo) que ainda não existe de
/// verdade nos dados mockados — usado no feed, mapa, busca e perfil.
class MediaPlaceholder extends StatelessWidget {
  const MediaPlaceholder({
    super.key,
    this.borderRadius = 12,
    this.showPlayIcon = false,
  });

  final double borderRadius;
  final bool showPlayIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(color: AppColors.surfaceHigh),
          CustomPaint(painter: _StripesPainter(), size: Size.infinite),
          if (showPlayIcon)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
            ),
        ],
      ),
    );
  }
}

class _StripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..strokeWidth = 10;
    final diagonal = sqrt(size.width * size.width + size.height * size.height);
    for (double x = -diagonal; x < diagonal; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x + diagonal, diagonal), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StripesPainter oldDelegate) => false;
}
