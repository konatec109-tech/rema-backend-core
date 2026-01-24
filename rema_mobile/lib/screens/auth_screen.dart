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
  
  // ⚠️ Vérifie que c'est la bonne URL (Render ou locale)
  static const String BASE_URL = "https://rema-backend-core.onrender.com"; 
  
  final Color kPrimaryColor = const Color(0xFFFF6600);
  final Color kBgColor = const Color(0xFFF4F6F9);

  Future<void> _registerAndLogin() async {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.length < 4 || _pinCtrl.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Remplissez tous les champs"), backgroundColor: Colors.red)
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // 1. GÉNÉRATION CLÉ HARDWARE (Locale)
      setState(() => _loadingText = "Génération Identité Crypto...");
      await Future.delayed(const Duration(milliseconds: 500));
      
      // On récupère la clé publique générée par le SecurityManager
      String myPublicKey = await SecurityManager().getPublicKey();
      
      // 2. ENVOI AU SERVEUR (Inscription réelle)
      setState(() => _loadingText = "Enregistrement Blockchain...");
      
      final dio = Dio(BaseOptions(baseUrl: BASE_URL, connectTimeout: const Duration(seconds: 10)));
      
      // --- CORRECTION ICI ---
      // On génère un ID unique temporaire pour satisfaire le serveur
      String uniqueDeviceId = "android_${DateTime.now().millisecondsSinceEpoch}";

      try {
        await dio.post("/auth/signup", data: {
          // CORRECTION 1 : "phone" devient "phone_number" pour correspondre au serveur
          "phone_number": _phoneCtrl.text,
          
          // CORRECTION 2 : Ajout du champ obligatoire "device_hardware_id"
          "device_hardware_id": uniqueDeviceId,
          
          "pin_hash": _pinCtrl.text,
          "full_name": _nameCtrl.text,
          "public_key": myPublicKey,
          "role": "user"
        });
      } on DioException catch (e) {
        // Si erreur 400, c'est peut-être que l'user existe déjà.
        if (e.response?.statusCode == 400) {
           print("Utilisateur existe déjà, tentative de suite...");
        } else {
           rethrow; // Relance l'erreur pour le catch global
        }
      }

      // 3. SAUVEGARDE LOCALE
      setState(() => _loadingText = "Finalisation...");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _nameCtrl.text);
      await prefs.setString('user_phone', _phoneCtrl.text);
      // On sauvegarde aussi l'ID hardware généré
      await prefs.setString('device_id', uniqueDeviceId);
      
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }

    } catch (e) {
      setState(() => _isLoading = false);
      String msg = "Erreur Connexion";
      if (e is DioException) {
         // Affiche le message d'erreur exact du serveur pour débugger
         if (e.response != null) {
           msg = "Refus Serveur (${e.response?.statusCode}): ${e.response?.data}";
         } else {
           msg = "Erreur Serveur: ${e.message}";
         }
      }
      print("ERREUR COMPLÈTE: $e"); // Log console pour voir les détails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 5))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: kBgColor,
      body: Stack(
        children: [
          Positioned(top: -100, right: -100, child: CircleAvatar(radius: 150, backgroundColor: kPrimaryColor.withOpacity(0.05))),
          Positioned(bottom: -50, left: -50, child: CircleAvatar(radius: 100, backgroundColor: kPrimaryColor.withOpacity(0.05))),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
                        child: Icon(Icons.nfc, size: 40, color: kPrimaryColor),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(child: Text("REMA PAY", style: GoogleFonts.spaceMono(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.black87))),
                    Center(child: Text("Initialisation Système", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey))),
                    
                    const SizedBox(height: 40),
                    
                    _buildLabel("Nom de l'utilisateur"),
                    _buildInput(_nameCtrl, Icons.person_outline, "Votre Nom", false, TextInputType.name),
                    
                    const SizedBox(height: 20),
                    
                    _buildLabel("Identifiant Réseau (Tél)"),
                    _buildInput(_phoneCtrl, Icons.phone_iphone, "07 XX XX XX XX", false, TextInputType.phone),
                    
                    const SizedBox(height: 20),
                    
                    _buildLabel("Clé PIN Locale"),
                    _buildInput(_pinCtrl, Icons.lock_outline, "****", true, TextInputType.number),
                    
                    const SizedBox(height: 40),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, 
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shadowColor: Colors.black.withOpacity(0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _isLoading ? null : _registerAndLogin,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isLoading) 
                              Container(
                                width: 20, height: 20, 
                                margin: const EdgeInsets.only(right: 15),
                                child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              ),
                            Text(
                              _isLoading ? _loadingText : "INITIALISER L'ACCÈS", 
                              style: GoogleFonts.sourceCodePro(
                                fontSize: _isLoading ? 12 : 16, 
                                fontWeight: FontWeight.bold, 
                                letterSpacing: 1
                              )
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
    );
  }

  Widget _buildInput(TextEditingController controller, IconData icon, String hint, bool isPassword, TextInputType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: type,
        inputFormatters: isPassword ? [LengthLimitingTextInputFormatter(4), FilteringTextInputFormatter.digitsOnly] : [],
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: GoogleFonts.poppins(color: Colors.grey[300], fontSize: 14), icon: Icon(icon, color: kPrimaryColor, size: 22)),
      ),
    );
  }
}