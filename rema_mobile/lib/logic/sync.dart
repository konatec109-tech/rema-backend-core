import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'security.dart';

class ApiService {
  // ⚠️ Assure-toi que c'est bien l'URL de ton serveur Render actif
  static const String BASE_URL = "https://rema-backend-core.onrender.com"; 
  
  final Dio _dio = Dio(BaseOptions(
    baseUrl: BASE_URL,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    validateStatus: (status) => status != null && status < 500, // On gère les erreurs 404 nous-mêmes
  ));

  // 1. RECHARGE (Cash-In)
  Future<bool> rechargeOfflineVault(double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String phone = prefs.getString('user_phone') ?? "";
      if (phone.isEmpty) return false;

      print("🔄 Recharge Cloud demandée: $amount");
      final response = await _dio.post("/users/recharge-offline", data: {
        "amount": amount,
        "phone": phone
      });

      if (response.statusCode == 200) {
        String key = 'vault_balance_v3_$phone';
        double current = prefs.getDouble(key) ?? 0.0;
        await prefs.setDouble(key, current + amount);
        return true;
      }
      return false;
    } catch (e) {
      print("❌ Erreur Recharge: $e");
      return false;
    }
  }

  // 2. SYNCHRO (La correction est ici 👇)
  Future<Map<String, dynamic>> syncTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sec = SecurityManager();
      
      String myPk = await sec.getPublicKey(); 
      String myPhone = prefs.getString('user_phone') ?? "";
      String myRawPhone = myPhone.replaceAll(RegExp(r'[^\w]'), '');

      String histKey = 'history_v3_$myPhone';
      List<String> historyRaw = prefs.getStringList(histKey) ?? [];
      
      List<Map<String, dynamic>> transactionsToSend = [];
      
      print("🔄 Analyse de ${historyRaw.length} transactions locales...");

      for (String item in historyRaw) {
        final tx = jsonDecode(item);
        
        // 🛑 FILTRE DE SÉCURITÉ CRITIQUE 🛑
        // 1. On ne sync que ce qui est ENTRANT (IN)
        // 2. On interdit de re-uploader les transactions "BANK_SYSTEM" (Recharges)
        if (tx['type'] == "IN" && 
            tx['sender_pk'] != null && 
            tx['sender_pk'] != "BANK_SYSTEM" && // <--- AJOUT VITAL
            tx['sender_pk'].toString().length > 10) { // Vérif minimale clé valide
           
           // Formatage strict pour Python Pydantic
           transactionsToSend.add({
             "id": tx['id'] ?? "unknown",
             "sender_pk": tx['sender_pk'],
             "amount": (tx['amount'] is int) ? tx['amount'] : (tx['amount'] as double).toInt(), // Force INT pour Python
             "timestamp": tx['timestamp_origin'] ?? 0,
             "phone": tx['partner'] ?? "Inconnu", 
             "target_name": myRawPhone, 
             "signature": tx['signature'] ?? ""
           });
        }
      }

      if (transactionsToSend.isEmpty) {
        return {"status": "empty", "message": "Aucune nouvelle transaction P2P à synchroniser."};
      }

      print("📤 Envoi de ${transactionsToSend.length} transactions au Cloud...");

      final response = await _dio.post("/transactions/sync", data: {
        "merchant_pk": myPk,
        "transactions": transactionsToSend
      });

      print("📥 Réponse Serveur: ${response.statusCode} - ${response.data}");

      if (response.statusCode == 200) {
        return response.data; 
      } else if (response.statusCode == 404) {
        return {"status": "error", "message": "Route API introuvable (404). Vérifier Server."};
      } else {
        return {"status": "error", "message": "Erreur ${response.statusCode}: ${response.data}"};
      }

    } catch (e) {
      print("❌ CRASH SYNC: $e");
      return {"status": "error", "message": "Erreur connexion: $e"};
    }
  }

  // 3. FETCH BALANCE
  Future<double?> fetchUserBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String phone = prefs.getString('user_phone') ?? "";
      if (phone.isEmpty || phone == "...") return null;

      final response = await _dio.get("/users/$phone/balance");
      if (response.statusCode == 200 && response.data != null) {
        var data = response.data;
        double onlineBalance = (data['online_balance'] is int) 
            ? (data['online_balance'] as int).toDouble() 
            : (data['online_balance'] as double);
        await prefs.setDouble('online_balance', onlineBalance);
        return onlineBalance;
      }
      return null;
    } catch (e) { return null; }
  }
}