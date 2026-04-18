import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../utils/face_storage.dart';
import '../../../services/api_service.dart';

class CaregiverContactsScreen extends StatefulWidget {
  final String elderId;
  final String elderName;

  const CaregiverContactsScreen({
    super.key,
    required this.elderId,
    required this.elderName,
  });

  @override
  State<CaregiverContactsScreen> createState() =>
      _CaregiverContactsScreenState();
}

class _CaregiverContactsScreenState extends State<CaregiverContactsScreen> {
  List<dynamic> _contacts = [];
  bool _isLoading = true;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getContacts(widget.elderId);
      setState(() {
        _contacts = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching contacts: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationController = TextEditingController();
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter un contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (pickedFile != null) {
                      setDialogState(
                        () => selectedImage = File(pickedFile.path),
                      );
                    }
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                      image: selectedImage != null
                          ? DecorationImage(
                              image: FileImage(selectedImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: selectedImage == null
                        ? const Icon(
                            Icons.add_a_photo,
                            size: 40,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nom complet'),
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: relationController,
                  decoration: const InputDecoration(
                    labelText: 'Relation (ex: Fille, Médecin)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    phoneController.text.isEmpty) {
                  return;
                }

                final caregiverId = InMemoryFaceStorage().getCaregiverId();
                if (caregiverId == null) return;

                try {
                  await _apiService.addContact({
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'relation': relationController.text,
                    'elderId': widget.elderId,
                    'caregiverId': caregiverId,
                  }, image: selectedImage);

                  Navigator.pop(context);
                  _fetchContacts();
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contacts de ${widget.elderName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
          ? const Center(child: Text('Aucun contact enregistré'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      backgroundImage: contact['photoUrl'] != null
                          ? NetworkImage(
                              '${_apiService.baseUrl}${contact['photoUrl']}',
                            )
                          : null,
                      child: contact['photoUrl'] == null
                          ? const Icon(Icons.person, color: Colors.blue)
                          : null,
                    ),
                    title: Text(
                      contact['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${contact['relation']} • ${contact['phone']}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Supprimer le contact'),
                            content: const Text(
                              'Êtes-vous sûr de vouloir supprimer ce contact ?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Non'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Oui'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await _apiService.deleteContact(contact['_id']);
                          _fetchContacts();
                        }
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.add),
      ),
    );
  }
}
