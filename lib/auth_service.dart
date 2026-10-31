import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// Logged-in user details shown on the dashboard.
/// The password is deliberately not part of this object.
class AppUser {
  const AppUser({required this.name, required this.email, required this.phone});

  final String name;
  final String email;
  final String phone;
}

/// Thrown when Firestore cannot be reached or rejects the request.
class LoginException implements Exception {
  const LoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// SHA-256 hex digest of [password], the format used for hashed passwords
/// in the `users` collection (see tool/hash_password.dart).
String hashPassword(String password) =>
    sha256.convert(utf8.encode(password)).toString();

final _sha256Hex = RegExp(r'^[0-9a-fA-F]{64}$');

/// Manual login against the Firestore `users` collection.
/// Firebase Authentication is NOT used.
class AuthService {
  AuthService({CollectionReference<Map<String, dynamic>>? users})
    : _users = users ?? FirebaseFirestore.instance.collection('users');

  final CollectionReference<Map<String, dynamic>> _users;

  /// Returns the matching user, or null when the email or password is wrong.
  /// Throws [LoginException] on Firestore / network errors.
  Future<AppUser?> login(String email, String password) async {
    final enteredEmail = email.trim().toLowerCase();

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      // Fetch only the user document(s) with this email, from the server
      // (never the local cache) so a deleted or changed user cannot log in.
      snapshot = await _users
          .where('email', isEqualTo: enteredEmail)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
    } on FirebaseException catch (e) {
      throw LoginException('Database error (${e.code}). Please try again.');
    } on TimeoutException {
      throw const LoginException(
        'Could not reach the database. Check your connection.',
      );
    } catch (_) {
      throw const LoginException('Something went wrong. Please try again.');
    }

    // Manually verify email and password against the stored credentials.
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final storedEmail = '${data['email'] ?? ''}'.trim().toLowerCase();
      final storedPassword = '${data['password'] ?? ''}';
      if (storedEmail == enteredEmail &&
          _passwordMatches(password, storedPassword)) {
        return AppUser(
          name: '${data['name'] ?? ''}',
          email: '${data['email'] ?? ''}',
          phone: '${data['phone'] ?? ''}',
        );
      }
    }
    return null;
  }

  /// Stored passwords may be a SHA-256 hex hash (recommended) or plain text,
  /// as the exercise permits.
  bool _passwordMatches(String entered, String stored) {
    if (stored.isEmpty) return false;
    if (_sha256Hex.hasMatch(stored)) {
      return hashPassword(entered) == stored.toLowerCase();
    }
    return entered == stored;
  }
}
