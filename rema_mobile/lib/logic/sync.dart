import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'security.dart';

class ApiService {
  // ⚠️ Vérifie que c'est bien l'URL de ton serveur (Render ou IP locale)
  static const String BASE_URL = "https://rema-backend-core.onrender.com"; 
  
  final Dio _dio = Dio(BaseOptions(
    baseUrl: BASE_URL,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    validateStatus: (status) => status != null && status < 500,
  ));

  // ===========================================================================
  // 1. RECHARGE DU COFFRE-FORT (CASH-IN)
  // ===========================================================================
  // 🔥 Entrée : INT (Atomic Unit). Ex: 5000 FCFA -> 5000.
  Future<bool> rechargeOfflineVault(int amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String phone = prefs.getString('user_phone') ?? "";
      if (phone.isEmpty) return false;

      print("🔄 Recharge Cloud demandée: $amount");
      
      // On envoie un entier strict au serveur
      final response = await _dio.post("/users/recharge-offline", data: {
        "amount": amount, 
        "phone": phone
      });

      if (response.statusCode == 200) {
        String key = 'vault_balance_v3_$phone';
        int current = prefs.getInt(key) ?? 0; // 🔥 Lecture INT
        await prefs.setInt(key, current + amount);
        return true;
      }
      return false;
    } catch (e) {
      print("Erreur Recharge: $e");
      return false;
    }
  }

  // ===========================================================================
  // 2. SYNCHRONISATION DES TRANSACTIONS (BATCH UPLOAD + BLACKLIST)
  // ===========================================================================
  Future<Map<String, dynamic>> syncTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String phone = prefs.getString('user_phone') ?? "";
      String myPk = await SecurityManager().getPublicKey();

      // A. MISE À JOUR SÉCURITÉ (Le "Gossip Protocol") [Doc Section 7.1]
      // Avant d'envoyer nos ventes, on télécharge la liste des téléphones volés.
      await updateSecurityBlacklist();

      // B. PRÉPARATION DES DONNÉES
      List<String> history = prefs.getStringList('history_v3_$phone') ?? [];
      if (history.isEmpty) return {"status": "empty", "message": "Rien à sync."};

      List<Map<String, dynamic>> transactionsToSend = [];

      for (String jsonStr in history) {
        Map<String, dynamic> tx = jsonDecode(jsonStr);
        
        // 🔍 FILTRE INTELLIGENT :
        // On ne synchronise que ce qui est complet et signé.
        if (tx['signature'] != null && tx['signature'].toString().isNotEmpty) {
          
          // MAPPING STRICT vers le Backend Python (SingleTransaction)
          transactionsToSend.add({
            "uuid": tx['uuid'],           // [Doc] UUID v4
            "protocol_ver": tx['protocol_ver'] ?? 1,
            "nonce": tx['nonce'],         // [Doc] Anti-Rejeu
            "timestamp": tx['timestamp'], // [Doc] Time
            "sender_pk": tx['sender_pk'],
            "receiver_pk": myPk,          // C'est moi qui synchronise
            "amount": tx['amount'],       // 🔥 INT STRICT
            "currency": tx['currency'] ?? 952,
            "signature": tx['signature'], // [Doc] Preuve Ed25519
            "type": "OFFLINE_PAYMENT"
          });
        }
      }

      if (transactionsToSend.isEmpty) return {"status": "empty"};

      print("📤 Envoi de ${transactionsToSend.length} transactions au Cloud...");

      // C. ENVOI DU BATCH AU SERVEUR
      final response = await _dio.post("/transactions/sync", data: {
        "merchant_pk": myPk,
        "batch_id": "${DateTime.now().millisecondsSinceEpoch}",
        "device_id": phone, 
        "count": transactionsToSend.length,
        "sync_timestamp": DateTime.now().toIso8601String(),
        "transactions": transactionsToSend
      });

      print("📥 Réponse Serveur: ${response.statusCode}");

      if (response.statusCode == 200) {
        // Optionnel : Nettoyer l'historique local ou le marquer "synced"
        // Pour l'instant, on laisse tel quel pour la traçabilité locale
        return response.data; 
      } else {
        return {"status": "error", "message": "Erreur ${response.statusCode}: ${response.data}"};
      }

    } catch (e) {
      print("❌ CRASH SYNC: $e");
      return {"status": "error", "message": "Erreur connexion: $e"};
    }
  }

  // ===========================================================================
  // 3. RECUPERER LE SOLDE (FETCH BALANCE)
  // ===========================================================================
  // 🔥 Retourne un INT maintenant
  Future<int?> fetchUserBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String phone = prefs.getString('user_phone') ?? "";
      if (phone.isEmpty) return null;

      final response = await _dio.get("/users/$phone/balance");
      
      if (response.statusCode == 200 && response.data != null) {
        var data = response.data;
        // Le serveur envoie maintenant 'balance_atomic' (int)
        if (data['balance_atomic'] != null) {
           return data['balance_atomic'] as int;
        } else if (data['balance'] != null) {
           // Fallback temporaire si le serveur est vieux
           return (data['balance'] as num).toInt();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ===========================================================================
  // 4. TÉLÉCHARGER LA LISTE DES VOLEURS (BLACKLIST / CRL) [Doc Section 7.1]
  // ===========================================================================
  Future<void> updateSecurityBlacklist() async {
    try {
      print("👮 Vérification de la liste noire...");
      final response = await _dio.get("/users/security/blacklist");
      
      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        List<String> bannedKeys = data.cast<String>();

        final prefs = await SharedPreferences.getInstance();
        
        // On sauvegarde la liste localement pour l'utiliser Offline
        // C'est rema_pay.dart qui lira cette liste pour bloquer les paiements
        await prefs.setStringList('local_blacklist_v1', bannedKeys);
        
        print("✅ Blacklist mise à jour : ${bannedKeys.length} clés bannies.");
      }
    } catch (e) {
      print("⚠️ Impossible de mettre à jour la blacklist (Mode Offline maintenu)");
    }
  }
}