import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bsoft_app_dist/data/database_helper.dart';
import 'package:bsoft_app_dist/main.dart';
import 'package:bsoft_app_dist/features/home/sold_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key); // ▶ OPTIMIZED: const

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _username = '', _password = '';

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(30);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A69BD), Color(0xFFCCFFE5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person, size: 100, color: Color(0xFF19264C)),
                const SizedBox(height: 20),
                const Text(
                  'Bienvenue',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF19264C),
                    fontFamily: 'Bahnschrift',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Connectez-vous pour continuer',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF19264C),
                    fontFamily: 'ZTGatha',
                  ),
                ),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Nom d\'utilisateur ou email',
                          labelStyle: const TextStyle(fontFamily: 'ZTGatha'),
                          prefixIcon: const Icon(Icons.person),
                          fillColor: Colors.white.withOpacity(0.8),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: borderRadius,
                            borderSide:
                                const BorderSide(color: Color(0xFF19264C)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: borderRadius,
                            borderSide:
                                const BorderSide(color: Color(0xFFD9F4E9)),
                          ),
                        ),
                        validator: _notEmptyValidator,
                        onSaved: (v) => _username = v!.trim(),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          labelStyle: const TextStyle(fontFamily: 'ZTGatha'),
                          prefixIcon: const Icon(Icons.lock),
                          fillColor: Colors.white.withOpacity(0.8),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: borderRadius,
                            borderSide:
                                const BorderSide(color: Color(0xFF19264C)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: borderRadius,
                            borderSide:
                                const BorderSide(color: Color(0xFFD9F4E9)),
                          ),
                        ),
                        obscureText: true,
                        validator: _notEmptyValidator,
                        onSaved: (v) => _password = v!.trim(),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed:
                            _handleLogin, // ▶ OPTIMIZED: extracted method
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF141E46),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          textStyle: const TextStyle(
                              fontSize: 18, fontFamily: 'ZTGatha'),
                          shape: RoundedRectangleBorder(
                              borderRadius: borderRadius),
                        ),
                        child: const Text('Connexion'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _notEmptyValidator(String? v) =>
      (v == null || v.isEmpty) ? 'Ce champ est requis' : null;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = await DatabaseHelper().authenticateUser(_username, _password);
      
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      if (user != null) {
        // Save login state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('loggedIn', true);
        await prefs.setString('userId', user['nom']); // Storing username as userId for compatibility
        await prefs.setInt('db_id_user', user['id_user']); // Store actual DB ID
        
        // Set global vanId (using username for now as per original logic, or switch to ID)
        vanId = user['nom']; 
        
        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const SoldScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid credentials'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
      print("Login Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
