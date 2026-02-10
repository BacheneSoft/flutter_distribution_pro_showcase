import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bsoft_app_dist/features/auth/activation_screen.dart';
import 'package:bsoft_app_dist/features/home/sold_screen.dart';
import 'package:bsoft_app_dist/features/auth/login_screen.dart';



// ▶ OPTIMIZED: Declare globals without initializing at top‐level.
String? vanId;
bool isCloture = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check for stored user ID
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool activated = prefs.getBool('is_activated') ?? false;
  
  if (activated) {
    String? storedUserId = prefs.getString('userId');
    if (storedUserId == null) {
      // If activated but no userId, default to admin
      await prefs.setString('userId', 'admin');
      await prefs.setInt('db_id_user', 1);
      await prefs.setBool('loggedIn', true);
      vanId = 'admin';
    } else {
      vanId = storedUserId;
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // ▶ OPTIMIZED: hide debug banner
      title: 'Bachene Soft',
      theme: ThemeData(
        primaryColor: Color(0xFF141E46),
        scaffoldBackgroundColor: Color(0xFFFAFAFF),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF6D67E4),
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF6D67E4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF141E46)),
          ),
        ),
      ),
      // Use the auth wrapper as the home widget.
      home: const AuthWrapper(),
    );
  }
}

/// This widget listens to the authentication state and returns the
/// appropriate screen: [ActivationScreen] if not activated, otherwise [SoldScreen].
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkActivationStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // In Demo/Showcase mode, we can auto-activate or show a demo login.
        // For simplicity, let's allow it to start normally.
        if (snapshot.data == true) {
          return const SoldScreen();
        } else {
          // You could redirect to a demo-specific welcome screen here
          return const ActivationScreen();
        }
      },
    );
  }

  Future<bool> _checkActivationStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool activated = prefs.getBool('is_activated') ?? false;
    
    if (activated && prefs.getString('userId') == null) {
      // Ensure we have a default user if activated but userId is missing
      await prefs.setString('userId', 'admin');
      await prefs.setInt('db_id_user', 1);
      await prefs.setBool('loggedIn', true);
      vanId = 'admin';
    }
    
    return activated;
  }
}
