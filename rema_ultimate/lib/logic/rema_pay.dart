import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ✅ IMPORTS INTERNES
import '../models/transaction.dart';
import 'security.dart';
import 'sync.dart';

class RemaPay {
  // --- CONFIGURATION ---
  static const String _backendUrl = "https://rema-backend-core.onrender.com";
  static final SecurityManager _security = SecurityManager();
  static final RemaSync _syncer = RemaSync();
  static const String _serviceId = "com.rema.ultimate"; 
  static const Strategy _strategy = Strategy.P2P_POINT_TO_POINT;

  // EVENTS UI (Pour mettre à jour l'écran)
  static Function(String)? onStatusUpdate;
  static Function(RemaTransaction)? onTransactionReceived;

  // --- INIT ---
  static Future<void> init() async { 
    await _security.getOrCreateIdentity();
    _syncer.pushOfflineTransactions();
  }

  // --- CLOUD & SOLDE ---

  static Future<double> fetchOnlineBalance() async {
    final prefs = await SharedPreferences.getInstance();
    // En mode test, on renvoie ce qu'on a en cache
    return prefs.getDouble('online_balance_cache') ?? 0.0;
  }

  // 🔥 FONCTION CLÉ : TÉLÉCHARGER DES FONDS
  static Future<bool> downloadFunds(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Simulation de l'appel réseau
    onStatusUpdate?.call("🔄 Connexion banque (SIMULATION)...");
    
    // --- ⚠️ MODE TEST ACTIVÉ (SANS BACKEND) ---
    // Dans la vraie vie, on attendrait la réponse du serveur (response.statusCode == 200)
    // Ici, on force le succès pour que tu puisses tester le Bluetooth tout de suite.
    bool serverSaysYes = true; 
    // -------------------------------------------

    if (serverSaysYes) {
      // 1. Crédit du Coffre Local (Offline)
      double currentVault = prefs.getDouble('vault_balance') ?? 0.0;
      await prefs.setDouble('vault_balance', currentVault + amount);

      // 2. Mise à jour visuelle
      double currentOnline = prefs.getDouble('online_balance_cache') ?? 0.0;
      // On évite le négatif pour l'esthétique
      await prefs.setDouble('online_balance_cache', (currentOnline - amount).abs()); 

      onStatusUpdate?.call("✅ (TEST) $amount F ajoutés au coffre !");
      return true;
    } 
    
    return false;
  }

