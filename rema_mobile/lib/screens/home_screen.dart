import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; 

import '../logic/rema_pay.dart'; 
import '../logic/sync.dart'; 
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _myPhone = "...";
  double _balance = 0.0; // OFFLINE
  double _onlineBalance = 0.0; // ONLINE (Cloud)
  
  bool _isReceiving = false;    
  List<Map<String, dynamic>> _history = [];
  Timer? _balanceTimer;

  @override
  void initState() {
    super.initState();
    
    // 👇 AJOUT CRITIQUE ICI 👇
    // Lance le moteur Bluetooth et demande les permissions au démarrage
    RemaPay.init(); 
    
    _loadData();
    
    // Timer Cloud (Toutes les 10s)
    _balanceTimer = Timer.periodic(const Duration(seconds: 10), (t) => _fetchCloudBalance());
    
    // Écouteur Transaction
    RemaPay.onTransactionReceived = (tx) {
      _loadData(); 
      if(mounted) {
         double amount = (tx['amount'] is int) ? (tx['amount'] as int).toDouble() : (tx['amount'] as double);
         String sender = tx['phone'] ?? "Inconnu";
         _showSuccessPopup(amount, "Reçu de $sender");
      }
    };
    
    // Écouteur Status
    RemaPay.onStatusUpdate = (msg) {
      if (mounted && msg.contains("Invisible")) {
        setState(() => _isReceiving = false);
      }
    };
  }
  
  @override
  void dispose() {
    _balanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    double v = await RemaPay.getOfflineBalance();
    List<Map<String, dynamic>> h = await RemaPay.getHistory();
    _fetchCloudBalance(); // Appel immédiat au cloud

    if(mounted) {
      setState(() {
        _myPhone = prefs.getString('user_phone') ?? "Inconnu";
        _balance = v;
        _history = h;
      });
    }
  }
  
  Future<void> _fetchCloudBalance() async {
    final api = ApiService();
    double? online = await api.fetchUserBalance();
    if(online != null && mounted) {
      setState(() => _onlineBalance = online);
    }
  }

  // --- ACTIONS ---

  void _toggleReceive() async {
    setState(() => _isReceiving = !_isReceiving);
    if (_isReceiving) {
      await RemaPay.startReceiving(); 
    } else {
      await RemaPay.stopAll(); 
    }
  }

  // LE SCAN (Pop-up comme avant)
  void _startScan() {
    showDialog(
      context: context, 
      barrierDismissible: true,
      builder: (ctx) => _RadarDialog(
        onSelected: (id, name) {
          Navigator.pop(ctx); 
          // Une fois le destinataire choisi, on demande le montant
          _showAmountDialog(id, name);
        },
      )
    );
  }
  
  // SYNC (Nouveau bouton pour envoyer au cloud)
  void _startSync() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Synchronisation en cours...")));
    final api = ApiService();
    final res = await api.syncTransactions();
    if(res['status'] != 'error') {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Synchronisé avec la Banque !"), backgroundColor: Colors.green));
       _fetchCloudBalance(); // Mise à jour solde
    } else {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${res['message']}"), backgroundColor: Colors.red));
    }
  }

  void _showAmountDialog(String deviceId, String deviceName) {
    TextEditingController amountCtrl = TextEditingController();
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Payer $deviceName", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: amountCtrl, 
          keyboardType: TextInputType.number, 
          autofocus: true, 
          decoration: InputDecoration(
            suffixText: "FCFA", 
            hintText: "Montant",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
          )
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              onPressed: () {
                  double? amount = double.tryParse(amountCtrl.text);
                  if (amount != null && amount > 0) {
                    Navigator.pop(ctx);
                    _doPayment(deviceId, deviceName, amount);
                  }
              },
              child: const Text("CONFIRMER LE PAIEMENT"),
            ),
          )
        ],
      )
    );
  }

  Future<void> _doPayment(String id, String name, double amount) async {
    // Petit loader
    showDialog(barrierDismissible: false, context: context, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.orange)));
    try {
      await RemaPay.payTarget(id, name, amount);
      if (mounted) Navigator.pop(context); 
      _loadData(); 
      _showSuccessPopup(amount, "Envoyé avec succès !");
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text("Erreur: $e")));
    }
  }

  void _showSuccessPopup(dynamic amount, String title) {
    showDialog(context: context, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF00CC66), size: 60),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text("${amount} FCFA", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer")),
            )
          ],
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Bonjour,", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)),
            Text(_myPhone, style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        actions: [
          // Bouton Sync (Nuage)
          IconButton(
            icon: const Icon(Icons.cloud_upload, color: Colors.blue),
            onPressed: _startSync,
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.logout, color: Colors.red, size: 20)
            ), 
            onPressed: () async {
               final p = await SharedPreferences.getInstance(); p.clear();
               await RemaPay.stopAll();
               Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
            }
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // --- CARTE ORANGE DÉGRADÉE ---
            Container(
              height: 200,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8C42), Color(0xFFFF5F2E)], 
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF5F2E).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("REMA WALLET", style: GoogleFonts.ptMono(color: Colors.white70, letterSpacing: 1.5)),
                      // Affichage du Solde Cloud en petit
                      Row(
                         children: [
                           const Icon(Icons.cloud, color: Colors.white54, size: 14),
                           const SizedBox(width: 5),
                           Text("${_onlineBalance.toStringAsFixed(0)} F", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                         ],
                      )
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Solde Poche (Offline)", style: GoogleFonts.poppins(color: Colors.white70)),
                      const SizedBox(height: 5),
                      Text("${_balance.toStringAsFixed(0)} FCFA", style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("**** 8842", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
                      InkWell(
                        onTap: () { 
                          // Simule une recharge offline depuis le cloud
                          final api = ApiService();
                          api.rechargeOfflineVault(5000).then((v) { _loadData(); });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                          child: const Text("+ Recharge", style: TextStyle(color: Colors.white)),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // --- BOUTONS D'ACTION ---
            Row(
              children: [
                // RECEVOIR
                Expanded(
                  child: InkWell(
                    onTap: _toggleReceive,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isReceiving ? const Color(0xFF4CD964) : Colors.white, 
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _isReceiving 
                          ? [BoxShadow(color: const Color(0xFF4CD964).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))]
                          : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.podcasts, color: _isReceiving ? Colors.white : const Color(0xFF4CD964), size: 28),
                          const SizedBox(height: 5),
                          Text(_isReceiving ? "En attente..." : "Recevoir", style: GoogleFonts.poppins(color: _isReceiving ? Colors.white : Colors.black, fontWeight: FontWeight.bold))
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // PAYER
                Expanded(
                  child: InkWell(
                    onTap: _startScan,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black, 
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))]
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, color: Colors.white, size: 28),
                          const SizedBox(height: 5),
                          Text("Payer", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            Text("Transactions Récentes", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 15),

            // --- HISTORIQUE ---
            _history.isEmpty 
             ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Aucune transaction")))
             : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                itemBuilder: (ctx, i) {
                  final tx = _history[i];
                  bool isReceived = tx['type'] == "IN";
                  // Date Parsing
                  String dateStr = tx['date'] ?? "";
                  if(dateStr.length > 16) dateStr = dateStr.substring(11, 16);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.all(10),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isReceived ? const Color(0xFFE8F5E9) : Colors.grey.shade100, 
                            shape: BoxShape.circle
                          ),
                          child: Icon(
                            isReceived ? Icons.south_west : Icons.north_east, 
                            color: isReceived ? const Color(0xFF4CD964) : Colors.black, 
                            size: 20
                          ),
                        ),
                        title: Text(tx['partner'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(dateStr, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                        trailing: Text(
                          "${isReceived ? '+' : '-'} ${tx['amount'].toInt()}", 
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, 
                            fontSize: 18, 
                            color: Colors.black 
                          )
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(15),
                            margin: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                            decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(15)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.verified_user, size: 16, color: Colors.blue),
                                    const SizedBox(width: 5),
                                    Text("PREUVE SÉCURISÉE", style: GoogleFonts.poppins(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  tx['signature'] ?? "Erreur de signature", 
                                  style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
             ),
          ],
        ),
      ),
    );
  }
}

// --- SCANNER RADAR ---
class _RadarDialog extends StatefulWidget {
  final Function(String, String) onSelected;
  const _RadarDialog({required this.onSelected});
  @override
  State<_RadarDialog> createState() => _RadarDialogState();
}

class _RadarDialogState extends State<_RadarDialog> {
  final Map<String, String> _devices = {};
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    // Scan
    RemaPay.scanForMerchants(onFound: (id, name) { 
      if(mounted) setState(() => _devices[id] = name); 
    });

    // Nettoyage
    _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (t) {
       if (mounted) setState(() => _devices.clear());
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      child: Container(
        height: 400,
        padding: const EdgeInsets.all(25),
        child: Column(children: [
            const CircularProgressIndicator(color: Colors.black),
            const SizedBox(height: 15),
            Text("Recherche REMA...", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(child: _devices.isEmpty 
              ? Center(child: Text("Approchez un téléphone...", style: GoogleFonts.poppins(color: Colors.grey)))
              : ListView.builder(itemCount: _devices.length, itemBuilder: (ctx, i) {
                    String id = _devices.keys.elementAt(i);
                    String name = _devices.values.elementAt(i);
                    return ListTile(
                      leading: const Icon(Icons.phone_iphone, color: Colors.black), 
                      title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), 
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => widget.onSelected(id, name)
                    );
            })),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER", style: TextStyle(color: Colors.red)))
        ]),
      ),
    );
  }
}