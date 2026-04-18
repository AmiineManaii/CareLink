// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? content;
  final VoidCallback? onTap;
  final List<Color> gradientColors;
  final Color iconColor;
  final Color textColor;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.content,
    this.onTap,
    required this.gradientColors,
    this.iconColor = Colors.white,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (subtitle != null) ...[
                    Text(
                      subtitle!,
                      style: TextStyle(color: textColor.withOpacity(0.9)),
                    ),
                  ],
                  if (content != null) content!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