  static Future<double> getOfflineBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('vault_balance') ?? 0.0;
  }

  // --- MOTEUR BLUETOOTH (CŒUR DU SYSTÈME) ---

  static void stopAll() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    await WakelockPlus.disable();
    onStatusUpdate?.call("🛑 Moteur arrêté");
    _syncer.pushOfflineTransactions(); 
  }

  // 1. MODE MARCHAND (Reçoit l'argent)
  static Future<void> startReceiving() async {
    await WakelockPlus.enable(); // CPU à fond
    final prefs = await SharedPreferences.getInstance();
    String myName = prefs.getString('user_name') ?? "Marchand";

    await Nearby().stopAllEndpoints();
    try {
      await Nearby().startAdvertising(
        myName,
        _strategy,
        serviceId: _serviceId,
        onConnectionInitiated: (id, info) async {
          onStatusUpdate?.call("🔗 Client détecté : ${info.endpointName}");
          // Acceptation automatique de la connexion
          await Nearby().acceptConnection(id, onPayLoadRecieved: (endId, payload) async {
            if (payload.type == PayloadType.BYTES) {
              String msg = utf8.decode(payload.bytes!);
              await _processData(msg, endId);
            }
          });
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) onStatusUpdate?.call("✅ Connecté ! Attente paiement...");
        },
        onDisconnected: (id) => onStatusUpdate?.call("Déconnecté"),
      );
      onStatusUpdate?.call("📡 PRÊT À RECEVOIR");
    } catch (e) { onStatusUpdate?.call("Erreur Adv: $e"); }
  }

  // 2. MODE CLIENT (Envoie l'argent)
  static Future<void> scanForMerchants({required Function(String, String) onFound, required Function(String) onLost}) async {
    await WakelockPlus.enable();
    try {
      await Nearby().startDiscovery(
        "Client",
        _strategy,
        serviceId: _serviceId,
        onEndpointFound: (id, name, serviceId) => onFound(id, name),
        onEndpointLost: (id) { if (id != null) onLost(id); },
      );
      onStatusUpdate?.call("🔍 Recherche...");
    } catch (e) { onStatusUpdate?.call("Erreur Scan: $e"); }
  }

  static Future<void> payTarget(String targetId, double amount) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Vérification du solde local avant d'envoyer
    double currentBalance = prefs.getDouble('vault_balance') ?? 0.0;
    if (currentBalance < amount) {
      onStatusUpdate?.call("❌ Solde insuffisant !");
      return;
    }

    await prefs.setDouble('pending_tx_amount', amount);
    await Nearby().stopDiscovery();
    
    Nearby().requestConnection(
      "Client",
      targetId,
      onConnectionInitiated: (id, info) async {
        await Nearby().acceptConnection(id, onPayLoadRecieved: (endId, payload) async {
           if (payload.type == PayloadType.BYTES) {
             await _processData(utf8.decode(payload.bytes!), endId);
           }
        });
      },
      onConnectionResult: (id, status) async {
        if (status == Status.CONNECTED) await _executePayment(id);
      },
      onDisconnected: (id) => onStatusUpdate?.call("Déconnecté"),
    );
  }

  static Future<void> _executePayment(String endpointId) async {
    final prefs = await SharedPreferences.getInstance();
    double amount = prefs.getDouble('pending_tx_amount') ?? 0.0;
    
    // ENVOI (Protocole Debug: Texte simple)
    String payload = "MONTANT:$amount"; 
    await Nearby().sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode(payload)));
    
    // DÉBIT LOCAL IMMÉDIAT
    double current = prefs.getDouble('vault_balance') ?? 0.0;
    await prefs.setDouble('vault_balance', current - amount);
    
    onStatusUpdate?.call("💸 Envoyé !");
    await prefs.remove('pending_tx_amount');
  }

  // 3. TRAITEMENT DES DONNÉES (Cerveau)
  static Future<void> _processData(String data, String endpointId) async {
    final prefs = await SharedPreferences.getInstance();

    if (data.startsWith("MONTANT:")) {
      try {
        double amount = double.parse(data.split(":")[1]);
        
        // A. CRÉDIT LOCAL
        double current = prefs.getDouble('vault_balance') ?? 0.0;
        await prefs.setDouble('vault_balance', current + amount);
        onStatusUpdate?.call("💰 REÇU : $amount F");
        
        // B. CRÉATION PREUVE CRYPTO (Ed25519)
        String myPk = await _security.getPublicKey();
        String txId = const Uuid().v4();
        int timestamp = DateTime.now().millisecondsSinceEpoch;
        
        // On signe : "ID de transaction + Ma clé + Montant + Heure"
        String signature = await _security.sign("$txId|$myPk|$amount|$timestamp");

        RemaTransaction tx = RemaTransaction(
            id: txId, 
            senderPk: "CLIENT_INCONNU", // Le client enverra sa PK dans la V7
            receiverPk: myPk,
            amount: amount, 
            timestamp: timestamp, 
            signature: signature
        );
        
        // C. STOCKAGE QUEUE (Pour la synchro future)
        List<String> queue = prefs.getStringList('offline_batch_queue') ?? [];
        queue.add(jsonEncode(tx.toJson()));
        await prefs.setStringList('offline_batch_queue', queue);

        // D. NOTIFICATION UI
        onTransactionReceived?.call(tx);
        
        // E. CONFIRMATION AU CLIENT
        await Nearby().sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode("FINISH")));
        
        await Future.delayed(const Duration(milliseconds: 1500));
        stopAll();
        
      } catch (e) { onStatusUpdate?.call("Erreur Traitement: $e"); }
    } 
    else if (data == "FINISH") {
      onStatusUpdate?.call("✅ PAIEMENT TERMINÉ");
      await Future.delayed(const Duration(milliseconds: 1500));
      stopAll();
    }
  }
}