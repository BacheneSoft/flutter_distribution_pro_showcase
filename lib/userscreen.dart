import 'database_helper.dart';
import 'allowed_users.dart';
import 'main.dart';
import 'userscreen_sells.dart';
//import 'package:bsoft_app/testing.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

List<Map<dynamic, dynamic>> clientsList = [];
List<Map<dynamic, dynamic>> filteredClientsList = [];

// Reusable style constants
const _labelStyle = TextStyle(
  fontFamily: 'ZTGatha',
  color: Color(0xFF19264C),
);

final _border = OutlineInputBorder(
  borderSide: BorderSide(color: Color(0xFF19264C)),
  borderRadius: BorderRadius.circular(4.0),
);

final _focusedBorder = OutlineInputBorder(
  borderSide: BorderSide(color: Color(0xFFB0ACFD)),
  borderRadius: BorderRadius.circular(4.0),
);

class UserScreen extends StatefulWidget {
  const UserScreen({Key? key}) : super(key: key);

  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  // StreamSubscription<DatabaseEvent>? _clientsSubscription;
  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;
  final List<TextEditingController> _controllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  final _searchController = TextEditingController();
  bool isDetectingLocation = false;
  bool locationDetected = true;
  bool isSearching = false;
  bool isOffline = false;
  final _formKey = GlobalKey<FormState>();

  // Controller getters for cleaner access
  TextEditingController get _clientNameController => _controllers[0];
  TextEditingController get _clientCodeController => _controllers[1];
  TextEditingController get _clientAddressController => _controllers[2];
  TextEditingController get _clientTypeController => _controllers[3];
  TextEditingController get _clientPhoneController => _controllers[4];
  TextEditingController get _clientBalanceController => _controllers[5];
  TextEditingController get _clientEmailController => _controllers[6];
  TextEditingController get _latitudeController => _controllers[7];
  TextEditingController get _longitudeController => _controllers[8];

  Future<void> fetchClients() async {
    // _clientsSubscription?.cancel();
    // if (vanId == null) return; // REMOVED: legacy check not needed for local DB

    final db = DatabaseHelper();
    // Assuming we filter clients by route or some other criteria if needed.
    // For now, let's fetch all clients or filter by what's relevant to the user.
    // The original code fetched 'vans/$vanId/clients'.
    // In local DB, we might need to filter by route associated with the user?
    // Or just fetch all clients if the DB is local to the device.

    List<Map<String, dynamic>> clients = await db.getClients();

    // We might need to map the keys to match what the UI expects (uppercase keys)
    List<Map<String, dynamic>> mappedClients = clients.map((c) {
      return {
        'IDCLIENT': c['id_client'].toString(),
        'NOMCLIENT': c['nom'],
        'CODECLTV': c['code'] ??
            c['id_client']?.toString() ??
            '', // Use code field if exists
        'ADRESSE': c['commune'], // Mapping commune to address for now
        'TYPE_CLIENT': c['type_client'],
        'TEL': c['tel'],
        'SOLDEINI': c['solde'],
        'CA': c['ca'],
        'VERS': c['vers'],
        'LATITUDE': c['latitude'],
        'LONGITUDE': c['longitude'],
        'EMAIL': c['email'] ?? '', // Use email field from DB
        ...c
      };
    }).toList();

    setState(() {
      clientsList = mappedClients;
      filteredClientsList = mappedClients;
    });
  }

  void _addClient() async {
    // 1) validate form
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackBar('Please fill all the required fields.');
      return;
    }
    // 2) guard against missing vanId -> REMOVED because we are local
    // if (vanId == null) return;

    // 4) prepare the payload
    // We need to map UI fields to DB columns
    final clientData = {
      'nom': _clientNameController.text,
      'telephone': _clientPhoneController.text,
      'type_client': _clientTypeController.text,
      'commune':
          _clientAddressController.text, // Using address as commune for now
      'cite': '',
      'Latitude': _latitudeController.text,
      'Longitude': _longitudeController.text,
      'id_route': 1, // Default or selected route
      'code': _clientCodeController.text,
      'email': _clientEmailController.text,
      'solde': double.parse((double.tryParse(_clientBalanceController.text) ?? 0.0).toStringAsFixed(2)),
    };

