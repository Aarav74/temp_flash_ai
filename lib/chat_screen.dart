import 'dart:async';
import 'dart:convert';
import 'package:flash_ai/flash_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'chat_message.dart';
import 'animated_lightning.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _conversationHistory = [];
  bool _isTyping = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isDarkMode = false;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final String creatorName = "AARAV";
  bool _hasSpeechPermission = false;
  late AnimationController _typingIndicatorController;

  // OpenRouter configuration
  String get _openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static const String _openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String _defaultModel = 'openai/gpt-3.5-turbo'; // Changed to more reliable model

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
    _typingIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _verifyFirebaseAuth();
    _initializeOpenRouter();
    _initializeSpeech();
    _loadInitialGreeting();
    _updateSystemUIOverlay();
  }

  void _updateSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: _isDarkMode ? _darkBackground : _lightBackground,
        systemNavigationBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
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

  void _initializeOpenRouter() {
    if (_openRouterApiKey.isEmpty) {
      _addSystemMessage("❌ OPENROUTER_API_KEY not found in .env file");
      debugPrint("❌ OpenRouter API Key is empty");
      return;
    }
    debugPrint("✅ OpenRouter API initialized with key: ${_openRouterApiKey.substring(0, 8)}...");
  }

  Future<void> _initializeSpeech() async {
    try {
      final status = await Permission.microphone.request();
      _hasSpeechPermission = status.isGranted;
      
      if (!_hasSpeechPermission) {
        _addSystemMessage("Microphone permission required for voice input");
        return;
      }

      bool available = await _speech.initialize(
        onStatus: (status) => debugPrint('Speech status: $status'),
        onError: (error) => debugPrint('Speech error: ${error.errorMsg}'),
      );

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
        await _stopListening();
      } else {
        await _startListening();
      }
    } catch (e) {
      _addSystemMessage("Speech error: ${e.toString()}");
    }
  }

  Future<void> _startListening() async {
    if (!_hasSpeechPermission) {
      _addSystemMessage("Microphone permission denied");
      return;
    }

    try {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() => _controller.text = result.recognizedWords);
          if (result.finalResult) {
            _sendMessage();
          }
        },
        listenFor: const Duration(seconds: 30),
        localeId: 'en_US',
        // ignore: deprecated_member_use
        cancelOnError: true,
        // ignore: deprecated_member_use
        partialResults: true,
      );
    } catch (e) {
      setState(() => _isListening = false);
      _addSystemMessage("Error starting speech: ${e.toString()}");
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
      setState(() => _isListening = false);
    } catch (e) {
      setState(() => _isListening = false);
      _addSystemMessage("Error stopping speech: ${e.toString()}");
    }
  }

  Future<void> _uploadFile() async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _addSystemMessage("Storage permission required");
        return;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'docx', 'txt'],
      );

      if (result == null || result.files.isEmpty) return;

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
    setState(() {
      _isTyping = true;
      _typingIndicatorController.repeat();
    });
    
    try {
      // For text files, read content directly
      if (file.extension?.toLowerCase() == 'txt') {
        final content = String.fromCharCodes(file.bytes!);
        await _sendOpenRouterMessage("Please analyze this text file content:\n\n$content");
      } else {
        // For other files, just mention the file type
        await _sendOpenRouterMessage("I received a ${file.extension} file named '${file.name}'. Please note that I can currently only process text content directly. For other file types, please describe what you'd like me to help you with regarding this file.");
      }
    } catch (e) {
      _addSystemMessage("Failed to process file: ${e.toString()}");
    } finally {
      setState(() {
        _isTyping = false;
        _typingIndicatorController.stop();
      });
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
    setState(() {
      _isTyping = true;
      _typingIndicatorController.repeat();
    });
    
    try {
      final lowerMessage = message.toLowerCase();
      
      if (lowerMessage.contains("who made you") || 
          lowerMessage.contains("who created you") ||
          lowerMessage.contains("creator")||
          lowerMessage.contains("developer")||
          lowerMessage.contains("created me")||
          lowerMessage.contains("created by ?")||
          lowerMessage.contains("who made u")||
          lowerMessage.contains("who is your developer")||
          lowerMessage.contains("who is your creator")||
          lowerMessage.contains("who created you")||
          lowerMessage.contains("creator")||
          lowerMessage.contains("your creator")||
          lowerMessage.contains(" your developer")) {
        _addMessage("I was created by $creatorName! ❤️", "FLASH");
        return;
      }

      await _sendOpenRouterMessage(message);
    } catch (e) {
      _addSystemMessage("Error processing message: ${e.toString()}");
    } finally {
      setState(() {
        _isTyping = false;
        _typingIndicatorController.stop();
      });
    }
  }

  // Enhanced debug version of _sendOpenRouterMessage
  Future<void> _sendOpenRouterMessage(String message) async {
    try {
      // Debug: Print API key status (first few characters only for security)
      final apiKey = _openRouterApiKey;
      debugPrint("🔑 API Key Status: ${apiKey.isEmpty ? 'EMPTY' : 'Present (${apiKey.substring(0, 8)}...*)'}");
      
      if (apiKey.isEmpty) {
        _addSystemMessage("❌ API Key not found. Please check your .env file.");
        return;
      }

      // Add user message to conversation history
      _conversationHistory.add({
        'role': 'user',
        'content': message,
      });

      debugPrint("📤 Sending request to OpenRouter...");
      debugPrint("🎯 Model: $_defaultModel");
      debugPrint("💬 Message: ${message.substring(0, message.length > 50 ? 50 : message.length)}...");

      final requestBody = {
        'model': _defaultModel,
        'messages': _conversationHistory,
        'temperature': 0.7,
        'max_tokens': 4000,
        'top_p': 0.9,
      };

      debugPrint("📦 Request body: ${jsonEncode(requestBody)}");

      final response = await http.post(
        Uri.parse('$_openRouterBaseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://flash-ai.app',
          'X-Title': 'FLASH AI',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30), // Add timeout
        onTimeout: () {
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );

      debugPrint("📥 Response status: ${response.statusCode}");
      debugPrint("📥 Response headers: ${response.headers}");
      debugPrint("📥 Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Enhanced response validation
        if (data == null) {
          throw Exception('Response data is null');
        }
        
        if (data['choices'] == null) {
          throw Exception('No choices in response: ${jsonEncode(data)}');
        }
        
        if (data['choices'].isEmpty) {
          throw Exception('Empty choices array: ${jsonEncode(data)}');
        }
        
        final choice = data['choices'][0];
        if (choice['message'] == null) {
          throw Exception('No message in choice: ${jsonEncode(choice)}');
        }
        
        final aiResponse = choice['message']['content'];
        if (aiResponse == null || aiResponse.toString().trim().isEmpty) {
          throw Exception('Empty AI response content');
        }
        
        debugPrint("✅ AI Response received: ${aiResponse.toString().substring(0, aiResponse.toString().length > 100 ? 100 : aiResponse.toString().length)}...");
        
        // Add AI response to conversation history
        _conversationHistory.add({
          'role': 'assistant',
          'content': aiResponse,
        });

        // Keep conversation history manageable (last 20 messages)
        if (_conversationHistory.length > 20) {
          _conversationHistory.removeRange(0, _conversationHistory.length - 20);
        }

        _addMessage(aiResponse.toString(), "FLASH");
        
      } else {
        // Enhanced error handling with more details
        String errorMessage = 'API request failed';
        String responseBody = response.body;
        
        debugPrint("❌ Error Response Body: $responseBody");
        
        try {
          final errorData = jsonDecode(responseBody);
          errorMessage = errorData['error']?['message'] ?? 'Unknown error occurred';
          
          // Log additional error details if available
          if (errorData['error']?['type'] != null) {
            debugPrint("❌ Error Type: ${errorData['error']['type']}");
          }
          if (errorData['error']?['code'] != null) {
            debugPrint("❌ Error Code: ${errorData['error']['code']}");
          }
          
        } catch (e) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
          debugPrint("❌ Failed to parse error response: $e");
        }
        
        throw Exception('API Error (${response.statusCode}): $errorMessage');
      }
      
    } catch (e) {
      debugPrint('❌ OpenRouter API Error Details: $e');
      debugPrint('❌ Error Type: ${e.runtimeType}');
      
      // Provide more specific user-friendly error messages
      String userMessage;
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('timeout')) {
        userMessage = "⏰ Request timed out. Please check your internet connection and try again.";
      } else if (errorString.contains('401') || errorString.contains('unauthorized')) {
        userMessage = "🔐 Authentication failed. Please check your OpenRouter API key.";
      } else if (errorString.contains('429') || errorString.contains('rate limit')) {
        userMessage = "⏳ Rate limit exceeded. Please wait a moment and try again.";
      } else if (errorString.contains('500') || errorString.contains('502') || errorString.contains('503')) {
        userMessage = "🔧 OpenRouter server error. Please try again in a few minutes.";
      } else if (errorString.contains('network') || errorString.contains('connection')) {
        userMessage = "🌐 Network error. Please check your internet connection.";
      } else if (errorString.contains('socketexception')) {
        userMessage = "📡 Connection failed. Please check your internet connection.";
      } else {
        userMessage = "❌ Error: ${e.toString()}";
      }
      
      _addSystemMessage(userMessage);
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

  void _navigateToIntroScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlashIntroScreen(user: _currentUser),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    _typingIndicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _currentUser?.email ?? 'Guest';

    return Scaffold(
      backgroundColor: _isDarkMode ? _darkBackground : _lightBackground,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: _navigateToIntroScreen,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: AnimatedLightning(
                    size: 28,
                    color: Colors.amber,
                  ),
                ),
              ),
            ),
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      _isDarkMode ? _bgDarkPath : _bgLightPath,
                      fit: BoxFit.cover,
                      opacity: const AlwaysStoppedAnimation(0.1),
                      errorBuilder: (context, error, stackTrace) => Container(),
                    ),
                  ),
                  ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _messages[index],
                  ),
                ],
              ),
            ),
            if (_isTyping)
              LinearProgressIndicator(
                minHeight: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isDarkMode ? Colors.blue[200]! : Colors.blue,
                ),
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
                        hintStyle: TextStyle(
                          color: _isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
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
      ),
    );
  }
}