import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityManager {
  // Singleton : Une seule instance pour toute l'app
  static final SecurityManager _instance = SecurityManager._internal();
  factory SecurityManager() => _instance;
  SecurityManager._internal();

  // Outils
  final _storage = const FlutterSecureStorage();
  final _algorithm = Ed25519(); // 🔥 C'est ici : L'algo demandé
  
  SimpleKeyPair? _cachedKeyPair;

  // 1. INITIALISATION (Récupère ou Crée la clé privée)
  Future<SimpleKeyPair> getOrCreateIdentity() async {
    if (_cachedKeyPair != null) return _cachedKeyPair!;

    // On regarde dans le coffre-fort du téléphone
    String? seedHex = await _storage.read(key: 'rema_private_seed');

    if (seedHex != null) {
      // Restauration : On recrée la clé à partir de la graine (seed)
      final seed = _hexToBytes(seedHex);
      _cachedKeyPair = await _algorithm.newKeyPairFromSeed(seed);
    } else {
      // Création : Nouvelle identité Ed25519
      final newKeyPair = await _algorithm.newKeyPair();
      final seed = await newKeyPair.extractPrivateKeyBytes();
      
      // On sauvegarde la "graine" de manière cryptée
      await _storage.write(key: 'rema_private_seed', value: _bytesToHex(seed));
      _cachedKeyPair = newKeyPair;
    }

    return _cachedKeyPair!;
  }

  // 2. SIGNATURE DE TRANSACTION
  // Input: "UUID|SENDER_PK|AMOUNT|TIMESTAMP"
  // Output: Signature Hexadécimale (64 bytes string)
  Future<String> sign(String message) async {
    final keyPair = await getOrCreateIdentity();
    
    final signature = await _algorithm.sign(
      utf8.encode(message),
      keyPair: keyPair,
    );

    return _bytesToHex(signature.bytes);
  }

  // 3. EXPORT CLÉ PUBLIQUE (Pour le Backend)
  Future<String> getPublicKey() async {
    final keyPair = await getOrCreateIdentity();
    final pubKey = await keyPair.extractPublicKey();
    return _bytesToHex(pubKey.bytes);
  }

  // --- UTILITAIRES HEX (Pour parler au Python) ---
  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  List<int> _hexToBytes(String hex) {
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}