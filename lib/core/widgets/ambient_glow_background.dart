import 'package:flutter/material.dart';

class AmbientGlowBackground extends StatelessWidget {
  final Widget child;

  const AmbientGlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Glow Sphere: Top Right (Electric Cyan)
        Positioned(
          top: -120,
          right: -120,
          width: 400,
          height: 400,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF00E5FF).withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Glow Sphere: Bottom Left (Ultraviolet Purple)
        Positioned(
          bottom: -160,
          left: -120,
          width: 450,
          height: 450,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFA855F7).withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Foreground Content
        child,
      ],
    );
  }
}
