import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NumKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  // size in logical pixels (width & height). Default kept for backward compatibility.
  final double size;
  const NumKey({
    super.key,
    required this.label,
    required this.onTap,
    this.size = 52,
  });

  @override
  State<NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<NumKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final borderRadius = BorderRadius.circular(widget.size * 0.2);
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (v) => setState(() => _pressed = v),
        borderRadius: borderRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          // Make keys taller than wide for a more elongated look
          width: widget.size,
          height: widget.size * 1.792, // 20% reduction from 2.24x
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: borderRadius,
            border: Border.all(
              color: scheme.primary.withOpacity(_pressed ? 0.8 : 0.65),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.secondary.withOpacity(_pressed ? 0.12 : 0.22),
                blurRadius: _pressed ? 8 : 18,
                spreadRadius: _pressed ? 1 : 2,
                offset: _pressed ? const Offset(0, 1) : const Offset(0, 3),
              ),
              if (_pressed)
                BoxShadow(
                  color: AppColors.neonPink.withOpacity(0.55),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: scheme.secondary,
                fontWeight: FontWeight.w800,
                // scale font size with key size - increased for better readability
                fontSize: (widget.size * 0.765).clamp(
                  18,
                  40,
                ), // tuned from 0.85
                letterSpacing: 0.2, // tighter letter spacing for larger text
              ),
            ),
          ),
        ),
      ),
    );
  }
}
