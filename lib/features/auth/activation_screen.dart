import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bsoft_app_dist/core/constants/activation_keys.dart';
import 'package:bsoft_app_dist/data/database_helper.dart';
import 'package:bsoft_app_dist/features/home/sold_screen.dart';
import 'package:bsoft_app_dist/main.dart'; 


class ActivationScreen extends StatefulWidget {
  const ActivationScreen({Key? key}) : super(key: key);

  @override
  _ActivationScreenState createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  String _activationKey = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
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
                const Icon(Icons.vpn_key, size: 100, color: Color(0xFF19264C)),
                const SizedBox(height: 20),
                const Text(
                  'Activation',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF19264C),
                    fontFamily: 'Bahnschrift',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Entrez votre clé d\'activation',
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
                          labelText: 'Clé d\'activation',
                          labelStyle: const TextStyle(fontFamily: 'ZTGatha'),
                          prefixIcon: const Icon(Icons.lock_open),
                          fillColor: Colors.white.withOpacity(0.8),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide:
                                const BorderSide(color: Color(0xFF19264C)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide:
                                const BorderSide(color: Color(0xFFD9F4E9)),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ce champ est requis'
                            : null,
                        onSaved: (v) => _activationKey = v!.trim(),
                      ),
                      const SizedBox(height: 30),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _handleActivation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF141E46),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 50, vertical: 15),
                                textStyle: const TextStyle(
                                    fontSize: 18, fontFamily: 'ZTGatha'),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                              child: const Text('Activer'),
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

  Future<void> _handleActivation() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    // 1. Check if key is valid
    if (ActivationKeys.isValid(_activationKey)) {
      // 2. Check if key is already used locally (simple check)
      final prefs = await SharedPreferences.getInstance();
      List<String> usedKeys = prefs.getStringList('used_keys') ?? [];
      
      if (usedKeys.contains(_activationKey)) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cette clé a déjà été utilisée sur cet appareil.'), backgroundColor: Colors.red),
        );
        return;
      }

      // 3. Mark key as used
      usedKeys.add(_activationKey);
      await prefs.setStringList('used_keys', usedKeys);
      await prefs.setBool('is_activated', true);

      // 4. Auto-login as admin
      // Ensure admin user exists (it should from DB creation, but let's be safe)
      // We'll just set the session vars directly as if we logged in as admin
      await prefs.setBool('loggedIn', true);
      await prefs.setString('userId', 'admin'); 
      await prefs.setInt('db_id_user', 1); 
      
      // Update global var
      // ignore: prefer_const_constructors
      // vanId = 'admin'; // Need to import main.dart or handle this better. 
      // For now, we rely on main.dart reloading or navigating to SoldScreen which might read prefs.
      
      if (!mounted) return;
      
      // Navigate to SoldScreen
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const SoldScreen()));
          
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clé invalide.'), backgroundColor: Colors.red),
      );
    }
  }
}
