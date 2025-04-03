import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_message.dart';

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

  @override
  void initState() {
    super.initState();
    _verifyFirebaseAuth();
    _initializeGemini();
    _initializeSpeech();
    _loadInitialGreeting();
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
          responseMimeType: 'text/plain',
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

  void _loadInitialGreeting() async {
    _addSystemMessage("Hello! I'm FLASH AI. How can I help you today?");
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          text: text,
          sender: "FLASH",
          isDarkMode: _isDarkMode,
          isFile: false,
        ),
      );
    });
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      // Update all messages with new theme
      
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
          onResult: (result) {
            setState(() => _controller.text = result.recognizedWords);
          },
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
      _addMessage(
        response.text ?? "I've processed your file",
        "FLASH",
      );
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
      final response = await _chat.sendMessage(Content.text(message));
      _addMessage(
        response.text ?? "Sorry, I couldn't generate a response",
        "FLASH",
      );
    } catch (e) {
      _addSystemMessage("Error processing message: ${e.toString()}");
    } finally {
      setState(() => _isTyping = false);
    }
  }

  void _addMessage(String text, String sender, {bool isFile = false}) {
    setState(() {
      _messages.insert(
        0,
        ChatMessage(
          text: text,
          sender: sender,
          isDarkMode: _isDarkMode,
          isFile: isFile,
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
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.grey[100],
      appBar: AppBar(
        title: const Text('FLASH AI'),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleDarkMode,
            tooltip: 'Toggle dark mode',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _messages[index],
            ),
          ),
          if (_isTyping)
            const LinearProgressIndicator(minHeight: 2),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: _isDarkMode ? Colors.grey[800] : Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _uploadFile,
            tooltip: 'Attach file',
          ),
          IconButton(
            icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
            color: _isListening ? Colors.red : null,
            onPressed: _toggleListening,
            tooltip: 'Voice input',
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Type your message...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
            tooltip: 'Send message',
          ),
        ],
      ),
    );
  }
}