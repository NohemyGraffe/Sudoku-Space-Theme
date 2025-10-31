import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NumKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  // size in logical pixels (width & height). Default kept for backward compatibility.
  final double size;
  final bool enabled;
  const NumKey({
    super.key,
    required this.label,
    required this.onTap,
    this.size = 52,
    this.enabled = true,
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
      // Make key significantly larger while pressed for a strong feedback effect
      scale: (widget.enabled && _pressed) ? 1.28 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutBack,
      child: InkWell(
        onTap: widget.enabled ? widget.onTap : null,
        onHighlightChanged: (v) {
          if (!widget.enabled) return;
          setState(() => _pressed = v);
        },
        borderRadius: borderRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          // Make keys taller than wide for a more elongated look
          width: widget.size,
          height: widget.size * 1.792, // 20% reduction from 2.24x
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: borderRadius,
            border: Border.all(
              color: widget.enabled
                  ? scheme.primary.withOpacity(_pressed ? 0.8 : 0.65)
                  : AppColors.muted.withOpacity(0.25),
              width: 1.5,
            ),
            boxShadow: [
              if (widget.enabled) ...[
                BoxShadow(
                  color: scheme.secondary.withOpacity(_pressed ? 0.30 : 0.20),
                  blurRadius: _pressed ? 28 : 16,
                  spreadRadius: _pressed ? 6 : 2,
                  offset: _pressed ? const Offset(0, 8) : const Offset(0, 3),
                ),
                if (_pressed)
                  BoxShadow(
                    color: AppColors.neonPink.withOpacity(0.55),
                    blurRadius: 34,
                    spreadRadius: 4,
                  ),
              ],
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.enabled
                    ? scheme.secondary
                    : AppColors.muted.withOpacity(0.45),
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
