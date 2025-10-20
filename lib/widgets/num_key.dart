import 'package:flutter/material.dart';

class NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const NumKey({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
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
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
