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
  
  // 🔥 VARIABLES D'ÉTAT (ENTIERS POUR ÉVITER LES ERREURS DE CENTIMES)
  int _balance = 0;       // Solde Offline (Dans votre poche)
  int _onlineBalance = 0; // Solde Online (Dans la Banque)
  
  bool _isReceiving = false;    
  List<Map<String, dynamic>> _history = []; // Historique complet
  Timer? _balanceTimer;

  // Formatage des sommes : 10000 -> "10 000"
  final currencyFmt = NumberFormat("#,###", "fr_FR");

  @override
  void initState() {
    super.initState();
    
    // 1. Initialisation du moteur Bluetooth
    RemaPay.init(); 
    
    // 2. Chargement immédiat des données locales
    _loadData();
    
    // 3. Récupération du solde Banque (Immédiat + Timer 10s)
    _fetchCloudBalance(); 
    _balanceTimer = Timer.periodic(const Duration(seconds: 10), (t) => _fetchCloudBalance());
    
    // 4. Écouteurs d'événements (Pour mettre à jour l'UI en temps réel)
    
    // A. Messages de statut (Toast/Snackbars)
    RemaPay.onStatusUpdate = (msg) {
        if(mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg), 
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ));
        }
        // Si le système dit "Standby", on désactive le mode réception visuel
        if (msg.contains("Standby") && _isReceiving) {
             setState(() => _isReceiving = false);
        }
    };
    
    // B. Réception d'argent (Mise à jour automatique)
    RemaPay.onTransactionReceived = (data) {
        _loadData(); // On recharge le solde et l'historique
    };
  }

  @override
  void dispose() {
    _balanceTimer?.cancel();
    RemaPay.stopAll();
    super.dispose();
  }

  // --- CHARGEMENT DES DONNÉES LOCALES (OFFLINE) ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    int offBal = await RemaPay.getOfflineBalance();
    var hist = await RemaPay.getHistory();
    
    if (mounted) {
      setState(() {
        _myPhone = prefs.getString('user_phone') ?? "Inconnu";
        _balance = offBal;
        _history = hist;
      });
    }
  }

  // --- CHARGEMENT DES DONNÉES ONLINE (BANQUE) ---
  Future<void> _fetchCloudBalance() async {
    // Appelle l'API pour savoir combien il reste sur le compte bancaire
    int? bal = await ApiService().fetchUserBalance();
    if (bal != null && mounted) {
      setState(() => _onlineBalance = bal);
    }
  }

  // --- SYNCHRONISATION (TÉLÉPHONE <-> BANQUE) ---
  Future<void> _handleSync() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Synchronisation en cours...")));
    
    // Envoi des preuves de paiement au serveur
    var res = await ApiService().syncTransactions();
    
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      bool success = res['status'] == 'success' || res['status'] == 'empty';
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? "✅ Cloud à jour" : "⚠️ ${res['message']}"),
        backgroundColor: success ? Colors.green : Colors.orange,
      ));
      
      // Une fois sync, on met à jour le solde Online pour refléter la réalité
      if (success) _fetchCloudBalance(); 
    }
  }

  // --- DIALOGUE DE RECHARGE (BANQUE -> TÉLÉPHONE) ---
  void _showRechargeDialog() {
    final c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("Retrait Banque", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Transférer du solde Online vers votre coffre Offline.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          TextField(
            controller: c, 
            keyboardType: TextInputType.number, 
            decoration: const InputDecoration(
              labelText: "Montant (FCFA)", 
              border: OutlineInputBorder(),
              suffixText: "FCFA"
            )
          ),
          const SizedBox(height: 10),
          // Indicateur visuel du solde disponible
          Text("Dispo Online: ${currencyFmt.format(_onlineBalance)} F", style: const TextStyle(fontSize: 12, color: Colors.green))
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ANNULER")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
          onPressed: () async {
            int amount = int.tryParse(c.text) ?? 0;
            if (amount > 0) {
                // 1. Vérification locale avant appel
                if (amount > _onlineBalance) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Solde bancaire insuffisant")));
                   return;
                }
                Navigator.pop(ctx);
                
                // 2. Appel API
                // Si succès : Online baisse, Offline monte
                bool ok = await ApiService().rechargeOfflineVault(amount);
                
                if(ok) {
                    _loadData(); // Met à jour le Offline (Monte ⬆️)
                    _fetchCloudBalance(); // Met à jour le Online (Baisse ⬇️)
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Argent téléchargé dans le téléphone !")));
                } else {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Erreur connexion banque")));
                }
            }
        }, child: const Text("VALIDER"))
      ],
    ));
  }

  // --- DIALOGUE DE PAIEMENT (ENVOI D'ARGENT) ---
  void _showPaymentDialog(String id, String name) {
      final ctrl = TextEditingController();
      showDialog(context: context, builder: (ctx) => AlertDialog(
          title: Text("Payer $name", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: "Montant", suffixText: "FCFA", border: OutlineInputBorder())
          ),
          actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ANNULER")),
              ElevatedButton(
                  onPressed: () {
                      int amount = int.tryParse(ctrl.text) ?? 0;
                      if (amount > 0) {
                          Navigator.pop(ctx);
                          // 🔥 PAIEMENT OFFLINE SÉCURISÉ (VISA COMPATIBLE)
                          RemaPay.payTarget(id, name, amount, metadata: "{\"source\": \"app_v3\"}")
                                 .then((_) => _loadData()) // Le solde Offline Baisse ⬇️ immédiatement
                                 .catchError((e) {
                                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
                                 });
                      }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6600), foregroundColor: Colors.white),
                  child: const Text("PAYER")
              )
          ],
      ));
  }

  // --- DIALOGUE DE SCAN (RECHERCHE MARCHANDS) ---
  void _showScanDialog() {
      Map<String, String> devicesFound = {};
      
      showDialog(context: context, builder: (ctx) {
          // Lancement du scan Bluetooth
          RemaPay.scanForMerchants(onFound: (id, name) {
              if (ctx.mounted && !devicesFound.containsKey(id)) {
                  // Rafraîchissement dynamique de la liste
                  (ctx as Element).markNeedsBuild();
                  devicesFound[id] = name;
              }
          });

          return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                    title: const Text("Recherche REMA..."),
                    content: SizedBox(
                        height: 300,
                        width: double.maxFinite,
                        child: Column(
                            children: [
                                const LinearProgressIndicator(color: Color(0xFFFF6600)),
                                const SizedBox(height: 20),
                                Expanded(
                                    child: devicesFound.isEmpty 
                                    ? Center(child: Text("Approchez un téléphone...", style: GoogleFonts.poppins(color: Colors.grey)))
                                    : ListView.builder(
                                        itemCount: devicesFound.length,
                                        itemBuilder: (c, i) {
                                            String id = devicesFound.keys.elementAt(i);
                                            String name = devicesFound.values.elementAt(i);
                                            return ListTile(
                                                leading: const Icon(Icons.phone_iphone),
                                                title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                                onTap: () {
                                                    Navigator.pop(ctx); // On ferme le scan
                                                    _showPaymentDialog(id, name); // On ouvre le paiement
                                                },
                                            );
                                        }
                                    )
                                )
                            ]
                        )
                    ),
                    actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FERMER"))
                    ],
                );
              }
          );
      }).then((_) => RemaPay.stopAll()); // Arrêt du scan à la fermeture
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        
        // --- BARRE DU HAUT ---
        appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text("REMA PAY", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
            centerTitle: true,
            actions: [
                // Bouton Sync
                IconButton(icon: const Icon(Icons.cloud_sync, color: Colors.black), onPressed: _handleSync),
                // Bouton Déconnexion
                IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: () async {
                    final p = await SharedPreferences.getInstance();
                    await p.clear();
                    if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
                })
            ],
        ),
        
        body: Column(
            children: [
                // --- CARTE PRINCIPALE (SOLDE) ---
                Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                        color: Colors.black, 
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]
                    ),
                    child: Column(children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                             const Text("SOLDE OFFLINE", style: TextStyle(color: Colors.white54, fontSize: 12)),
                             Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                 decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                                 child: const Row(children: [Icon(Icons.flash_on, color: Colors.yellow, size: 14), SizedBox(width: 4), Text("Instantané", style: TextStyle(color: Colors.white, fontSize: 10))])
                             )
                        ]),
                        const SizedBox(height: 10),
                        
                        // 🔥 Affichage du Solde Offline (En Gros)
                        Text("${currencyFmt.format(_balance)} F", style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                        
                        const Divider(color: Colors.white24, height: 30),
                        
                        // Ligne du bas : Solde Banque + Bouton Retrait
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text("BANQUE (CLOUD)", style: TextStyle(color: Colors.white54, fontSize: 10)),
                                Text("${currencyFmt.format(_onlineBalance)} F", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
                            ]),
                            ElevatedButton.icon(
                                onPressed: _showRechargeDialog, 
                                icon: const Icon(Icons.download, size: 16), 
                                label: const Text("Retrait"),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5))
                            )
                        ])
                    ])
                ),

                // --- TITRE HISTORIQUE ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: [
                      Text("Activités récentes", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                
                // --- LISTE DE L'HISTORIQUE ---
                Expanded(
                    child: _history.isEmpty 
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.history, size: 50, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text("Aucune transaction", style: GoogleFonts.poppins(color: Colors.grey))
                      ]))
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _history.length,
                        separatorBuilder: (_,__) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                            var tx = _history[i];
                            // Détermine si c'est Entrant (IN) ou Sortant (OUT)
                            bool isOut = tx['type'] == 'OUT';
                            DateTime date = DateTime.fromMillisecondsSinceEpoch(tx['timestamp']);
                            
                            return Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                                child: Row(children: [
                                    // Icône (Flèche rouge ou verte)
                                    Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: isOut ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                                        child: Icon(isOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: isOut ? Colors.orange : Colors.green)
                                    ),
                                    const SizedBox(width: 15),
                                    // Détails (Nom + Date)
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(isOut ? "Payé à ${tx['partner']}" : "Reçu de ${tx['partner'] ?? 'Inconnu'}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                        Text(DateFormat('dd MMM à HH:mm', 'fr_FR').format(date), style: const TextStyle(color: Colors.grey, fontSize: 12))
                                    ])),
                                    // Montant (+ ou -)
                                    Text("${isOut ? '-' : '+'}${currencyFmt.format(tx['amount'])} F", 
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: isOut ? Colors.black : Colors.green)
                                    )
                                ])
                            );
                        }
                    )
                )
            ]
        ),
        
        // --- BOUTONS D'ACTION (BAS DE PAGE) ---
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                    // --- BOUTON RECEVOIR ---
                    Expanded(
                        child: FloatingActionButton.extended(
                            heroTag: "btnRec",
                            onPressed: () {
                                setState(() => _isReceiving = true);
                                RemaPay.startReceiving();
                                showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
                                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                                        const SizedBox(height: 10),
                                        const CircularProgressIndicator(color: Colors.black),
                                        const SizedBox(height: 20),
                                        Text("Mode Marchand Activé", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                        const Text("En attente d'un client...", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        const SizedBox(height: 20),
                                        TextButton(onPressed: () {
                                            RemaPay.stopAll();
                                            Navigator.pop(ctx);
                                        }, child: const Text("ARRÊTER", style: TextStyle(color: Colors.red)))
                                    ])
                                )).then((_) => setState(() => _isReceiving = false));
                            },
                            backgroundColor: Colors.black,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text("RECEVOIR")
                        )
                    ),
                    const SizedBox(width: 15),
                    
                    // --- BOUTON PAYER ---
                    Expanded(
                        child: FloatingActionButton.extended(
                            heroTag: "btnPay",
                            onPressed: _showScanDialog,
                            backgroundColor: const Color(0xFFFF6600),
                            icon: const Icon(Icons.nfc),
                            label: const Text("PAYER")
                        )
                    )
                ]
            )
        )
    );
  }
}