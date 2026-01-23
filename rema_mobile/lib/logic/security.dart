import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityManager {
  // Singleton : On s'assure qu'il n'y a qu'une seule instance de sécurité en mémoire
  static final SecurityManager _instance = SecurityManager._internal();
  factory SecurityManager() => _instance;
  SecurityManager._internal();

  // Le coffre-fort sécurisé (utilise la puce Hardware du téléphone : Secure Enclave / Keystore)
  final _storage = const FlutterSecureStorage();
  
  // L'algorithme Ed25519 (Rapide, Sécurisé, Standard industriel)
  final _algorithm = Ed25519();
  
  SimpleKeyPair? _cachedKeyPair;

  // ===========================================================================
  // 1. RÉCUPÉRER OU CRÉER L'IDENTITÉ (Clé Publique)
  // ===========================================================================
  Future<String> getPublicKey() async {
    // A. Si déjà chargé en mémoire RAM, on renvoie direct (Ultra rapide)
    if (_cachedKeyPair != null) {
      final pub = await _cachedKeyPair!.extractPublicKey();
      return _bytesToHex(pub.bytes);
    }

    // B. Sinon, on cherche dans le coffre-fort du téléphone
    // On utilise '_v2' pour être sûr d'avoir une clé propre
    String? storedSeed = await _storage.read(key: 'rema_identity_seed_v2');

    if (storedSeed != null) {
      // ✅ Restauration : Le téléphone connaît déjà son identité
      List<int> seedBytes = _hexToBytes(storedSeed);
      _cachedKeyPair = await _algorithm.newKeyPairFromSeed(seedBytes);
    } else {
      // 🆕 Création : Nouvelle identité générée (Première ouverture)
      _cachedKeyPair = await _algorithm.newKeyPair();
      
      // On extrait la graine (Seed) et on la sauvegarde de manière chiffrée
      final seed = await _cachedKeyPair!.extractPrivateKeyBytes();
      await _storage.write(key: 'rema_identity_seed_v2', value: _bytesToHex(seed));
    }

    // On retourne la Clé Publique (Celle qu'on envoie au serveur Python)
    final pub = await _cachedKeyPair!.extractPublicKey();
    return _bytesToHex(pub.bytes);
  }

  // ===========================================================================
  // 2. SIGNER UN MESSAGE (Preuve mathématique)
  // ===========================================================================
  Future<String> sign(String message) async {
    // On s'assure d'avoir la clé chargée
    if (_cachedKeyPair == null) await getPublicKey();

    final messageBytes = utf8.encode(message);
    
    // Signature mathématique pure (ne dépend pas de la marque du téléphone)
    final signature = await _algorithm.sign(
      messageBytes,
      keyPair: _cachedKeyPair!,
    );

    return _bytesToHex(signature.bytes);
  }

  // ===========================================================================
  // 3. VÉRIFIER UNE SIGNATURE (Utilisé par le Marchand pour vérifier le Client)
  // ===========================================================================
  Future<bool> verifySignature(String message, String signatureHex, String publicKeyHex) async {
    try {
      final messageBytes = utf8.encode(message);
      final signatureBytes = _hexToBytes(signatureHex);
      final publicKeyBytes = _hexToBytes(publicKeyHex);

      final pubKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
      final signature = Signature(signatureBytes, publicKey: pubKey);

      // Vérification mathématique
      final isValid = await _algorithm.verify(
        messageBytes,
        signature: signature,
      );
      
      return isValid;
    } catch (e) {
      print("❌ Erreur Crypto Verif: $e");
      return false;
    }
  }

  // ===========================================================================
  // UTILITAIRES (Conversion Hexadécimale pour Python)
  // ===========================================================================
  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  List<int> _hexToBytes(String hex) {
    List<int> bytes = [];
    if (hex.length % 2 != 0) hex = '0$hex';
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}