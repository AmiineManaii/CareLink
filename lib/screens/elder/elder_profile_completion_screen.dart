import 'package:flutter/material.dart';
import 'package:care_link/services/api_service.dart';
import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:care_link/main.dart';

class ElderProfileCompletionScreen extends StatefulWidget {
  final String elderId;
  const ElderProfileCompletionScreen({super.key, required this.elderId});

  @override
  State<ElderProfileCompletionScreen> createState() =>
      _ElderProfileCompletionScreenState();
}

class _ElderProfileCompletionScreenState
    extends State<ElderProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  String? _gender;
  bool _loading = false;

  final _genders = const ['Homme', 'Femme', 'Autre'];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final profile = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'gender': _gender,
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
      };
      final res = await ApiService().elderUpdateProfile(
        elderId: widget.elderId,
        profile: profile,
      );
      if (res['ok'] == true) {
        await InMemoryFaceStorage().setRole('personne_agee');
        await InMemoryFaceStorage().setLoggedIn(true);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ElderlyNavigation()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur de sauvegarde du profil')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erreur réseau')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compléter votre profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Prénom',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _gender,
                items: _genders
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                decoration: const InputDecoration(
                  labelText: 'Genre',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _gender = v),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Âge',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Âge invalide';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Continuer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
