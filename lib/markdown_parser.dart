import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownParser {
  static Widget parse(String text, {bool isDarkMode = false}) {
    // First clean the text to handle common markdown issues
    String cleanedText = _cleanMarkdown(text);
    
    return MarkdownBody(
      data: cleanedText,
      styleSheet: MarkdownStyleSheet(
        strong: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        p: TextStyle(
          fontSize: 16,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        // ... other style definitions ...
      ),
    );
  }

  static String _cleanMarkdown(String text) {
    // Fix common markdown issues
    return text
        .replaceAll('**', '**')  // Ensure proper bold syntax
        .replaceAll('*', '*')    // Ensure proper italic syntax
        .replaceAll('__', '**')  // Convert __ to ** for bold
        .replaceAll('_', '*');   // Convert _ to * for italic
  }
}