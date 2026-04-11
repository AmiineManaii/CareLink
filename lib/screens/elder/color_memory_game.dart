import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class ColorMemoryGame extends StatefulWidget {
  const ColorMemoryGame({super.key});

  @override
  State<ColorMemoryGame> createState() => _ColorMemoryGameState();
}

class _ColorMemoryGameState extends State<ColorMemoryGame> {
  static const List<Color> _gameColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

  late List<Color> _cards;
  late List<bool> _cardFliped;
  late List<bool> _cardMatched;
  int? _firstSelectedIndex;
  bool _isProcessing = false;
  int _score = 0;
  int _tries = 0;
  int _countdown = 5;
  bool _isMemorizing = false;
  Timer? _memorizeTimer;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    _memorizeTimer?.cancel();
    super.dispose();
  }

  void _initializeGame() {
    _memorizeTimer?.cancel();
    // Create pairs of colors
    _cards = [..._gameColors, ..._gameColors];
    _cards.shuffle();
    _cardFliped = List.filled(_cards.length, true); // Show all cards initially
    _cardMatched = List.filled(_cards.length, false);
    _firstSelectedIndex = null;
    _isProcessing = true; // Disable taps during memorization
    _isMemorizing = true;
    _score = 0;
    _tries = 0;
    _countdown = 5;

    _startMemorizeCountdown();
  }

  void _startMemorizeCountdown() {
    _memorizeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _isMemorizing = false;
          _isProcessing = false;
          _cardFliped = List.filled(_cards.length, false); // Hide all cards
          _memorizeTimer?.cancel();
        }
      });
    });
  }

  void _onCardTap(int index) {
    if (_isProcessing || _cardFliped[index] || _cardMatched[index]) return;

    setState(() {
      _cardFliped[index] = true;
    });

    if (_firstSelectedIndex == null) {
      _firstSelectedIndex = index;
    } else {
      _tries++;
      _isProcessing = true;
      if (_cards[_firstSelectedIndex!] == _cards[index]) {
        // Match!
        setState(() {
          _cardMatched[_firstSelectedIndex!] = true;
          _cardMatched[index] = true;
          _score++;
          _firstSelectedIndex = null;
          _isProcessing = false;
        });
        if (_score == _gameColors.length) {
          _showWinDialog();
        }
      } else {
        // No match
        Timer(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _cardFliped[_firstSelectedIndex!] = false;
              _cardFliped[index] = false;
              _firstSelectedIndex = null;
              _isProcessing = false;
            });
          }
        });
      }
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Félicitations !'),
        content: Text('Vous avez gagné en $_tries essais !'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _initializeGame();
              });
            },
            child: const Text('Rejouer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jeu de Mémoire'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_isMemorizing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Text(
                      'Mémorisez les cartes ! $_countdown',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('Score: $_score', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Essais: $_tries', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _onCardTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _cardFliped[index] || _cardMatched[index]
                          ? _cards[index]
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _cardFliped[index] || _cardMatched[index]
                        ? null
                        : const Center(
                            child: Icon(Icons.question_mark, color: Colors.white),
                          ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _initializeGame();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Nouvelle Partie', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
