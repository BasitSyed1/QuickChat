import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

class MessageCrypto {
  static const _appSecret = String.fromEnvironment(
    'MESSAGE_SECRET',
    defaultValue: 'quickchat-message-secret-v1',
  );
  static const _prefix = 'v1:';

  static Key _keyFor(String conversationId) {
    final digest = sha256.convert(utf8.encode('$_appSecret:$conversationId'));
    return Key(Uint8List.fromList(digest.bytes));
  }

  static String encryptText(String plaintext, String conversationId) {
    final encrypter =
        Encrypter(AES(_keyFor(conversationId), mode: AESMode.gcm));
    final iv = IV.fromSecureRandom(12);
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '$_prefix${base64Encode(iv.bytes)}:${encrypted.base64}';
  }

  static String decryptText(String stored, String conversationId) {
    if (!stored.startsWith(_prefix)) return stored;
    try {
      final parts = stored.substring(_prefix.length).split(':');
      if (parts.length != 2) return stored;
      final iv = IV(base64Decode(parts[0]));
      final encrypted = Encrypted.fromBase64(parts[1]);
      final encrypter =
          Encrypter(AES(_keyFor(conversationId), mode: AESMode.gcm));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (_) {
      return '[unable to decrypt]';
    }
  }
}
