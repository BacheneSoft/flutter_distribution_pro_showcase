import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class AddSoldScreen extends StatefulWidget {
  @override
  _AddSoldScreenState createState() => _AddSoldScreenState();
}

class _AddSoldScreenState extends State<AddSoldScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _items = [];
  int? _selectedClientId;
  int? _selectedItemId;
  int _selectedQuantity = 1;
  int? _currentUserId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final dbUserId = prefs.getInt('db_id_user');
    final clients = await _db.getClients();
    final items = await _db.getItems();

    if (!mounted) return;
    setState(() {
      _currentUserId = dbUserId;
      _clients = clients;
      _items = items;
      _loading = false;
    });
  }

  Future<void> _saveSale() async {
    if (_selectedClientId == null ||
        _selectedItemId == null ||
        _selectedQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs.')),
      );
      return;
    }

    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun utilisateur connecté.')),
      );
      return;
    }

    final item = _items.firstWhere(
      (it) => it['id_item'] == _selectedItemId,
      orElse: () => {},
    );

    if (item.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article introuvable.')),
      );
      return;
    }

    final double unitPrice =
        (item['unit_price'] as num?)?.toDouble() ?? 0.0;
    final double totalPrice = unitPrice * _selectedQuantity;

    final saleData = {
      'id_client': _selectedClientId,
      'id_user': _currentUserId,
      'total_amount': totalPrice,
      'payment_method': 'cash',
      'payment_status': 'paid',
      'discount': 0.0,
      'tax': 0.0,
      'notes': '',
    };

    final saleItems = [
      {
        'id_item': _selectedItemId,
        'quantity': _selectedQuantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
      }
    ];

    await _db.addSale(saleData, saleItems);

    // Update encaissement cache
    final prefs = await SharedPreferences.getInstance();
    final currentEncaissement =
        prefs.getDouble('total_encaissement') ?? 0.0;
    await prefs.setDouble(
        'total_encaissement', currentEncaissement + totalPrice);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vente enregistrée localement.')),
    );

    setState(() {
      _selectedClientId = null;
      _selectedItemId = null;
      _selectedQuantity = 1;
      _quantityController.text = '1';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle vente'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    value: _selectedClientId,
                    decoration:
                        const InputDecoration(labelText: 'Sélectionner client'),
                    items: _clients
                        .map(
                          (client) => DropdownMenuItem<int>(
                            value: client['id_client'] as int,
                            child: Text(client['nom'] ?? 'Client'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedClientId = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _selectedItemId,
                    decoration:
                        const InputDecoration(labelText: 'Sélectionner article'),
                    items: _items
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item['id_item'] as int,
                            child: Text(item['item_name'] ?? 'Article'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedItemId = value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityController,
                    decoration:
                        const InputDecoration(labelText: 'Quantité'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _selectedQuantity = int.tryParse(value) ?? 1;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSale,
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }
}
