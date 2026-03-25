import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Add this import
import 'package:flutter_application_1/firebase_options.dart';
import 'views/auth/login.dart';

void main() async {
  // 1. Standard Flutter setup
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Initialize Google Sign-In (Fix for version 7.x errors)
  // This must be called before you try to use any Google Sign-In features
  try {
    await GoogleSignIn.instance.initialize();
  } catch (e) {
    debugPrint("Google Sign-In initialization error: $e");
  }

  runApp(const EasyFixApp());
}

class EasyFixApp extends StatelessWidget {
  const EasyFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyFix Kenya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Using ColorScheme for Material 3 compatibility
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}