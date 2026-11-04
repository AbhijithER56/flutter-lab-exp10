// Demo launcher for Experiment 10 – runs the real login and dashboard screens
// against an in-memory fake Firestore, so no Firebase project is needed.
//
//   flutter run -d chrome -t tool/demo_main.dart
//
// Demo logins (same data as the widget tests):
//   abhijith@example.com / Pass@123   (password stored as a SHA-256 hash)
//   priya@example.com  / Pass@123   (password stored as plain text)

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_experiment_10_firestore_user_login/auth_service.dart';
import 'package:flutter_experiment_10_firestore_user_login/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = FakeFirebaseFirestore();
  final users = db.collection('users');
  await users.add({
    'name': 'Abhijith E R',
    'email': 'abhijith@example.com',
    'phone': '9876543210',
    'password': hashPassword('Pass@123'),
  });
  await users.add({
    'name': 'Priya',
    'email': 'priya@example.com',
    'phone': '9123456780',
    'password': 'Pass@123',
  });

  runApp(
    MaterialApp(
      title: 'User Login (demo)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
        useMaterial3: true,
      ),
      home: LoginScreen(authService: AuthService(users: users)),
    ),
  );
}
