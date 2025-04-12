import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'animated_lightning.dart';

class FlashIntroScreen extends StatelessWidget {
  final User? user;

  const FlashIntroScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About FLASH AI'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: AnimatedLightning(
                  size: 100,
                  color: Colors.amber,
                  onTap: () {}, // Optional: Add functionality if needed
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Hello ${user?.displayName ?? 'User'}! 👋',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to FLASH AI',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Your intelligent assistant by Aarav<3. '
                'I can help you with information, creative ideas, and much more!',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Features:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              _buildFeatureItem('Real-time conversations', isDarkMode),
              _buildFeatureItem('File uploads & analysis', isDarkMode),
              _buildFeatureItem('Voice input support', isDarkMode),
              _buildFeatureItem('Dark/light mode', isDarkMode),
              const SizedBox(height: 40),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Got it! Continue to Chat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Icon(
              Icons.bolt,
              color: Colors.amber,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}