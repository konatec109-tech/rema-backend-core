import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

// ✅ IMPORT LOCAL
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  final LocalAuthentication auth = LocalAuthentication();
  
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();

  Future<void> _login() async {
    setState(() => _isLoading = true);
    
    // Simulation Auth (À connecter plus tard à ton User.py via HTTP)
    // Pour l'instant, on sauvegarde juste le téléphone pour l'identité Offline
    String phone = _phoneController.text.trim();
    String pin = _pinController.text.trim();

    if (phone.isNotEmpty && pin.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone', phone);
      await prefs.setString('user_name', "Utilisateur $phone"); // Nom par défaut
      
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Remplissez tout !")));
    }
    
    if(mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ REMPLACEMENT DE L'ICÔNE PAR LE LOGO
              // const Icon(Icons.lock_outline, size: 80, color: Color(0xFFFF6600)),
              Image.asset(
                "assets/logo.png",
                height: 120, // Tu peux ajuster la taille ici
              ),
              
              const SizedBox(height: 20),
              Text("IDENTIFICATION", style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Téléphone",
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Code PIN",
                  prefixIcon: const Icon(Icons.key),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 30),
              
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6600)),
                onPressed: _isLoading ? null : _login,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("ENTRER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              )),
            ],
          ),
        ),
      ),
    );
  }
}