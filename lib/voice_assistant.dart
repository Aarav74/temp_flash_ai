import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceAssistant extends StatefulWidget {
  final Function(String) onMessageSent;
  
  const VoiceAssistant({super.key, required this.onMessageSent});

  @override
  State<VoiceAssistant> createState() => _VoiceAssistantState();
}

class _VoiceAssistantState extends State<VoiceAssistant> with SingleTickerProviderStateMixin {
  late final stt.SpeechToText _speech;
  bool _isListening = false;
  final bool _isProcessing = false;
  String _currentText = '';
  late final AnimationController _pulseController;
  late final Color _accentColor;
  bool _hasSpeechPermission = false;

  @override
  void initState() {
    super.initState();
    _accentColor = Color(int.parse(
      dotenv.get('ASSISTANT_ACCENT_COLOR').replaceFirst('#', '0xFF')
    ));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final status = await Permission.microphone.request();
      _hasSpeechPermission = status.isGranted;
      
      if (!_hasSpeechPermission) {
        _showError("Microphone permission required");
        return;
      }

      final available = await _speech.initialize(
        onStatus: (status) => debugPrint('Speech status: $status'),
        onError: (error) => _showError(error.errorMsg),
      );

      if (!available) {
        _showError("Speech recognition not available");
      }
    } catch (e) {
      _showError("Failed to initialize speech: ${e.toString()}");
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_hasSpeechPermission) {
      _showError("Microphone permission denied");
      return;
    }

    try {
      setState(() {
        _isListening = true;
        _currentText = 'Listening...';
        _pulseController.repeat(reverse: true);
      });

      await _speech.listen(
        onResult: (result) {
          setState(() => _currentText = result.recognizedWords);
          if (result.finalResult) {
            widget.onMessageSent(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        localeId: 'en_US',
      );
    } catch (e) {
      _showError("Error starting speech: ${e.toString()}");
      setState(() => _isListening = false);
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _pulseController.stop();
      });
    } catch (e) {
      _showError("Error stopping speech: ${e.toString()}");
      setState(() => _isListening = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 100,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              // ignore: deprecated_member_use
              _accentColor.withOpacity(0.2),
              // ignore: deprecated_member_use
              _accentColor.withOpacity(0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dotenv.get('ASSISTANT_NAME'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: GestureDetector(
                    onTap: _toggleListening,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            color: _isListening 
                                ? _accentColor
                                // ignore: deprecated_member_use
                                : _accentColor.withOpacity(0.7),
                            shape: BoxShape.circle,
                            boxShadow: _isListening
                                ? [
                                    BoxShadow(
                                      // ignore: deprecated_member_use
                                      color: _accentColor.withOpacity(0.5),
                                      blurRadius: 10 * _pulseController.value,
                                      spreadRadius: 5 * _pulseController.value,
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: _isProcessing
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  )
                                : Icon(
                                    _isListening ? Icons.mic : Icons.mic_none,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (_currentText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    _currentText,
                    style: TextStyle(
                      // ignore: deprecated_member_use
                      color: _accentColor.withOpacity(0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }
}