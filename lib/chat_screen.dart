import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'chat_message.dart';
import 'animated_lightning.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late GenerativeModel _model;
  late ChatSession _chat;
  bool _isTyping = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isDarkMode = false;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final String creatorName = "AARAV";

  // Asset paths
  static const String _bgLightPath = 'assets/images/chat_bg_light.jpg';
  static const String _bgDarkPath = 'assets/images/chat_bg_dark.jpg';

  // Color definitions
  final Color _darkBackground = const Color(0xFF1A1A2E);
  final Color _darkMessageUser = const Color(0xFF16213E);
  final Color _darkMessageAI = const Color(0xFF0F3460);
  final Color _darkTextColor = Colors.white;
  final Color _lightBackground = Colors.grey[50]!;
  final Color _lightMessageUser = Colors.blue[100]!;
  final Color _lightMessageAI = Colors.grey[200]!;
  final Color _lightTextColor = Colors.black;
  final Color _darkInputBackground = Colors.grey[800]!;

  @override
  void initState() {
    super.initState();
    _verifyFirebaseAuth();
    _initializeGemini();
    _initializeSpeech();
    _loadInitialGreeting();
    _updateSystemUIOverlay();
  }

  void _updateSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }

  void _verifyFirebaseAuth() {
    if (_currentUser == null) {
      debugPrint("⚠️ No authenticated user found");
    } else {
      debugPrint("✅ Authenticated user: ${_currentUser.email}");
    }
  }

  void _initializeGemini() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      _addSystemMessage("GEMINI_API_KEY not found in .env file");
      return;
    }

    try {
      _model = GenerativeModel(
        model: 'gemini-1.5-pro',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 1,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 8192,
        ),
      );
      _chat = _model.startChat();
    } catch (e) {
      _addSystemMessage("Failed to initialize Gemini: ${e.toString()}");
    }
  }

  void _initializeSpeech() async {
    try {
      bool available = await _speech.initialize();
      if (!available) {
        _addSystemMessage("Speech recognition not available");
      }
    } catch (e) {
      _addSystemMessage("Speech init failed: ${e.toString()}");
    }
  }

  void _loadInitialGreeting() {
    _addSystemMessage("Hello! I'm FLASH. How can I help you today?");
  }

  void _addSystemMessage(String text) {
    _addMessage(text, "FLASH");
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sign out failed: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      _updateSystemUIOverlay();
    });
  }

  Future<void> _toggleListening() async {
    try {
      if (_isListening) {
        await _speech.stop();
        setState(() => _isListening = false);
        if (_controller.text.isNotEmpty) await _sendMessage();
      } else {
        bool available = await _speech.listen(
          onResult: (result) => setState(() => _controller.text = result.recognizedWords),
        );
        setState(() => _isListening = available);
      }
    } catch (e) {
      _addSystemMessage("Speech error: ${e.toString()}");
    }
  }

  Future<void> _uploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'docx'],
      );

      if (result == null) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _addSystemMessage("Failed to read file bytes");
        return;
      }

      _addMessage(file.name, "User", isFile: true);
      _processFile(file);
    } catch (e) {
      _addSystemMessage("File upload failed: ${e.toString()}");
    }
  }

  Future<void> _processFile(PlatformFile file) async {
    setState(() => _isTyping = true);
    
    try {
      final mimeType = _getMimeType(file.extension);
      final base64File = base64Encode(file.bytes!);
      final content = Content.multi([
        TextPart("data:$mimeType;base64,$base64File"),
        TextPart("Please analyze this ${file.extension} file"),
      ]);

      final response = await _chat.sendMessage(content);
      _addMessage(response.text ?? "I've processed your file", "FLASH");
    } catch (e) {
      _addSystemMessage("Failed to process file: ${e.toString()}");
    } finally {
      setState(() => _isTyping = false);
    }
  }

  String _getMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    _controller.clear();
    _addMessage(message, "User");
    await _processTextMessage(message);
  }

  Future<void> _processTextMessage(String message) async {
    setState(() => _isTyping = true);
    
    try {
      final lowerMessage = message.toLowerCase();
      
      if (lowerMessage.contains("who made you") || 
          lowerMessage.contains("who created you") ||
          lowerMessage.contains("who created u") ||
          lowerMessage.contains("who made u") ||
          lowerMessage.contains("you made by")) {
        _addMessage("I was created by $creatorName! ❤️", "FLASH");
        return;
      }

      final response = await _chat.sendMessage(Content.text(message));
      _addMessage(response.text ?? "Sorry, I couldn't generate a response", "FLASH");
    } catch (e) {
      _addSystemMessage("Error processing message: ${e.toString()}");
    } finally {
      setState(() => _isTyping = false);
    }
  }

  void _addMessage(String text, String sender, {bool isFile = false}) {
    if (!mounted) return;
    
    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          text: text,
          sender: sender,
          isUser: sender == "User",
          isFile: isFile,
          userColor: _isDarkMode ? _darkMessageUser : _lightMessageUser,
          aiColor: _isDarkMode ? _darkMessageAI : _lightMessageAI,
          textColor: _isDarkMode ? _darkTextColor : _lightTextColor,
          isDarkMode: _isDarkMode,
        ),
      );
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _currentUser?.email ?? 'Guest';

    return Scaffold(
      backgroundColor: _isDarkMode ? _darkBackground : _lightBackground,
      appBar: AppBar(
        title: Row(
          children: [
            AnimatedLightning(size: 32, color: Colors.yellow[700]!),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FLASH AI',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  userEmail,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: _isDarkMode ? _darkMessageAI : Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
            tooltip: 'Logout',
          ),
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: _toggleDarkMode,
            tooltip: 'Toggle theme',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              _isDarkMode ? _bgDarkPath : _bgLightPath,
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.1),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _messages[index],
                ),
              ),
              if (_isTyping)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: _isDarkMode ? Colors.blue[200] : Colors.blue,
                  backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.grey[300],
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isDarkMode ? _darkInputBackground : Colors.white,
                  border: Border.all(
                    color: _isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.attach_file,
                        color: _isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                      onPressed: _uploadFile,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: "Type your message...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic_off : Icons.mic,
                        color: _isListening
                            ? Colors.red
                            : (_isDarkMode ? Colors.white70 : Colors.grey[700]),
                      ),
                      onPressed: _toggleListening,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.send,
                        color: _isDarkMode ? Colors.blue[200] : Colors.blue,
                      ),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}