import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'activation_screen.dart';
import 'sold_screen.dart';

// ▶ OPTIMIZED: Declare globals without initializing at top‐level.
String? vanId;
bool isCloture = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check for stored user ID
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? storedUserId = prefs.getString('userId');
  if (storedUserId != null) {
    vanId = storedUserId;
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
/// appropriate screen: [LoginScreen] if the user is not signed in, or [HomeButtons] if they are.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkLoginStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return const SoldScreen();
        } else {
          return const ActivationScreen();
        }
      },
    );
  }

  Future<bool> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Check if activated instead of just logged in
    return prefs.getBool('is_activated') ?? false;
  }
}
