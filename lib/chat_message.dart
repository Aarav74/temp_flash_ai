import 'package:flutter/material.dart';

class ChatMessage extends StatelessWidget {
  final String text;
  final String sender;

  const ChatMessage({super.key, required this.text, required this.sender, required bool isDarkMode, required bool isFile});

  set isDarkMode(bool isDarkMode) {}

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment:
            sender == "User" ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (sender == "FLASH") ...[
            const CircleAvatar(
              backgroundImage: AssetImage('assets/images/Graident Ai Robot.jpg'),
              backgroundColor: Color.fromARGB(255, 237, 138, 255),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: sender == "User" ? Colors.purpleAccent : Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: sender == "User" ? Colors.white : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}