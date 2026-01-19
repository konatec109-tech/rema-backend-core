import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ IMPORTS LOGIC & MODELS
import '../logic/rema_pay.dart';
import '../models/transaction.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Données
  double _onlineBalance = 0.0;
  double _offlineBalance = 0.0;
  String _userName = "...";
  
  // Console
  final List<String> _logs = []; 
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupListeners();
  }

  void _setupListeners() {
    // 1. Écoute les logs du moteur
    RemaPay.onStatusUpdate = (msg) {
      if (mounted) {
        setState(() {
          _logs.add("${DateTime.now().minute}:${DateTime.now().second} > $msg");
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    };

    // 2. Écoute les paiements entrants
    RemaPay.onTransactionReceived = (tx) {
      _refreshBalances();
      _showSuccessDialog(tx.amount);
    };
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _userName = prefs.getString('user_name') ?? "Utilisateur");
    await _refreshBalances();
  }

  Future<void> _refreshBalances() async {
    double on = await RemaPay.fetchOnlineBalance();
    double off = await RemaPay.getOfflineBalance();
    if (mounted) setState(() { _onlineBalance = on; _offlineBalance = off; });
  }

  // --- ACTIONS ---

  void _actionDownloadFunds() {
    TextEditingController amountCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Télécharger Fonds"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Transférer du Cloud vers le Coffre Local (Offline)", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: "Montant", suffixText: "FCFA", border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
          onPressed: () async {
            Navigator.pop(ctx);
            double? amount = double.tryParse(amountCtrl.text);
            if (amount != null && amount > 0) {
              // 🔥 APPEL À LA FONCTION ANTI-DOUBLE SPENDING
              bool success = await RemaPay.downloadFunds(amount);
              if (success) _refreshBalances();
            }
          },
          child: const Text("TÉLÉCHARGER", style: TextStyle(color: Colors.white)),
        )
      ],
    ));
  }

  void _actionScan() {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const _ScanDialog());
  }

  void _actionReceive() {
    RemaPay.startReceiving();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mode Marchand Activé"), backgroundColor: Colors.green));
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_phone');
    if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void _showSuccessDialog(double amount) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.green,
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 60),
        Text("+ ${amount.toStringAsFixed(0)} F", style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text("REMA PAY", style: GoogleFonts.orbitron(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.black), onPressed: _logout)
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // CARTES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _buildCard("COFFRE (Offline)", _offlineBalance, Colors.black, true)),
                const SizedBox(width: 10),
                Expanded(child: _buildCard("CLOUD (Online)", _onlineBalance, Colors.grey, false)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // BOUTONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _buildBtn("PAYER", Icons.arrow_upward, const Color(0xFFFF6600), _actionScan)),
                const SizedBox(width: 15),
                Expanded(child: _buildBtn("RECEVOIR", Icons.arrow_downward, Colors.green, _actionReceive)),
              ],
            ),
          ),
          // CONSOLE
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _logs.length,
                itemBuilder: (ctx, i) => Text(_logs[i], style: GoogleFonts.firaCode(color: Colors.greenAccent, fontSize: 11)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, double amount, Color color, bool isOffline) {
    return Container(
      padding: const EdgeInsets.all(15), height: 120,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${amount.toStringAsFixed(0)} F", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              if(isOffline) InkWell(
                onTap: _actionDownloadFunds,
                child: const Icon(Icons.download, color: Colors.white),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBtn(String label, IconData icon, Color color, VoidCallback tap) {
    return InkWell(
      onTap: tap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }
}

// SCANNER POPUP
class _ScanDialog extends StatefulWidget {
  const _ScanDialog();
  @override
  State<_ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<_ScanDialog> {
  final Map<String, String> _devices = {}; 
  
  @override
  void initState() {
    super.initState();
    RemaPay.scanForMerchants(
      onFound: (id, name) => setState(() => _devices[id] = name),
      onLost: (id) => setState(() => _devices.remove(id)),
    );
  }

  void _pay(String id, String name) {
    TextEditingController c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("Payer $name"),
      content: TextField(controller: c, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(suffixText: "F")),
      actions: [
        ElevatedButton(onPressed: () {
          double? val = double.tryParse(c.text);
          if (val != null) {
            Navigator.pop(ctx); Navigator.pop(context);
            RemaPay.payTarget(id, val);
          }
        }, child: const Text("ENVOYER"))
      ],
    ));
  }

  @override
  void dispose() {
    RemaPay.stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Recherche Marchands..."),
      content: SizedBox(width: double.maxFinite, height: 300, child: ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (ctx, i) {
          String id = _devices.keys.elementAt(i);
          return ListTile(
            leading: const Icon(Icons.phone_android),
            title: Text(_devices.values.elementAt(i)),
            trailing: ElevatedButton(onPressed: () => _pay(id, _devices.values.elementAt(i)), child: const Text("PAYER")),
          );
        },
      )),
    );
  }
}