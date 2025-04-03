import 'package:flutter/material.dart';

class ChatMessage extends StatelessWidget {
  final String text;
  final String sender;
  final bool isDarkMode;
  final bool isFile;

  const ChatMessage({
    super.key,
    required this.text,
    required this.sender,
    required this.isDarkMode,
    required this.isFile,
  });

  @override
  Widget build(BuildContext context) {
    // Define colors based on theme and sender
    final backgroundColor = sender == "User"
        ? (isDarkMode ? Colors.blue[800] : Colors.blue)
        : (isDarkMode ? Colors.grey[800] : Colors.grey[200]);

    final textColor = isDarkMode ? Colors.white : Colors.black;
    final iconColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: sender == "User" 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Sender avatar (only for AI messages)
          if (sender != "User") ...[
            CircleAvatar(
              backgroundColor: isDarkMode ? Colors.blue[900] : Colors.blue[200],
              radius: 18,
              child: Icon(
                Icons.auto_awesome,
                size: 18,
                color: isDarkMode ? Colors.white : Colors.blue[800],
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          // Message bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(sender == "User" ? 20 : 4),
                  bottomRight: Radius.circular(sender == "User" ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: sender == "User" 
                    ? CrossAxisAlignment.end 
                    : CrossAxisAlignment.start,
                children: [
                  // File indicator (if applicable)
                  if (isFile) ...[
                    Icon(
                      Icons.insert_drive_file,
                      size: 40,
                      color: iconColor,
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Message text
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                    ),
                  ),
                  
                  // Timestamp
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(DateTime.now()),
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // User avatar (only for user messages)
          if (sender == "User") ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: isDarkMode ? Colors.blue[800] : Colors.blue,
              radius: 18,
              child: Icon(
                Icons.person,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour}:${time.minute.toString().padLeft(2, '0')}";
  }
}