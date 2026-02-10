import 'package:flutter/material.dart';
import 'package:bsoft_app_dist/data/database_helper.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _routeController = TextEditingController();
  final DatabaseHelper _db = DatabaseHelper();
  bool _saving = false;

  Future<void> _handleAddUser() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    final route = _routeController.text.trim();

    if (name.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nom et mot de passe sont requis.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _db.addLocalUser(name: name, password: password, route: route);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilisateur enregistré localement.')),
      );
      _nameController.clear();
      _passwordController.clear();
      _routeController.clear();
  } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la création: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
        children: [
          TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom utilisateur'),
          ),
            const SizedBox(height: 12),
          TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            obscureText: true,
          ),
            const SizedBox(height: 12),
          TextField(
              controller: _routeController,
              decoration: const InputDecoration(
                  labelText: 'Routes (séparées par des virgules)'),
          ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _handleAddUser,
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Ajouter'),
              ),
          ),
        ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _routeController.dispose();
    super.dispose();
  }
}
