import 'dart:io'; // Pour Platform.isAndroid
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'; // <--- AJOUT CRUCIAL

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // On force l'app en mode Portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const RemaApp());
}

class RemaApp extends StatelessWidget {
  const RemaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REMA PAY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        useMaterial3: true,
      ),
      home: const CheckAuth(), 
    );
  }
}

class CheckAuth extends StatefulWidget {
  const CheckAuth({super.key});

  @override
  State<CheckAuth> createState() => _CheckAuthState();
}

class _CheckAuthState extends State<CheckAuth> {
  bool _isChecking = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  // C'est ici que tout se joue au démarrage
  void _initApp() async {
    // 1. DEMANDE DES PERMISSIONS (IMMÉDIATEMENT)
    // On le fait avant même de savoir si le gars est connecté.
    if (Platform.isAndroid) {
      // On demande tout le paquet d'un coup
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location, // Vital pour que Samsung voit les autres
      ].request();
      
      // Petit log pour toi développeur (visible dans la console)
      print("🔐 Permissions Démarrage : $statuses");
    }

    // 2. Vérification Login
    final prefs = await SharedPreferences.getInstance();
    String? phone = prefs.getString('user_phone');
    
    if (mounted) {
      setState(() {
        _isLoggedIn = (phone != null && phone.isNotEmpty);
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 20),
              Text("Initialisation du Système...", style: TextStyle(color: Colors.grey))
            ],
          ),
        ),
      );
    }
    return _isLoggedIn ? const HomeScreen() : const AuthScreen();
  }
}