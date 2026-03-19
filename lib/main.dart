import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // ← proper import
import 'package:flutter_application_1/firebase_options.dart';
import 'views/auth/login.dart';

void main() async {  // ← no parameters
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        primarySwatch: Colors.green,
        primaryColor: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}