    final db = DatabaseHelper();
    await db.insertClient(clientData);

    // Update financials if needed (since insertClient doesn't take solde yet, or we updated schema?)
    // We updated schema to include solde, ca, vers.
    // But insertClient method in DatabaseHelper might need update to accept these.
    // Let's check insertClient implementation. It takes a map and inserts specific fields.
    // I should probably update insertClient to accept more fields or just use raw insert here?
    // Or better, update insertClient in DatabaseHelper later.
    // For now, let's assume basic insertion works and we can update financials separately if needed,
    // or just rely on defaults.

    _showSnackBar('Client Added Successfully (Local)');
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
    fetchClients();
  }

  // Removed _prepareClientData and _handleClientOperation from the legacy cloud implementation

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _importClientsFromCSV() async {
    try {
      // Pick CSV file from device
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        return; // User canceled the picker
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);
      
      // Read and parse CSV
      final csvString = await file.readAsString();
      final List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);
      
      if (csvData.isEmpty || csvData.length < 2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier CSV vide ou invalide')),
        );
        return;
      }
      
      // Expected CSV format: Code,Nom,Adresse,Telephone,Type,Email,Solde
      int importedCount = 0;
      int skippedCount = 0;
      
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        
        // Validate row has minimum required columns
        if (row.length < 5) {
          skippedCount++;
          continue;
        }
        
        try {
          final code = row[0]?.toString().trim() ?? '';
          final nom = row[1]?.toString().trim() ?? '';
          final adresse = row[2]?.toString().trim() ?? '';
          final telephone = row[3]?.toString().trim() ?? '';
          final type = row[4]?.toString().trim() ?? 'Detail';
          final email = row.length > 5 ? (row[5]?.toString().trim() ?? '') : '';
          final soldeRaw = row.length > 6 ? (double.tryParse(row[6]?.toString() ?? '0') ?? 0.0) : 0.0;
          final solde = double.parse(soldeRaw.toStringAsFixed(2));
          
          // Validate required fields
          if (nom.isEmpty || code.isEmpty || telephone.isEmpty) {
            skippedCount++;
            continue;
          }
          
          // Check if client already exists by code
          final db = DatabaseHelper();
          final existingClients = await db.getClients();
          final exists = existingClients.any((c) => c['CODECLTV']?.toString() == code);
          
          if (exists) {
            skippedCount++;
            continue; // Skip duplicate
          }
          
          // Insert client
          await db.insertClient({
            'nom': nom,
            'code': code,
            'commune': adresse,
            'tel': telephone,
            'type_client': type,
            'email': email,
            'latitude': '',
            'longitude': '',
            'solde': solde,
          });
          
          importedCount++;
        } catch (e) {
          skippedCount++;
          print('Error importing row $i: $e');
        }
      }
      
      // Reload clients
      await fetchClients();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Importation terminée: $importedCount ajouté(s), $skippedCount ignoré(s)'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'import: $e')),
      );
    }
  }

  // update the clients
  void _showEditClientDialog(Map<dynamic, dynamic> client) {
    // Pre‑fill controllers via getters
    _clientNameController.text = client['NOMCLIENT'] ?? '';
    _clientCodeController.text = client['CODECLTV']?.toString() ?? '';
    _clientAddressController.text = client['ADRESSE'] ?? '';
    _clientTypeController.text = client['TYPE_CLIENT'] ?? '';
    _clientPhoneController.text = client['TEL'] ?? '';
    _clientBalanceController.text = client['SOLDEINI']?.toString() ?? '';
    _clientEmailController.text = client['EMAIL'] ?? '';
    _latitudeController.text = client['LATITUDE'] ?? '';
    _longitudeController.text = client['LONGITUDE'] ?? '';

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFFFAFAFF),
              title: const Text(
                'Modifier Client',
                style: TextStyle(
                  color: Color(0xFF19264C),
                  fontFamily: 'Bahnschrift',
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // Nom
                    TextField(
                      controller: _clientNameController,
                      decoration: InputDecoration(
                        labelText: 'Nom',
                        labelStyle: _labelStyle,
                        enabledBorder: _border,
                        focusedBorder: _focusedBorder,
                      ),
                      style: _labelStyle,
                    ),
                    const SizedBox(height: 20),
                    // Adresse
                    TextField(
                      controller: _clientAddressController,
                      decoration: InputDecoration(
                        labelText: 'Adresse',
                        labelStyle: _labelStyle,
                        enabledBorder: _border,
                        focusedBorder: _focusedBorder,
                      ),
                      style: _labelStyle,
                    ),
                    const SizedBox(height: 20),
                    // Téléphone
                    TextField(
                      controller: _clientPhoneController,
                      decoration: InputDecoration(
                        labelText: 'Téléphone',
                        labelStyle: _labelStyle,
                        enabledBorder: _border,
                        focusedBorder: _focusedBorder,
                      ),
                      keyboardType: TextInputType.number,
                      style: _labelStyle,
                    ),
                    const SizedBox(height: 20),
                    // Type
                    DropdownButtonFormField<String>(
                      value: _clientTypeController.text.isNotEmpty
                          ? _clientTypeController.text
                          : null,
                      items: ['Detail', 'Gros'].map((type) {
                        return DropdownMenuItem(
                            value: type, child: Text(type, style: _labelStyle));
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _clientTypeController.text = val!),
                      dropdownColor: const Color(0xFFFAFAFF),
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle: _labelStyle,
                        enabledBorder: _border,
                        focusedBorder: _focusedBorder,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Solde
                    TextField(
                      controller: _clientBalanceController,
                      enabled: false, // Make solde non-editable
                      decoration: InputDecoration(
                        labelText: 'Solde',
                        labelStyle: _labelStyle,
                        enabledBorder: _border,
                        focusedBorder: _focusedBorder,
                        disabledBorder: _border,
                      ),
                      keyboardType: TextInputType.number,
                      style: _labelStyle,
                    ),
                    const SizedBox(height: 20),
                    // Latitude
                    TextField(
                      controller: _latitudeController,
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        labelStyle: _labelStyle,
                        enabledBorder: _border,
                        focusedBorder: _focusedBorder,
                      ),
                      style: _labelStyle,
                    ),
                    const SizedBox(height: 20),
                    // Longitude
                    TextField(
                      controller: _longitudeController,
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        labelStyle: _labelStyle,
                        enabledBorder: _border,
                        focusedBorder: _focusedBorder,
                      ),
                      style: _labelStyle,
                    ),
                    const SizedBox(height: 10),
                    // Localisation button
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 151, 147, 229),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minimumSize: const Size(70, 32),
                        ),
                        onPressed: isDetectingLocation ? null : _getLocation,
                        child: isDetectingLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Localisation', style: _labelStyle),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF141E46)),
                  onPressed: () => _updateClient(client['IDCLIENT']),
                  child: const Text('Modifier',
                      style: TextStyle(fontFamily: 'ZTGatha')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD9F4E9)),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler',
                      style: TextStyle(
                          fontFamily: 'ZTGatha', color: Color(0xFF19264C))),
                ),
              ],
            ));
  }

  void _updateClient(String clientId) async {
    final updatedClientData = {
      'id_client': int.tryParse(clientId),
      'nom': _clientNameController.text,
      'tel': _clientPhoneController.text,
      'type_client': _clientTypeController.text,
      'commune': _clientAddressController.text,
      'latitude': _latitudeController.text,
      'longitude': _longitudeController.text,
      'code': _clientCodeController.text,
      'email': _clientEmailController.text,
      // 'solde': double.tryParse(_clientBalanceController.text) ?? 0.0,
    };

    final db = DatabaseHelper();
    await db.updateClient(updatedClientData);

    // Also update financials if needed
    await db.updateClientFinancials(int.parse(clientId),
        solde: double.parse((double.tryParse(_clientBalanceController.text) ?? 0.0).toStringAsFixed(2)));

    _showSnackBar('Client Updated Successfully (Local)');
    Navigator.of(context).pop();
    fetchClients();
  }

  Future<void> _getLocation() async {
    setState(() {
      isDetectingLocation = true; // Show that location detection is in progress
    });

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      setState(() {
        isDetectingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Location services are disabled. Please enable them.')),
      );
      return;
    }

    // Check for location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          isDetectingLocation = false;
        });
        // Permissions are denied, show a message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied, show a message
      setState(() {
        isDetectingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permissions are permanently denied')),
      );
      return;
    }

    // Try to get the current position with a timeout
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(Duration(seconds: 15)); // Timeout after 10 seconds

      setState(() {
        _latitudeController.text =
            "${position.latitude}"; // Changed from _location to _latitude
        _longitudeController.text = "${position.longitude}"; // Added _longitude
        locationDetected = true;
        isDetectingLocation = false; // Reset detecting state
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Location detected: ${position.latitude}, ${position.longitude}')),
      );
    } catch (e) {
      setState(() {
        isDetectingLocation = false;
      });
      if (e is TimeoutException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Location detection timed out. Please try again.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  // Method to open the form in a dialog
  void _showAddClientDialog() async {
    // Reset all controllers
    _controllers.forEach((c) => c.clear());

    // Auto-increment code
    final dbHelper = DatabaseHelper();
    final nextCode = await dbHelper.getNextClientCode();
    _clientCodeController.text = nextCode;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFAFAFF),
        title: const Text(
          'Ajouter Client',
          style: TextStyle(
            color: Color(0xFF19264C),
            fontFamily: 'Bahnschrift',
          ),
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Nom
                TextFormField(
                  controller: _clientNameController,
                  decoration: InputDecoration(
                    labelText: 'Nom',
                    labelStyle: _labelStyle,
                    enabledBorder: _border,
                    focusedBorder: _focusedBorder,
                  ),
                  style: _labelStyle,
                  validator: (v) => (v == null || v.isEmpty) ? 'Nom!' : null,
                ),
                const SizedBox(height: 20),
                // Adresse
                TextFormField(
                  controller: _clientAddressController,
                  decoration: InputDecoration(
                    labelText: 'Adresse',
                    labelStyle: _labelStyle,
                    enabledBorder: _border,
                    focusedBorder: _focusedBorder,
                  ),
                  style: _labelStyle,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Adresse!' : null,
                ),
                const SizedBox(height: 20),
                // Téléphone
                TextFormField(
                  controller: _clientPhoneController,
                  decoration: InputDecoration(
                    labelText: 'Téléphone',
                    labelStyle: _labelStyle,
                    enabledBorder: _border,
                    focusedBorder: _focusedBorder,
                  ),
                  keyboardType: TextInputType.number,
                  style: _labelStyle,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Téléphone!' : null,
                ),
                const SizedBox(height: 20),
                // Type
                DropdownButtonFormField<String>(
                  value: _clientTypeController.text.isNotEmpty
                      ? _clientTypeController.text
                      : null,
                  items: ['Detail', 'Gros'].map((type) {
                    return DropdownMenuItem(
                        value: type, child: Text(type, style: _labelStyle));
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => _clientTypeController.text = val!),
                  decoration: InputDecoration(
                    labelText: 'Type',
                    labelStyle: _labelStyle,
                    enabledBorder: _border,
                    focusedBorder: _focusedBorder,
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Type!' : null,
                ),
                const SizedBox(height: 20),
                // Solde
                TextFormField(
                  controller: _clientBalanceController,
                  decoration: InputDecoration(
                    labelText: 'Solde',
                    labelStyle: _labelStyle,
                    enabledBorder: _border,
                    focusedBorder: _focusedBorder,
                  ),
                  keyboardType: TextInputType.number,
                  style: _labelStyle,
                  validator: (v) => (v == null || v.isEmpty) ? 'Solde!' : null,
                ),
                const SizedBox(height: 20),
                // Latitude (read-only)
                TextFormField(
                  controller: _latitudeController,
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    labelStyle: _labelStyle,
                    enabledBorder: _border,
                    focusedBorder: _focusedBorder,
                  ),
                  readOnly: true,
                  style: _labelStyle,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Latitude!' : null,
                ),
                const SizedBox(height: 20),
                // Longitude (read-only)
                TextFormField(
                  controller: _longitudeController,
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    labelStyle: _labelStyle,
                    enabledBorder: _border,
                    focusedBorder: _focusedBorder,
                  ),
                  readOnly: true,
                  style: _labelStyle,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Longitude!' : null,
                ),
                const SizedBox(height: 10),
                // Localisation button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 151, 147, 229),
                      minimumSize: const Size(70, 32),
                    ),
                    onPressed: isDetectingLocation ? null : _getLocation,
                    child: isDetectingLocation
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : const Text('Localisation', style: _labelStyle),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF141E46)),
            onPressed: _addClient,
            child:
                const Text('Ajouter', style: TextStyle(fontFamily: 'ZTGatha')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9F4E9)),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler',
                style:
                    TextStyle(fontFamily: 'ZTGatha', color: Color(0xFF19264C))),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    fetchClients();
    _searchController.addListener(filterClients);
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    try {
      final result = await connectivity.checkConnectivity();
      _updateConnectivityStatus(result);
    } catch (_) {
      // Swallow errors; UI already defaults to online.
    }
    connectivitySubscription =
        connectivity.onConnectivityChanged.listen(_updateConnectivityStatus);
  }

  void _updateConnectivityStatus(dynamic result) {
    if (!mounted) return;
    final bool offline = result is List
        ? result.contains(ConnectivityResult.none)
        : result == ConnectivityResult.none;
    setState(() {
      isOffline = offline;
    });
  }

  void filterClients() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      filteredClientsList = query.isEmpty
          ? clientsList
          : clientsList.where((c) {
              final code = (c['CODECLTV']?.toString() ?? '').toLowerCase();
              final name = (c['NOMCLIENT']?.toString() ?? '').toLowerCase();
              final email = (c['EMAIL']?.toString() ?? '').toLowerCase();
              final tel = (c['TEL']?.toString() ?? '').toLowerCase();
              return code.contains(query) ||
                  name.contains(query) ||
                  email.contains(query) ||
                  tel.contains(query);
            }).toList();
    });
  }

  @override
  void dispose() {
    connectivitySubscription?.cancel();
    // _clientsSubscription?.cancel();
    _searchController.dispose();
    for (var c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = resolveUserType(vanId) == UserType.All;

    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(canEdit),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Color(0xFFFAFAFF),
      title: isSearching
          ? TextField(controller: _searchController, autofocus: true)
          : const Text(
              'Planning - Clients',
              style: TextStyle(
                color: Color(0xFF19264C),
                fontFamily: 'Bahnschrift',
              ),
            ),
      actions: [
        if (isSearching)
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.push(
              // ✅ Add navigation
              context,
              MaterialPageRoute(
                builder: (_) => QRScannerScreen(
                  onScan: (scannedCode) {
                    setState(() => _searchController.text = scannedCode);
                    filterClients(); // Also fix #3 below
                  },
                ),
              ),
            ),
          ),
        if (!isSearching)
          /*IconButton(
            icon: const Icon(Icons.file_upload, color: Color(0xFF19264C)),
            tooltip: 'Importer Clients CSV',
            onPressed: _importClientsFromCSV,
          ),*/
        IconButton(
          icon: Icon(isSearching ? Icons.close : Icons.search),
          onPressed: () => setState(() {
            if (isSearching) _searchController.clear();
            isSearching = !isSearching;
          }),
        ),
      ],
    );
  }

  Widget _buildBody(bool canEdit) {
    return Container(
      color: const Color(0xFFFAFAFF),
      child: Column(
        children: [
          Expanded(child: _buildClientList(canEdit)),
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildClientList(bool canEdit) {
    return ListView.builder(
      itemCount: filteredClientsList.length,
      itemBuilder: (context, index) {
        final client = filteredClientsList[index];
        final clientId = client['IDCLIENT']?.toString() ?? '';
        return Dismissible(
          key: ValueKey(clientId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(
              Icons.delete,
              color: Colors.white,
              size: 30,
            ),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFFFAFAFF),
                      title: const Text(
                        'Supprimer le client',
                        style: TextStyle(
                          color: Color(0xFF19264C),
                          fontFamily: 'Bahnschrift',
                        ),
                      ),
                      content: Text(
                        'Êtes-vous sûr de vouloir supprimer ${client['NOMCLIENT'] ?? 'ce client'}?',
                        style: const TextStyle(
                          fontFamily: 'ZTGatha',
                          color: Color(0xFF19264C),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFD9F4E9),
                          ),
                          child: const Text(
                            'Annuler',
                            style: TextStyle(
                              fontFamily: 'ZTGatha',
                              color: Color(0xFF19264C),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            'Supprimer',
                            style: TextStyle(
                              fontFamily: 'ZTGatha',
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ) ??
                false;
          },
          onDismissed: (direction) async {
            final clientIdInt = int.tryParse(clientId);
            if (clientIdInt != null) {
              final db = DatabaseHelper();
              await db.deleteClient(clientIdInt);
              fetchClients(); // Refresh the list
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Client supprimé avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
          },
          child: InkWell(
            onTap: () => _navigateToClientDetails(client),
            child: _buildClientCard(client, canEdit),
          ),
        );
      },
    );
  }

  void _navigateToClientDetails(Map client) {
    final clientId = client['IDCLIENT']?.toString();
    if (clientId == null) {
      _showSnackBar('Client ID is missing or invalid');
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientDetailsScreen(
            clientId: clientId,
            clientName: client['NOMCLIENT'] ?? 'Unknown Client',
          ),
        )).then((_) {
      // Refresh client list when returning from client details
      fetchClients();
    });
  }

  Card _buildClientCard(Map client, bool canEdit) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: const Color(0xFFFAFAFF),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildClientInfo(client),
                _buildEditButton(client, canEdit),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Expanded _buildClientInfo(Map client) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(client['NOMCLIENT'] ?? 'No Name',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(client['ADRESSE'] ?? 'Adresse inconnu',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9C9C9E))),
              ),
            ],
          ),
          if (((client['SOLDEINI'] as num?)?.toDouble() ?? 0.0) != 0)
            Text(
              'Crédit: ${((client['SOLDEINI'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} DA',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditButton(Map client, bool canEdit) {
    return IconButton(
      icon: const Icon(Icons.edit, size: 24),
      onPressed: canEdit ? () => _showEditClientDialog(client) : null,
    );
  }

  Widget _buildAddButton() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.0,
          top: 16.0,
          right: 16.0,
          bottom: 16.0 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB0ACFD),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16)),
          onPressed: _showAddClientDialog,
          child: const Icon(Icons.add, size: 25, color: Color(0xFF19264C)),
        ),
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  final Function(String) onScan;
  const QRScannerScreen({Key? key, required this.onScan}) : super(key: key);

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isCodeScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (BarcodeCapture capture) {
              if (!_isCodeScanned && capture.barcodes.isNotEmpty) {
                final barcode = capture.barcodes.first;
                final String? code = barcode.rawValue;
                if (code != null && code.isNotEmpty) {
                  setState(() {
                    _isCodeScanned = true;
                  });
                  widget.onScan(code);
                  Navigator.pop(context);
                }
              }
            },
          ),
          // Overlay for scanning area
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
