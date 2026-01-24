import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityManager {
  // Singleton : Une seule instance de sécurité pour toute l'app
  static final SecurityManager _instance = SecurityManager._internal();
  factory SecurityManager() => _instance;
  SecurityManager._internal();

  // Le coffre-fort sécurisé (Keystore / Keychain)
  final _storage = const FlutterSecureStorage();
  
  // Algorithme de signature (Ed25519)
  final _algorithm = Ed25519();
  
  // 🔥 AJOUT : Algorithme de hachage pour le PIN (SHA-256)
  final _hashAlgo = Sha256();
  
  SimpleKeyPair? _cachedKeyPair;

  // ===========================================================================
  // 1. GESTION DES CLÉS (KEY MANAGEMENT)
  // ===========================================================================
  
  // Récupère la Clé Publique (Hex)
  Future<String> getPublicKey() async {
    if (_cachedKeyPair != null) {
      final pub = await _cachedKeyPair!.extractPublicKey();
      return _bytesToHex(pub.bytes);
    }

    String? storedSeedHex = await _storage.read(key: 'user_private_seed_v2');

    if (storedSeedHex != null) {
      final seed = _hexToBytes(storedSeedHex);
      _cachedKeyPair = await _algorithm.newKeyPairFromSeed(seed);
    } else {
      _cachedKeyPair = await _algorithm.newKeyPair();
      final seed = await _cachedKeyPair!.extractPrivateKeyBytes();
      await _storage.write(key: 'user_private_seed_v2', value: _bytesToHex(seed));
    }

    final pub = await _cachedKeyPair!.extractPublicKey();
    return _bytesToHex(pub.bytes);
  }

  // ===========================================================================
  // 2. SIGNATURE (OFFLINE PAYMENT)
  // ===========================================================================
  
  Future<String> sign(String message) async {
    try {
      if (_cachedKeyPair == null) await getPublicKey(); // Force init

      final messageBytes = utf8.encode(message);
      
      final signature = await _algorithm.sign(
        messageBytes,
        keyPair: _cachedKeyPair!,
      );

      return _bytesToHex(signature.bytes);
    } catch (e) {
      print("❌ Erreur Signature: $e");
      throw "Echec de la signature cryptographique";
    }
  }

  // ===========================================================================
  // 3. VÉRIFICATION (SÉCURITÉ MARCHAND)
  // ===========================================================================
  
  Future<bool> verifySignature(String message, String signatureHex, String publicKeyHex) async {
    try {
      final messageBytes = utf8.encode(message);
      final signatureBytes = _hexToBytes(signatureHex);
      final publicKeyBytes = _hexToBytes(publicKeyHex);

      final pubKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
      final signature = Signature(signatureBytes, publicKey: pubKey);

      final isValid = await _algorithm.verify(
        messageBytes,
        signature: signature,
      );
      
      return isValid;
    } catch (e) {
      print("⚠️ Signature Invalide: $e");
      return false;
    }
  }

  // ===========================================================================
  // 4. HACHAGE PIN (C'EST LA FONCTION QUI MANQUAIT !) ⚠️
  // ===========================================================================
  
  // Transforme "1234" en un hash SHA-256 sécurisé
  Future<String> hashPin(String pin) async {
    final pinBytes = utf8.encode(pin);
    final hash = await _hashAlgo.hash(pinBytes);
    return _bytesToHex(hash.bytes);
  }

  // ===========================================================================
  // 5. OUTILS UTILITAIRES (HEX)
  // ===========================================================================
  
  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  List<int> _hexToBytes(String hex) {
    if (hex.length % 2 != 0) hex = '0$hex';
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}