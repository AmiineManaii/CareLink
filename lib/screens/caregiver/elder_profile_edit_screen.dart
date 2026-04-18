import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../widgets/common/custom_app_bar.dart';

class ElderProfileEditScreen extends StatefulWidget {
  final String elderId;
  final Map<String, dynamic> initialProfile;

  const ElderProfileEditScreen({
    super.key,
    required this.elderId,
    required this.initialProfile,
  });

  @override
  State<ElderProfileEditScreen> createState() => _ElderProfileEditScreenState();
}

class _ElderProfileEditScreenState extends State<ElderProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _ageController;
  String? _gender;
  File? _image;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.initialProfile['firstName']);
    _lastNameController = TextEditingController(text: widget.initialProfile['lastName']);
    _phoneController = TextEditingController(text: widget.initialProfile['phone']);
    _emailController = TextEditingController(text: widget.initialProfile['email']);
    _ageController = TextEditingController(text: widget.initialProfile['age']?.toString());
    _gender = widget.initialProfile['gender'];
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedProfile = {
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'age': int.tryParse(_ageController.text),
        'gender': _gender,
      };

      await ApiService().elderUpdateProfile(
        elderId: widget.elderId,
        profile: updatedProfile,
        image: _image,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour avec succès')),
        );
        Navigator.pop(context, true); // Return true to indicate profile was updated
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la mise à jour : $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Modifier le Profil',
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Image Picker Section
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage: _image != null
                                ? FileImage(_image!)
                                : (widget.initialProfile['photoUrl'] != null
                                    ? NetworkImage(widget.initialProfile['photoUrl'])
                                    : null) as ImageProvider?,
                            child: _image == null && widget.initialProfile['photoUrl'] == null
                                ? const Icon(Icons.person, size: 60, color: Colors.blue)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade600,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Form Fields
                    _buildTextField(_firstNameController, 'Prénom', Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildTextField(_lastNameController, 'Nom', Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildTextField(_phoneController, 'Téléphone', Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildTextField(_emailController, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _buildTextField(_ageController, 'Âge', Icons.cake_outlined, keyboardType: TextInputType.number),
                    const SizedBox(height: 16),

                    // Gender Dropdown
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: _inputDecoration('Genre', Icons.wc_outlined),
                      items: const [
                        DropdownMenuItem(value: 'Homme', child: Text('Homme')),
                        DropdownMenuItem(value: 'Femme', child: Text('Femme')),
                        DropdownMenuItem(value: 'Autre', child: Text('Autre')),
                      ],
                      onChanged: (val) => setState(() => _gender = val),
                      validator: (val) => val == null ? 'Veuillez choisir un genre' : null,
                    ),
                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Enregistrer les modifications',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label, icon),
      validator: (val) => val == null || val.isEmpty ? 'Ce champ est requis' : null,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blue.shade600),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade700),
    );
  }
}
