import 'package:flutter/material.dart';

/// The outer LCD glass panel — dark background, bevelled border, box shadow,
/// and the subtle reflection/refraction overlays. Accepts any [child] so it
/// can be reused by both [OpusampLcd] and [OpusampFileInfo].
class OpusampLcdSurface extends StatelessWidget {
  const OpusampLcdSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: const Color(0xFF444444)),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF000000),
            blurRadius: 2,
            spreadRadius: -1,
          ),
        ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            child,
            // Diagonal reflection
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.35, 0.5, 1.0],
                      colors: [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.015),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Top edge refraction
            Positioned(
              top: 0, left: 0, right: 0, height: 6,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Left edge refraction
            Positioned(
              top: 0, left: 0, bottom: 0, width: 4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom edge refraction
            Positioned(
              bottom: 0, left: 0, right: 0, height: 4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.025),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Right edge refraction
            Positioned(
              top: 0, right: 0, bottom: 0, width: 3,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.white.withValues(alpha: 0.02),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
