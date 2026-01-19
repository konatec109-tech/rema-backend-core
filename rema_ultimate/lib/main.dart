import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ IMPORT ARCHITECTURE ULTIMATE
import 'logic/rema_pay.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

const Color kPrimary = Color(0xFFFF6600);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Barre de statut transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Démarrage du Moteur
  try {
    await RemaPay.init();
    print("✅ MOTEUR REMA DÉMARRÉ");
  } catch (e) {
    print("❌ ERREUR MOTEUR: $e");
  }

  runApp(const RemaApp());
}

class RemaApp extends StatefulWidget {
  const RemaApp({super.key});

  @override
  State<RemaApp> createState() => _RemaAppState();
}

class _RemaAppState extends State<RemaApp> {
  bool _isReady = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Permissions Critiques (Android 12+)
    await [
      Permission.location, // Vital pour Bluetooth LE
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ].request();

    // 2. Vérification Session
    final prefs = await SharedPreferences.getInstance();
    String? phone = prefs.getString('user_phone');

    if (mounted) {
      setState(() {
        _isLoggedIn = (phone != null && phone.isNotEmpty);
        _isReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator(color: kPrimary))),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'REMA ULTIMATE',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: kPrimary,
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
      ),
      // Si connecté -> Home, Sinon -> Auth
      home: _isLoggedIn ? const HomeScreen() : const AuthScreen(),
    );
  }
}