import 'package:flutter/material.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String buttonText;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.buttonText = 'Sign in with Google',
  });

  @override
  Widget build(BuildContext context) {
    return SignInButton(
      Buttons.Google,
      text: buttonText,
      onPressed: onPressed,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
    );
  }
}