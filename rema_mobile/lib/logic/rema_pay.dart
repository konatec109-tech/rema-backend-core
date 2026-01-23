import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ble_peripheral/ble_peripheral.dart' as ble_server;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'security.dart';

class RemaPay {
  static const String SERVICE_UUID = "bf27730d-860a-4e09-889c-2d8b6a9e0fe7";
  static const String CHAR_UUID    = "bf27730d-860a-4e09-889c-2d8b6a9e0fe8";

  static Function(String)? onStatusUpdate;
  static Function(dynamic)? onTransactionReceived;
  
  static bool _isReceivingAllowed = false;
  static StringBuffer _messageBuffer = StringBuffer(); 

  // ===========================================================================
  // 1. INITIALISATION
  // ===========================================================================
  static Future<void> init() async {
    await WakelockPlus.enable();
    if (Platform.isAndroid) {
      if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
        try { await FlutterBluePlus.turnOn(); } catch (e) {}
      }
      await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();
    }
    await ble_server.BlePeripheral.initialize();
  }

  static Future<void> stopAll({bool notify = true}) async {
    _isReceivingAllowed = false;
    _messageBuffer.clear();
    try {
      await FlutterBluePlus.stopScan();
      await ble_server.BlePeripheral.stopAdvertising();
    } catch (e) {}
    if (notify) onStatusUpdate?.call("Standby");
  }

  // ===========================================================================
  // 2. RECEVOIR (MARCHAND)
  // ===========================================================================
  static Future<void> startReceiving() async {
    await stopAll(notify: false);
    await Future.delayed(const Duration(milliseconds: 300));
    await WakelockPlus.enable();
    
    final prefs = await SharedPreferences.getInstance();
    String currentPhone = prefs.getString('user_phone') ?? "Inconnu";
    
    // Nom court pour être visible partout
    String safeName = "R:${currentPhone.replaceAll(RegExp(r'[^\w]'), '')}";
    if(safeName.length > 15) safeName = safeName.substring(0, 15);

    _isReceivingAllowed = true;
    _messageBuffer.clear();
    onStatusUpdate?.call("📡 Prêt : $safeName");

    try {
      await ble_server.BlePeripheral.addService(
        ble_server.BleService(
          uuid: SERVICE_UUID,
          primary: true,
          characteristics: [
            ble_server.BleCharacteristic(
              uuid: CHAR_UUID,
              properties: [ 
                ble_server.CharacteristicProperties.writeWithoutResponse.index,
                ble_server.CharacteristicProperties.notify.index // <--- IMPORTANT: On active NOTIFY pour répondre
              ],
              permissions: [ ble_server.AttributePermissions.writeable.index, ble_server.AttributePermissions.readable.index ], 
              value: null,
            ),
          ],
        ),
      );
      // Publicité légère (Nom seul)
      await ble_server.BlePeripheral.startAdvertising(services: [], localName: safeName);
    } catch (e) {
      stopAll();
    }

    ble_server.BlePeripheral.setWriteRequestCallback((deviceId, characteristicId, offset, value) {
        if (!_isReceivingAllowed) return null;
        if (value != null) {
           try {
             String chunk = utf8.decode(value);
             _messageBuffer.write(chunk);
             String totalMessage = _messageBuffer.toString();
             
             if (totalMessage.endsWith("#")) {
               String cleanMsg = totalMessage.substring(0, totalMessage.length - 1);
               _processSecurePayment(cleanMsg);
               _messageBuffer.clear();
             }
           } catch (e) {}
        }
        return null;
    });
  }

  static void _processSecurePayment(String msg) async {
      msg = msg.trim();
      if (!msg.startsWith("PAY:")) return;

      try {
        List<String> parts = msg.split(":");
        if (parts.length < 3) return;

        String dataContent = parts[1]; 
        String signature = parts[2];
        List<String> innerParts = dataContent.split("|");
        
        String senderPk = innerParts[0];
        double amount = double.parse(innerParts[1]);
        String timestampStr = innerParts[2];
        String senderPhone = (innerParts.length > 3) ? innerParts[3] : "Inconnu";
        String targetNameInMsg = (innerParts.length > 4) ? innerParts[4] : ""; 

        final prefs = await SharedPreferences.getInstance();
        String currentPhone = prefs.getString('user_phone') ?? "Inconnu";
        String myRawNumber = currentPhone.replaceAll(RegExp(r'[^\w]'), '');
        
        if (targetNameInMsg.replaceAll("R:", "").trim() != myRawNumber) return;

        final sec = SecurityManager();
        if (await sec.verifySignature(dataContent, signature, senderPk)) {
          String balanceKey = 'vault_balance_v3_$currentPhone';
          double current = prefs.getDouble(balanceKey) ?? 0.0;
          await prefs.setDouble(balanceKey, current + amount);
          
          await _saveTransaction(
            phone: currentPhone, amount: amount, partner: senderPhone, 
            type: "IN", signature: signature, senderPk: senderPk,
            timestamp: int.parse(timestampStr), txId: DateTime.now().millisecondsSinceEpoch.toString()
          );

          // 👇 LE HANDSHAKE : ON RÉPOND "ACK" (J'ai reçu !)
          try {
             await ble_server.BlePeripheral.updateCharacteristic(
                 characteristicId: CHAR_UUID,
                 value: utf8.encode("ACK") 
             );
          } catch(e) { print("Erreur ACK: $e"); }

          onTransactionReceived?.call({ "amount": amount, "sender": senderPk, "phone": senderPhone });
          onStatusUpdate?.call("✅ REÇU DE $senderPhone");
        }
      } catch (e) { print(e); }
  }

  // ===========================================================================
  // 3. PAYER (CLIENT - AVEC HANDSHAKE)
  // ===========================================================================
  static Future<void> scanForMerchants({required Function(String, String) onFound}) async {
    await stopAll();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10), androidScanMode: AndroidScanMode.lowLatency);
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        String n = r.advertisementData.localName.isNotEmpty ? r.advertisementData.localName : r.device.platformName;
        if (n.startsWith("R:")) onFound(r.device.remoteId.str, n.substring(2));
      }
    });
  }

  static Future<void> payTarget(String merchantId, String targetName, double amount) async {
    final prefs = await SharedPreferences.getInstance();
    String myPhone = prefs.getString('user_phone') ?? "Inconnu";
    String balanceKey = 'vault_balance_v3_$myPhone';
    double currentBalance = prefs.getDouble(balanceKey) ?? 0.0;

    if (currentBalance < amount) {
        onStatusUpdate?.call("❌ SOLDE INSUFFISANT");
        throw "Fonds insuffisants";
    }

    BluetoothDevice device = BluetoothDevice.fromId(merchantId);
    try { await FlutterBluePlus.stopScan(); } catch(e) {}
    if (Platform.isAndroid) { try { await device.removeBond(); } catch(e) {} }

    bool isConnected = false;
    int attempts = 0;
    while (!isConnected && attempts < 3) { 
      try {
        attempts++;
        onStatusUpdate?.call("Connexion ($attempts)...");
        await device.connect(autoConnect: false).timeout(const Duration(seconds: 5));
        isConnected = true;
      } catch (e) {
        try { await device.disconnect(); } catch (_) {}
      }
    }

    if (!isConnected) throw "Impossible de joindre le terminal.";

    try {
      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? targetChar;
      for (var s in services) {
        if (s.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toLowerCase() == CHAR_UUID.toLowerCase()) targetChar = c;
          }
        }
      }

      if (targetChar != null) {
        // 👇 HANDSHAKE : ON ÉCOUTE LA RÉPONSE AVANT D'ENVOYER
        await targetChar.setNotifyValue(true);
        Completer<bool> ackCompleter = Completer<bool>();
        
        StreamSubscription? sub = targetChar.lastValueStream.listen((value) {
            String response = utf8.decode(value);
            if (response == "ACK" && !ackCompleter.isCompleted) {
              ackCompleter.complete(true); // C'est validé !
            }
        });

        onStatusUpdate?.call("Envoi sécurisé...");
        final sec = SecurityManager();
        final String myPk = await sec.getPublicKey();
        final int timestamp = DateTime.now().millisecondsSinceEpoch;
        
        final String contract = "$myPk|${amount.toInt()}|$timestamp|$myPhone|$targetName";
        final String signature = await sec.sign(contract);
        String payload = "PAY:$contract:$signature#";
        
        // Envoi par petits morceaux pour éviter les bouchons
        await _sendInChunks(targetChar, payload);
        
        onStatusUpdate?.call("Attente validation...");
        
        // On attend le ACK pendant 10 secondes max
        try {
          await ackCompleter.future.timeout(const Duration(seconds: 10));
          
          // SUCCÈS : On a reçu le ACK, on débite !
          await prefs.setDouble(balanceKey, currentBalance - amount);
          await _saveTransaction(
              phone: myPhone, amount: amount, partner: targetName, 
              type: "OUT", signature: signature, senderPk: myPk, timestamp: timestamp
          );
          onStatusUpdate?.call("✅ PAIEMENT RÉUSSI !");
          
        } catch (timeout) {
          throw "Pas de réponse du marchand (Timeout)";
        } finally {
          await sub?.cancel();
        }

        try { await device.disconnect(); } catch (_) {}
      } else { throw "Service introuvable"; }
    } catch (e) {
      try { await device.disconnect(); } catch (_) {}
      onStatusUpdate?.call("❌ ERREUR: $e");
      rethrow;
    }
  }

  // Helper pour couper les messages (Samsung Friendly)
  static Future<void> _sendInChunks(BluetoothCharacteristic c, String payload) async {
    int chunkSize = 20; 
    List<int> bytes = utf8.encode(payload);
    for (int i = 0; i < bytes.length; i += chunkSize) {
      int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      await c.write(bytes.sublist(i, end), withoutResponse: true);
      await Future.delayed(const Duration(milliseconds: 25)); 
    }
  }

  // --- DATA ---
  static Future<void> _saveTransaction({required String phone, required double amount, required String partner, required String type, required String signature, String? senderPk, int? timestamp, String? txId}) async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'history_v3_$phone'; 
    List<String> history = prefs.getStringList(key) ?? [];
    Map<String, dynamic> tx = {
      "id": txId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      "amount": amount, "partner": partner, "type": type, "signature": signature,
      "sender_pk": senderPk ?? "", "timestamp_origin": timestamp ?? 0, 
      "date": DateTime.now().toIso8601String()
    };
    history.insert(0, jsonEncode(tx));
    if (history.length > 50) history = history.sublist(0, 50);
    await prefs.setStringList(key, history);
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String phone = prefs.getString('user_phone') ?? "Inconnu";
    List<String> h = prefs.getStringList('history_v3_$phone') ?? [];
    return h.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  static Future<double> getOfflineBalance() async {
    final p = await SharedPreferences.getInstance();
    String phone = p.getString('user_phone') ?? "Inconnu";
    return p.getDouble('vault_balance_v3_$phone') ?? 0.0;
  }
}