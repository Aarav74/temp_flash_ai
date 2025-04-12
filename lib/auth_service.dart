import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'], // Request additional user data
  );

  // Current user getter
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email & Password Sign In
  Future<User?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _authErrorHandler(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Email & Password Sign Up
  Future<User?> createUserWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _authErrorHandler(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Google Sign In
  Future<User?> signInWithGoogle() async {
    try {
      // Sign out first to ensure clean state
      await _googleSignIn.signOut();

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Create Firebase credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _authErrorHandler(e);
    } catch (e) {
      throw 'Failed to sign in with Google. Please try again.';
    }
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _authErrorHandler(e);
    } catch (e) {
      throw 'Failed to send password reset email. Please try again.';
    }
  }

  // Update Email
  Future<void> updateEmail(String newEmail) async {
    try {
      // ignore: deprecated_member_use
      await currentUser?.updateEmail(newEmail.trim());
    } on FirebaseAuthException catch (e) {
      throw _authErrorHandler(e);
    } catch (e) {
      throw 'Failed to update email. Please try again.';
    }
  }

  // Update Password
  Future<void> updatePassword(String newPassword) async {
    try {
      await currentUser?.updatePassword(newPassword.trim());
    } on FirebaseAuthException catch (e) {
      throw _authErrorHandler(e);
    } catch (e) {
      throw 'Failed to update password. Please try again.';
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw 'Failed to sign out. Please try again.';
    }
  }

  // Delete Account
  Future<void> deleteAccount() async {
    try {
      await currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw _authErrorHandler(e);
    } catch (e) {
      throw 'Failed to delete account. Please try again.';
    }
  }

  // Error Handler
  String _authErrorHandler(FirebaseAuthException e) {
    switch (e.code) {
      // Common errors
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      
      // Sign up errors
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      
      // Google auth errors
      case 'account-exists-with-different-credential':
        return 'Account already exists with different credentials.';
      case 'invalid-credential':
        return 'The authentication credential is invalid.';
      // Network errors
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      
      // Other errors
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please log in again.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      
      default:
        return e.message ?? 'An unexpected error occurred. Please try again.';
    }
  }
}