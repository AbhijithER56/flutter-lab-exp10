// Prints the SHA-256 hash to paste into the `password` field of a user
// document in Firebase Console (same algorithm as hashPassword() in
// lib/auth_service.dart).
//
// Usage: dart run tool/hash_password.dart <password>

// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:crypto/crypto.dart';

void main(List<String> args) {
  if (args.length != 1) {
    print('Usage: dart run tool/hash_password.dart <password>');
    return;
  }
  print(sha256.convert(utf8.encode(args.single)));
}
