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

  @override
  void initState() {
    super.initState();
    _initializeGemini();
    _initializeSpeech();
    _loadInitialGreeting();
  }

  void _initializeGemini() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw Exception("No GEMINI_API_KEY found in .env file");
    }

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

    _chat = _model.startChat(history: []);
  }

  void _initializeSpeech() async {
    bool available = await _speech.initialize();
    if (!available) {
      debugPrint("Speech-to-Text not available");
    }
  }

  void _loadInitialGreeting() async {
    setState(() => _isTyping = true);
    final response = await _chat.sendMessage(Content.text(
        "Hello! I'm FLASH AI. How can I assist you today? Keep responses brief."));
    setState(() {
      _messages.insert(
          0,
          ChatMessage(
            text: response.text ?? "Hello! How can I help?",
            sender: "FLASH",
            isDarkMode: _isDarkMode, isFile:false,
          ));
      _isTyping = false;
    });
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      // Update all messages with new theme
      for (var message in _messages) {
        message.isDarkMode = _isDarkMode;
      }
    });
  }

  void _toggleListening() async {
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
  }

  Future<void> _uploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'docx'],
      );

      if (result == null) return;

      final file = result.files.first;
      final fileBytes = file.bytes;
      if (fileBytes == null) return;

      final mimeType = _getMimeType(file.extension);
      final base64File = "data:$mimeType;base64,${base64Encode(fileBytes)}";

      _addMessage(file.name, "User", isFile: true);
      _processFileResponse(base64File);
    } catch (e) {
      _handleError("Error processing file: ${e.toString()}");
    }
  }

  String _getMimeType(String? extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _processFileResponse(String base64File) async {
    setState(() => _isTyping = true);
    try {
      final response = await _chat.sendMessage(
        Content.multi([TextPart(base64File)]),
      );
      _addMessage(
        response.text ?? "I've received your file. How can I help with it?",
        "FLASH",
      );
    } catch (e) {
      _handleError("Failed to process file");
    } finally {
      setState(() => _isTyping = false);
    }
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    _controller.clear();
    _addMessage(message, "User");
    await _processTextResponse(message);
  }

  Future<void> _processTextResponse(String message) async {
    setState(() => _isTyping = true);
    try {
      final response = await _chat.sendMessage(Content.text(message));
      _addMessage(
        response.text ?? "Sorry, I couldn't generate a response.",
        "FLASH",
      );
      _scrollToBottom();
    } catch (e) {
      _handleError("Error processing your message");
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
          isFile: isFile,
          isDarkMode: _isDarkMode,
        ),
      );
    });
    _scrollToBottom();
  }

  void _handleError(String error) {
    _addMessage(error, "FLASH");
    debugPrint(error);
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
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
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
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: _isDarkMode ? Colors.grey[800] : Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _uploadFile,
          ),
          IconButton(
            icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
            onPressed: _toggleListening,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Type your message...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}