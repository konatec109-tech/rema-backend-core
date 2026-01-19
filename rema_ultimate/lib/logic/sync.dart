import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'security.dart'; // On appelle la sécu pour l'ID device

class RemaSync {
  // 🔥 Mets ici l'URL de ton backend Python (Render)
  static const String _backendUrl = "https://rema-backend-core.onrender.com"; 
  
  bool _isSyncing = false;

  Future<int> pushOfflineTransactions() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    
    final prefs = await SharedPreferences.getInstance();
    List<String> rawQueue = prefs.getStringList('offline_batch_queue') ?? [];

    if (rawQueue.isEmpty) { 
      _isSyncing = false; 
      return 0; 
    }

    try {
      // Préparation du Batch
      List<Map<String, dynamic>> txList = rawQueue
          .map((str) => jsonDecode(str) as Map<String, dynamic>)
          .toList();
      
      String myPk = await SecurityManager().getPublicKey(); 

      // Structure qui plait au Backend
      Map<String, dynamic> batchRequest = {
        "batch_id": "SYNC_${DateTime.now().millisecondsSinceEpoch}",
        "device_id": myPk, // sender_pk
        "transactions": txList 
      };

      print("☁️ Envoi de ${txList.length} transactions...");

      final response = await http.post(
        Uri.parse("$_backendUrl/transactions/sync/batch"), // Vérifie cette route API
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(batchRequest)
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Synchro réussie !");
        await prefs.setStringList('offline_batch_queue', []); // On vide la file
        _isSyncing = false;
        return txList.length;
      } else {
        print("❌ Erreur Serveur (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("❌ Erreur Réseau: $e");
    } finally {
      _isSyncing = false;
    }
    return 0;
  }
}