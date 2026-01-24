import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'security.dart';

class ApiService {
  // ⚠️ C'est l'URL de ton serveur Render (Backend Core)
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
      // Correspond à la route backend: /users/recharge-offline
      final response = await _dio.post("/users/recharge-offline", data: {
        "amount": amount, 
        "phone": phone
      });

      if (response.statusCode == 200) {
        // Si le serveur valide, on crée l'argent dans le téléphone
        String key = 'vault_balance_v3_$phone';
        int current = prefs.getInt(key) ?? 0; 
        await prefs.setInt(key, current + amount);
        return true;
      }
      return false;
    } catch (e) {
      print("❌ Erreur Recharge: $e");
      return false;
    }
  }

  // ===========================================================================
  // 2. SYNCHRONISATION DES TRANSACTIONS (UPLOAD)
  // ===========================================================================
  Future<Map<String, dynamic>> syncTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String phone = prefs.getString('user_phone') ?? "";
      String myPk = await SecurityManager().getPublicKey();

      // Étape 1 : On met à jour la liste des voleurs avant de sync
      await updateSecurityBlacklist();

      // Étape 2 : On récupère l'historique local
      List<String> history = prefs.getStringList('history_v3_$phone') ?? [];
      if (history.isEmpty) return {"status": "empty", "message": "Rien à sync."};

      List<Map<String, dynamic>> transactionsToSend = [];

      // Étape 3 : On prépare le colis pour le serveur
      for (String jsonStr in history) {
        Map<String, dynamic> tx = jsonDecode(jsonStr);
        
        // On ne sync que ce qui a une signature crypto valide
        if (tx['signature'] != null && tx['signature'].toString().isNotEmpty) {
          
          transactionsToSend.add({
            // Champs obligatoires du protocole
            "uuid": tx['uuid'],
            "protocol_ver": tx['protocol_ver'] ?? 1,
            "nonce": tx['nonce'],
            "timestamp": tx['timestamp'],
            "sender_pk": tx['sender_pk'],
            "receiver_pk": myPk, // C'est moi qui sync, donc je suis le receveur (ou l'émetteur sync)
            "amount": tx['amount'],
            "currency": tx['currency'] ?? 952,
            "signature": tx['signature'],
            "type": "OFFLINE_PAYMENT",
            
            // 🔥 CRITIQUE : C'est ici qu'on envoie l'info Visa/FedaPay au serveur
            "metadata": tx['metadata'] ?? "{}" 
          });
        }
      }

      if (transactionsToSend.isEmpty) return {"status": "empty"};

      print("📤 Envoi de ${transactionsToSend.length} transactions vers le Cloud...");

      // Étape 4 : Envoi du Batch (Carton)
      // Correspond à la route backend: /transactions/sync
      final response = await _dio.post("/transactions/sync", data: {
        "merchant_pk": myPk,
        "batch_id": "${DateTime.now().millisecondsSinceEpoch}",
        "device_id": phone, 
        "count": transactionsToSend.length,
        "sync_timestamp": DateTime.now().toIso8601String(),
        "transactions": transactionsToSend
      });

      if (response.statusCode == 200) {
        print("✅ Sync Réussie !");
        return response.data; 
      } else {
        print("⚠️ Erreur Serveur: ${response.statusCode} - ${response.data}");
        return {"status": "error", "message": "Erreur ${response.statusCode}: ${response.data}"};
      }

    } catch (e) {
      print("❌ Erreur Connexion Sync: $e");
      return {"status": "error", "message": "Erreur connexion: $e"};
    }
  }

  // ===========================================================================
  // 3. VÉRIFIER SOLDE ONLINE (BANQUE)
  // ===========================================================================
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
      // Si pas de connexion, on garde l'ancienne liste, ce n'est pas grave.
      print("⚠️ Pas de connexion pour maj blacklist.");
    }
  }
}