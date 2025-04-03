import 'package:flutter/material.dart';

class ChatMessage extends StatelessWidget {
  final String text;
  final String sender;
  final bool isUser;  // Required parameter to identify user messages
  final bool isFile;
  final Color userColor;
  final Color aiColor;
  final Color textColor;

  const ChatMessage({
    super.key,
    required this.text,
    required this.sender,
    required this.isUser,
    required this.isFile,
    required this.userColor,
    required this.aiColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isUser ? userColor : aiColor;
    // ignore: deprecated_member_use
    final iconColor = textColor.withOpacity(0.7);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI avatar (left side for AI messages)
          if (!isUser) ...[
            CircleAvatar(
              // ignore: deprecated_member_use
              backgroundColor: aiColor.withOpacity(0.8),
              radius: 18,
              child: Icon(
                Icons.auto_awesome,
                size: 18,
                color: textColor,
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
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (isFile) ...[
                    Icon(
                      Icons.insert_drive_file,
                      size: 40,
                      color: iconColor,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(DateTime.now()),
                    style: TextStyle(
                      // ignore: deprecated_member_use
                      color: textColor.withOpacity(0.6),
                      fontSize: 10,
                    ),
              )],
              ),
            ),
          ),
          
          // User avatar (right side for user messages)
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: userColor,
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