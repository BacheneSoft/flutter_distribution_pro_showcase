import 'package:flutter/material.dart';
import 'database_helper.dart';

class ClientDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> client;

  ClientDetailsScreen({required this.client});

  @override
  _ClientDetailsScreenState createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();
  String? _nom;
  String? _telephone;
  String? _typeClient;
  String? _commune;
  String? _cite;
  String? _latitude;
  String? _longitude;
  String? _etat;

  @override
  void initState() {
    super.initState();
    // Initialize the form fields with existing client data
    _nom = widget.client['nom'];
    _telephone = widget.client['tel'];
    _typeClient = widget.client['type_client'];
    _commune = widget.client['commune'];
    _cite = widget.client['cite'];
    _latitude = widget.client['latitude'];
    _longitude = widget.client['longitude'];
    _etat = widget.client['etat'];

    // Print to check if values are retrieved correctly
    print("Latitude: $_latitude");
    print("Longitude: $_longitude");
  }

  // Function to update the client data
  void _updateClient() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      Map<String, dynamic> updatedClient = {
        'id_client': widget.client['id_client'],
        'nom': _nom,
        'tel': _telephone,
        'type_client': _typeClient,
        'commune': _commune,
        'cite': _cite,
        'latitude': _latitude,
        'longitude': _longitude,
        'etat': _etat,
      };

      // Get the number of affected rows from the updateClient method
      int result = await dbHelper.updateClient(updatedClient);
      if (result != 0) {
        print('Client data updated to local database'); // Debugging log
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Client updated')));
        Navigator.pop(context); // Go back to the client list after saving
      } else {
        print('Failed to insert client'); // Log if insert fails
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update client')));
      }
    }
  }

  // Function to delete the client
  void _deleteClient() async {
    await dbHelper.deleteClient(widget.client['id_client']);
    Navigator.pop(context); // Go back to the client list after deleting
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Magasin Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _deleteClient,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: _nom,
                decoration: InputDecoration(labelText: 'Nom'),
                onSaved: (value) => _nom = value,
              ),
              SizedBox(height: 10),
              TextFormField(
                initialValue: _telephone,
                decoration: InputDecoration(labelText: 'Téléphone'),
                onSaved: (value) => _telephone = value,
              ),
              SizedBox(height: 10),
              TextFormField(
                initialValue: _typeClient,
                decoration: InputDecoration(labelText: 'Type Magasin'),
                onSaved: (value) => _typeClient = value,
              ),
              SizedBox(height: 10),
              TextFormField(
                initialValue: _commune,
                decoration: InputDecoration(labelText: 'Commune'),
                onSaved: (value) => _commune = value,
              ),
              SizedBox(height: 10),
              TextFormField(
                initialValue: _cite,
                decoration: InputDecoration(labelText: 'Cité'),
                onSaved: (value) => _cite = value,
              ),
              SizedBox(height: 10),
              /*
              TextFormField(
                initialValue: _latitude,
                decoration: InputDecoration(labelText: 'Latitude'),
                onSaved: (value) => _latitude = value,
              ),
              SizedBox(height: 10),
              TextFormField(
                initialValue: _longitude,
                decoration: InputDecoration(labelText: 'Longitude'),
                onSaved: (value) => _longitude = value,
              ),
              SizedBox(height: 10),
              */
              TextFormField(
                initialValue: _etat,
                decoration: InputDecoration(labelText: 'État'),
                onSaved: (value) => _etat = value,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF141E46),
                ),
                onPressed: _updateClient,
                child: Text('Update'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
