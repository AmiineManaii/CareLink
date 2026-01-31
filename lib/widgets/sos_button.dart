// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SOSButton extends StatefulWidget {
  final bool isPressed;
  final VoidCallback onPressedDown;
  final VoidCallback onPressedUp;

  const SOSButton({
    super.key,
    required this.isPressed,
    required this.onPressedDown,
    required this.onPressedUp,
  });

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => widget.onPressedDown(),
      onLongPressEnd: (_) => widget.onPressedUp(),
      child: Listener(
        onPointerDown: (_) => widget.onPressedDown(),
        onPointerUp: (_) => widget.onPressedUp(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.isPressed ? 224 : 256,
          height: widget.isPressed ? 224 : 256,
          decoration: BoxDecoration(
            color: widget.isPressed ? Colors.red[700] : Colors.red[600],
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(widget.isPressed ? 0.5 : 0.4),
                blurRadius: widget.isPressed ? 30 : 40,
                spreadRadius: widget.isPressed ? 5 : 10,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.triangleExclamation,
                color: Colors.white,
                size: widget.isPressed ? 80 : 96,
              ),
              const SizedBox(height: 16),
              Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.isPressed ? 40 : 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'URGENCE',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}