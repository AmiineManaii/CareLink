import 'package:flutter/material.dart';

class CaregiverHomeScreen extends StatelessWidget {
  const CaregiverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Espace Aidant')),
      body: const Center(
        child: Text(
          "Bienvenue dans l'espace Aidant",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
