import 'package:care_link/screens/caregiver/caregiver_navigation.dart';
import 'package:care_link/services/auth/face_storage.dart';
import 'package:care_link/services/api_service.dart';
import 'package:flutter/material.dart';

class CaregiverSignupScreen extends StatefulWidget {
  const CaregiverSignupScreen({super.key});

  @override
  State<CaregiverSignupScreen> createState() => _CaregiverSignupScreenState();
}

class _CaregiverSignupScreenState extends State<CaregiverSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _elderCodeController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = false;
  bool _isCodeVerified = false;
  bool _verifyingCode = false;
  bool _obscurePassword = true;

  final List<String> _genders = ['Homme', 'Femme', 'Autre'];

  void _verifyCode() async {
    final code = _elderCodeController.text.trim();
    if (code.length != 6) {
      _showSnackBar('Le code doit contenir 6 chiffres', isError: true);
      return;
    }

    setState(() => _verifyingCode = true);

    try {
      final result = await ApiService().verifyElderCode(code);
      if (mounted) {
        if (result['valid'] == true) {
          setState(() => _isCodeVerified = true);
          _showSnackBar(
            'Code valide ! Senior: ${result['elder']['firstName'] ?? ''} ${result['elder']['lastName'] ?? ''}',
            isSuccess: true,
          );
        } else {
          setState(() => _isCodeVerified = false);
          _showSnackBar('Code invalide. Veuillez vérifier.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _verifyingCode = false);
      }
    }
  }

  void _signup() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedGender == null) {
        _showSnackBar('Veuillez sélectionner un genre', isError: true);
        return;
      }

      if (_elderCodeController.text.isNotEmpty && !_isCodeVerified) {
        _showSnackBar(
          'Veuillez vérifier le code senior avant de continuer',
          isError: true,
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final resp = await ApiService().caregiverSignup(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          phone: _phoneController.text.trim(),
          gender: _selectedGender!,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          elderCode: _elderCodeController.text.trim().isEmpty
              ? null
              : _elderCodeController.text.trim(),
        );

        if (mounted) {
          await InMemoryFaceStorage().setRole('aidant');
          await InMemoryFaceStorage().setLoggedIn(true);
          if (resp['caregiverId'] != null) {
            await InMemoryFaceStorage().setCaregiverId(resp['caregiverId'].toString());
          }
          if (resp['linkedElderId'] != null) {
            await InMemoryFaceStorage().setElderId(resp['linkedElderId']);
          }

          _showSnackBar('Compte créé avec succès !', isSuccess: true);

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const CaregiverNavigation()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Erreur lors de l\'inscription: $e', isError: true);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red.shade400
            : isSuccess
                ? Colors.green.shade400
                : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _elderCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey.shade800,
        title: const Text(
          'Créer un compte',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  'Inscription Aidant',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Rejoignez CareLink pour accompagner vos proches',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Name Fields
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _firstNameController,
                        label: 'Prénom',
                        icon: Icons.person_outline,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _lastNameController,
                        label: 'Nom',
                        icon: Icons.person_outline,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Requis' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Email
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Requis';
                    if (!value!.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                _buildTextField(
                  controller: _passwordController,
                  label: 'Mot de passe',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Requis';
                    if (value!.length < 6) return 'Min. 6 caractères';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone
                _buildTextField(
                  controller: _phoneController,
                  label: 'Téléphone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Requis' : null,
                ),
                const SizedBox(height: 16),

                // Gender Dropdown
                _buildGenderDropdown(),
                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'A Remplir',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 24),

                // Elder Code Section
                _buildElderCodeSection(),
                const SizedBox(height: 32),

                // Sign Up Button
                _buildSignUpButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
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
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration: InputDecoration(
          labelText: 'Genre',
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(Icons.wc_outlined, color: Colors.grey.shade600, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        items: _genders.map((gender) {
          return DropdownMenuItem(
            value: gender,
            child: Text(gender, style: const TextStyle(fontSize: 15)),
          );
        }).toList(),
        onChanged: (value) => setState(() => _selectedGender = value),
        validator: (value) => value == null ? 'Requis' : null,
      ),
    );
  }

  Widget _buildElderCodeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Lier à un compte senior',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _elderCodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 15, letterSpacing: 2),
                  onChanged: (value) {
                    if (_isCodeVerified) {
                      setState(() => _isCodeVerified = false);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 2),
                    filled: true,
                    fillColor: Colors.white,
                    counterText: '',
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
                      borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: _isCodeVerified
                        ? Icon(Icons.check_circle, color: Colors.green.shade600)
                        : null,
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty && value.length != 6) {
                      return 'Code à 6 chiffres';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed:  _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCodeVerified ? Colors.green.shade600 : Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _verifyingCode
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isCodeVerified ? '✓' : 'Vérifier',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _signup,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Créer mon compte',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
    );
  }
}
