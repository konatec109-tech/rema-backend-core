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
  // C'est ici que la Clé Privée dort. Elle ne sort JAMAIS en clair.
  final _storage = const FlutterSecureStorage();
  
  // Algorithme Ed25519 (Standard Industriel - Doc Section 4.1)
  final _algorithm = Ed25519();
  
  SimpleKeyPair? _cachedKeyPair;

  // ===========================================================================
  // 1. GESTION DES CLÉS (KEY MANAGEMENT)
  // ===========================================================================
  
  // Récupère la Clé Publique au format HEX (pour envoi au serveur/marchand)
  Future<String> getPublicKey() async {
    // 1. Si en cache RAM, on renvoie direct (Performance)
    if (_cachedKeyPair != null) {
      final pub = await _cachedKeyPair!.extractPublicKey();
      return _bytesToHex(pub.bytes);
    }

    // 2. Sinon, on cherche dans le stockage sécurisé
    String? storedSeedHex = await _storage.read(key: 'user_private_seed_v2');

    if (storedSeedHex != null) {
      // Restauration de la clé existante
      final seed = _hexToBytes(storedSeedHex);
      _cachedKeyPair = await _algorithm.newKeyPairFromSeed(seed);
    } else {
      // Création d'une nouvelle identité (Premier lancement)
      _cachedKeyPair = await _algorithm.newKeyPair();
      final seed = await _cachedKeyPair!.extractPrivateKeyBytes();
      // On sauvegarde la graine (seed) de manière chiffrée
      await _storage.write(key: 'user_private_seed_v2', value: _bytesToHex(seed));
    }

    final pub = await _cachedKeyPair!.extractPublicKey();
    return _bytesToHex(pub.bytes);
  }

  // ===========================================================================
  // 2. SIGNER UNE TRANSACTION (SIGNING)
  // ===========================================================================
  // Signe le payload "UUID|NONCE|..." avec la clé privée
  Future<String> sign(String message) async {
    try {
      if (_cachedKeyPair == null) await getPublicKey(); // Force init

      final messageBytes = utf8.encode(message);
      
      final signature = await _algorithm.sign(
        messageBytes,
        keyPair: _cachedKeyPair!,
      );

      // On retourne la signature en Hexadécimal (64 octets -> 128 chars hex)
      return _bytesToHex(signature.bytes);
    } catch (e) {
      print("❌ Erreur Signature: $e");
      throw "Echec de la signature cryptographique";
    }
  }

  // ===========================================================================
  // 3. VÉRIFIER UNE SIGNATURE (VERIFYING)
  // ===========================================================================
  // Utilisé par le Marchand pour vérifier que le Client est légitime
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
  // 4. OUTILS UTILITAIRES (HEX CONVERSION)
  // ===========================================================================
  // Convertit [0, 255] -> "00ff"
  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // Convertit "00ff" -> [0, 255]
  List<int> _hexToBytes(String hex) {
    if (hex.length % 2 != 0) hex = '0$hex'; // Padding sécurité
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}