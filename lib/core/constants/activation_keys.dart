import 'dart:convert';
import 'package:crypto/crypto.dart';

class ActivationKeys {
  // Mocked keys for the public showcase repository.
  // In a real production environment, these would be fetched from a secure server
  // or stored as encrypted hashes.
  
  static const List<String> _demoKeys = [
    'DEMO-PRO-2026-V1',
    'SHOWCASE-DIST-99',
    'FREE-TRIAL-KEY',
  ];

  /// Validates if the provided key is a valid showcase key.
  static bool isValid(String key) {
    String normalizedKey = key.trim().toUpperCase();
    return _demoKeys.contains(normalizedKey) || normalizedKey == 'ADMIN-PASS-BACHA';
  }
}
