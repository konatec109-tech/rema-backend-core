import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import '../logic/security.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  
  bool _isLoading = false;
  String _loadingText = "CONNEXION"; 
  
  // ⚠️ URL DE PROD (RENDER)
  static const String BASE_URL = "https://rema-backend-core.onrender.com"; 
  
  final Color kPrimaryColor = const Color(0xFFFF6600);
  final Color kBgColor = const Color(0xFFF4F6F9);

  Future<void> _registerAndLogin() async {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.length < 4 || _pinCtrl.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Remplissez tous les champs correctement")),
      );
      return;
    }

    setState(() { _isLoading = true; _loadingText = "SÉCURISATION..."; });

    try {
      // 1. Initialisation Sécurité
      final sec = SecurityManager();
      String pubKey = await sec.getPublicKey();
      
      // 🔥 CRITIQUE : HASH DU PIN (SHA-256)
      // On utilise ta fonction security.dart pour ne jamais envoyer le PIN en clair
      String pinHash = await sec.hashPin(_pinCtrl.text.trim());

      Dio dio = Dio(BaseOptions(baseUrl: BASE_URL));
      
      // 2. Tentative d'inscription (Signup)
      setState(() { _loadingText = "CRÉATION COMPTE..."; });
      
      try {
        await dio.post("/auth/signup", data: {
          "phone_number": _phoneCtrl.text.trim(),
          "full_name": _nameCtrl.text.trim(),
          "pin_hash": pinHash, // On envoie le SHA-256
          "public_key": pubKey,
          "role": "user",
          "device_hardware_id": "android_id_placeholder" 
        });
      } catch (e) {
        // Si erreur 400, c'est que le compte existe déjà, on continue vers le login
        print("Info: Compte existant, passage au login.");
      }

      // 3. Connexion (Login)
      setState(() { _loadingText = "AUTHENTIFICATION..."; });
      
      final loginResp = await dio.post(
        "/auth/login",
        data: {
          "username": _phoneCtrl.text.trim(),
          "password": pinHash // Le mot de passe est le Hash du PIN
        },
        options: Options(contentType: Headers.formUrlEncodedContentType)
      );

      if (loginResp.statusCode == 200) {
        // 4. Sauvegarde Locale des identifiants
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_phone', _phoneCtrl.text.trim());
        await prefs.setString('user_name', _nameCtrl.text.trim());
        await prefs.setString('user_pin_hash', pinHash); // On garde le hash pour les reconnexions futures
        await prefs.setString('auth_token', loginResp.data['access_token']);
        
        // Initialisation du solde offline à 0 pour les nouveaux utilisateurs
        String vaultKey = 'vault_balance_v3_${_phoneCtrl.text.trim()}';
        if (prefs.getInt(vaultKey) == null) {
           await prefs.setInt(vaultKey, 0);
        }

        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }

    } catch (e) {
      String msg = "Erreur de connexion";
      if (e is DioException) {
        if (e.response?.statusCode == 403) msg = "PIN Incorrect";
        else if (e.response?.statusCode == 404) msg = "Compte introuvable";
        else msg = "Erreur réseau: ${e.message}";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: kBgColor,
        body: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // --- LOGO / TITRE ---
                        Center(
                          child: Text("REMA PAY", 
                            style: GoogleFonts.ptMono(fontSize: 32, fontWeight: FontWeight.bold, color: kPrimaryColor)
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text("Banque Mobile Offline", 
                            style: GoogleFonts.poppins(color: Colors.grey)
                          ),
                        ),
                        const SizedBox(height: 50),

                        // --- CHAMPS DE SAISIE ---
                        _buildLabel("Nom complet"),
                        _buildInput(_nameCtrl, Icons.person, "Ex: Moussa Diop", false, TextInputType.name),
                        const SizedBox(height: 20),

                        _buildLabel("Numéro de téléphone"),
                        _buildInput(_phoneCtrl, Icons.phone, "Ex: 07080910", false, TextInputType.phone),
                        const SizedBox(height: 20),

                        _buildLabel("Code PIN Secret (4 chiffres)"),
                        _buildInput(_pinCtrl, Icons.lock, "****", true, TextInputType.number),
                        const SizedBox(height: 40),

                        // --- BOUTON D'ACTION ---
                        SizedBox(
                          width: double.infinity,
                          child: _isLoading 
                          ? Column(children: [const CircularProgressIndicator(color: Colors.orange), const SizedBox(height: 10), Text(_loadingText)])
                          : ElevatedButton(
                              onPressed: _registerAndLogin,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  elevation: 5,
                                  shadowColor: kPrimaryColor.withOpacity(0.4)
                              ),
                              child: Text("COMMENCER", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        )
                    ]
                )
            )
        )
    );
  }

  // --- WIDGETS DE STYLE ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
    );
  }

  Widget _buildInput(TextEditingController controller, IconData icon, String hint, bool isPassword, TextInputType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: type,
        inputFormatters: isPassword ? [LengthLimitingTextInputFormatter(4), FilteringTextInputFormatter.digitsOnly] : [],
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          border: InputBorder.none, 
          hintText: hint, 
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400), 
          icon: Icon(icon, color: Colors.grey)
        ),
      ),
    );
  }
}