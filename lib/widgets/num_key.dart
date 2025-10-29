import 'package:flutter/material.dart';

class NumKey extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Container(
        // Make keys taller than wide for a more elongated look
        width: size,
        height: size * 1.792, // 20% reduction from 2.24x
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(
            size * 0.2,
          ), // keep same radius for top/bottom
          border: Border.all(
            color: scheme.primary.withOpacity(0.65),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.secondary.withOpacity(0.22),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: scheme.secondary,
              fontWeight: FontWeight.w800,
              // scale font size with key size - increased for better readability
              fontSize: (size * 0.765).clamp(18, 40), // 10% reduction from 0.85
              letterSpacing: 0.2, // tighter letter spacing for larger text
            ),
          ),
        ),
      ),
    );
  }
}
