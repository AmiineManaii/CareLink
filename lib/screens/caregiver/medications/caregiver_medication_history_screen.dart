import 'package:care_link/services/api_service.dart';
import 'package:care_link/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

class CaregiverMedicationHistoryScreen extends StatefulWidget {
  final String caregiverId;

  const CaregiverMedicationHistoryScreen({
    super.key,
    required this.caregiverId,
  });

  @override
  State<CaregiverMedicationHistoryScreen> createState() =>
      _CaregiverMedicationHistoryScreenState();
}

class _CaregiverMedicationHistoryScreenState
    extends State<CaregiverMedicationHistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;
  String? _error;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  String? _currentlyPlayingUrl;
  String? _currentlySpeakingId;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("fr-FR");
    await _flutterTts.setSpeechRate(0.5);
    
    _flutterTts.setStartHandler(() {
      // Pas besoin de setState ici car on le gère déjà dans onPressed
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _currentlySpeakingId = null);
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() => _currentlySpeakingId = null);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService().getMedicationHistory(widget.caregiverId);
      setState(() {
        _history = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _playAudio(String url) async {
    debugPrint("URL brute reçue du backend : $url");
    String formattedUrl = _formatAudioUrl(url);
    debugPrint("URL finale formatée pour lecture : $formattedUrl");

    if (_currentlyPlayingUrl == formattedUrl) {
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlayingUrl = null;
      });
    } else {
      try {
        // Arrêter toute autre lecture avant de commencer
        await _audioPlayer.stop();
        await _flutterTts.stop();
        
        await _audioPlayer.play(UrlSource(formattedUrl));
        setState(() {
          _currentlyPlayingUrl = formattedUrl;
          _currentlySpeakingId = null;
        });

        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              _currentlyPlayingUrl = null;
            });
          }
        });
      } catch (e) {
        debugPrint("Erreur lecture audio : $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur de lecture audio : $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Historique des prises',
        showBackButton: true,
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _history.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final log = _history[index];
                          return _buildHistoryCard(log);
                        },
                      ),
                    ),
    );
  }

  String _formatAudioUrl(String url) {
    if (url.startsWith('http')) return url;
    String path = url;
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    return "${ApiService().baseUrl}$path";
  }

  Widget _buildHistoryCard(dynamic log) {
    final String logId = log['_id'] ?? log['id'] ?? log.hashCode.toString();
    final medication = log['medicationId'];
    final DateTime takenAt = DateTime.parse(log['takenAt']);
    final String note = log['note'] ?? "";
    final String? audioUrl = log['audioUrl'];
    final String status = log['status'];

    final bool isThisPlaying = audioUrl != null && _currentlyPlayingUrl == _formatAudioUrl(audioUrl);
    final bool isThisSpeaking = _currentlySpeakingId == logId;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication != null ? medication['name'] : 'Médicament supprimé',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        medication != null ? medication['dosage'] : '',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'taken' ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status == 'taken' ? 'Pris' : status,
                    style: TextStyle(
                      color: status == 'taken' ? Colors.green[800] : Colors.orange[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(takenAt),
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  note,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
            if (audioUrl != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _playAudio(audioUrl),
                icon: Icon(isThisPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(
                  isThisPlaying ? "Arrêter l'audio" : "Écouter le message vocal",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ] else if (note.isNotEmpty) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  if (isThisSpeaking) {
                    await _flutterTts.stop();
                    setState(() => _currentlySpeakingId = null);
                  } else {
                    // Arrêter toute lecture en cours avant de commencer
                    await _flutterTts.stop();
                    await _audioPlayer.stop();
                    setState(() {
                      _currentlyPlayingUrl = null;
                      _currentlySpeakingId = logId;
                    });
                    await _flutterTts.speak(note);
                  }
                },
                icon: Icon(isThisSpeaking ? Icons.stop : Icons.volume_up),
                label: Text(isThisSpeaking ? "Arrêter la lecture" : "Écouter la note (vocal)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "Aucun historique de prise",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
