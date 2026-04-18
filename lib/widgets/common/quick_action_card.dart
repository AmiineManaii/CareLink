// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class QuickActionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Color>? gradientColors;
  final VoidCallback onTap;
  final Color? color;

  const QuickActionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.gradientColors,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          gradient: color == null && gradientColors != null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors!,
                )
              : null,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (color ?? gradientColors?[0] ?? Colors.blue).withOpacity(
                0.3,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
