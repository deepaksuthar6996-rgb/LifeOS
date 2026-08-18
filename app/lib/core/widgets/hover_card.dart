import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HoverCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  const HoverCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius = 16.0,
    this.backgroundColor = const Color(0xFF141721),
    this.borderColor = AppColors.border,
    this.borderWidth = 1.2,
    this.onTap,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final borderCol = _isHovered
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
        : (widget.borderColor == AppColors.border ? Colors.white.withValues(alpha: 0.08) : widget.borderColor);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: widget.margin,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: widget.padding ?? const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.backgroundColor.withValues(alpha: 0.55), // Frosted translucent background
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: borderCol,
                  width: widget.borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: widget.onTap != null
                  ? InkWell(
                      onTap: widget.onTap,
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      child: widget.child,
                    )
                  : widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
