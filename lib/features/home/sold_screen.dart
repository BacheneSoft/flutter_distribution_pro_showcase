/// lib/sold_screen.dart
import 'package:bsoft_app_dist/features/stock/stock_management_screen.dart';
import 'package:bsoft_app_dist/data/database_helper.dart';
import 'package:bsoft_app_dist/features/auth/login_screen.dart';
import 'package:bsoft_app_dist/features/clients/client_list_screen.dart';
import 'package:bsoft_app_dist/features/sales/sales_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:bsoft_app_dist/features/home/clotures_history_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bsoft_app_dist/features/settings/settings_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class SoldScreen extends StatefulWidget {
  const SoldScreen({Key? key}) : super(key: key);

  @override
  _SoldScreenState createState() => _SoldScreenState();
}

class _SoldScreenState extends State<SoldScreen> {
  double encaissement = 0.0;
  double chiffreAffaire = 0.0;
  String vanName = '';
  String appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadEncaissement();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _loadEncaissement() async {
    final prefs = await SharedPreferences.getInstance();
    final newEncaissement = prefs.getDouble('total_encaissement') ?? 0.0;
    final newChiffreAffaire = prefs.getDouble('total_chiffre_affaire') ?? 0.0;
    final storedVanName = prefs.getString('van_name') ?? '';
    if (!mounted) return;
    setState(() {
      encaissement = newEncaissement;
      chiffreAffaire = newChiffreAffaire;
      vanName = storedVanName;
    });
  }

  Future<void> _saveEncaissement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('total_encaissement', encaissement);
    await prefs.setDouble('total_chiffre_affaire', chiffreAffaire);
  }

  Future<void> _resetEncaissementOnLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('total_encaissement', 0.0);
    await prefs.setDouble('total_chiffre_affaire', 0.0);
  }

  void _showClotureDialog() {
    final TextEditingController montantController = TextEditingController();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAFAFF),
        title: const Text(
          'Clôture',
          style: TextStyle(color: Color(0xFF19264C), fontFamily: 'Bahnschrift'),
        ),
        content: TextField(
          controller: montantController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Montant',
            labelStyle:
                TextStyle(fontFamily: 'ZTGatha', color: Color(0xFF19264C)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF19264C)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF19264C)),
            ),
          ),
          style:
              const TextStyle(fontFamily: 'ZTGatha', color: Color(0xFF19264C)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style:
                TextButton.styleFrom(backgroundColor: const Color(0xFFD9F4E9)),
            child: const Text('Annuler',
                style:
                    TextStyle(color: Color(0xFF19264C), fontFamily: 'ZTGatha')),
          ),
          ElevatedButton(
            onPressed: () async {
              final montant = montantController.text.trim();
              if (montant.isEmpty) return;
              
              final prefs = await SharedPreferences.getInstance();
              double montantValue = double.tryParse(montant) ?? 0.0;
              
              // Save cloture to history before resetting
              await DatabaseHelper().addCloture(
                clotureDate: DateTime.now().toIso8601String(),
                montant: montantValue,
                encaissement: encaissement,
                chiffreAffaire: chiffreAffaire,
              );
              
              // Now reset encaissement and chiffre d'affaire
              await _resetEncaissementOnLogout();
              
              // Reset inventory tracking columns (quantity_sold and quantity_char)
              await DatabaseHelper().resetInventoryTracking();
              
              if (!mounted) return;
              setState(() {
                encaissement = 0.0;
                chiffreAffaire = 0.0;
                depots = [];
                selectedDepotId = null;
                selectedDepotMarchandises = [];
                clientsList = [];
                filteredClientsList = [];
              });
              await _saveEncaissement();
              
              // Reset local van stats (encaissement and chiffre_affaire in vans table)
              int? userId = prefs.getInt('db_id_user');
              if (userId != null) {
                 final van = await DatabaseHelper().getVanByUserId(userId);
                 if (van != null) {
                   await DatabaseHelper().resetVanStats(van['id_van']);
                 }
              }

              Navigator.pop(context);
              
              // Refresh the screen to show updated values
              _loadEncaissement();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Clôture effectuée avec succès'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF19264C)),
            child:
                const Text('Clôture', style: TextStyle(fontFamily: 'ZTGatha')),
          ),
        ],
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _loadEncaissement());
  }

  Future<void> _handleLogout() async {
    // Do NOT reset encaissement and chiffre d'affaire on logout
    // They should persist until cloture
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', false);
    await prefs.remove('userId');
    
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _showEditVanNameDialog() {
    final TextEditingController nameController = TextEditingController(text: vanName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAFAFF),
        title: const Text(
          'Modifier Nom Van',
          style: TextStyle(color: Color(0xFF19264C), fontFamily: 'Bahnschrift'),
        ),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nom Van',
            labelStyle: TextStyle(fontFamily: 'ZTGatha', color: Color(0xFF19264C)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF19264C)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF19264C)),
            ),
          ),
          style: const TextStyle(fontFamily: 'ZTGatha', color: Color(0xFF19264C)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(backgroundColor: const Color(0xFFD9F4E9)),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Color(0xFF19264C), fontFamily: 'ZTGatha'),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('van_name', newName);
                setState(() {
                  vanName = newName;
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF19264C)),
            child: const Text('Enregistrer', style: TextStyle(fontFamily: 'ZTGatha')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showEditVanNameDialog,
          child: Text(
            vanName.isEmpty ? 'No Van name' : vanName,
            style: const TextStyle(
              fontFamily: 'Bahnschrift',
              fontSize: 24,
              color: Color(0xFF19264C),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF19264C)),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: Color(0xFF19264C)),
                  child: Text('Profile',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontFamily: 'Odin Rounded')),
                ),
                _buildDrawerItem(Icons.home, 'Home'),
                _buildDrawerItem(Icons.file_download, 'Exporter',
                    action: _handleExport),
                _buildDrawerItem(Icons.file_upload, 'Importer',
                    action: _handleImport),
                _buildDrawerItem(Icons.history, 'Historique Clôtures',
                    action: _showCloturesHistory),
                _buildDrawerItem(Icons.settings, 'Paramètres',
                    action: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    }),
                _buildDrawerItem(Icons.exit_to_app, 'Deconnecté',
                    action: _handleLogout),
              ]),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Text(
                'Version: $appVersion',
                style: const TextStyle(
                  fontFamily: 'Odin Rounded',
                  fontSize: 14,
                  color: Color(0xFF19264C),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFFFAFAFF),
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: _buildCustomButton(
                          'Planning',
                          'assets/images/Planning_icon_11.webp',
                          () => _navigateTo(const UserScreen()))),
                ]),
                const SizedBox(height: 40),
                Wrap(
                    spacing: 5,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildSquareIconButton(
                        'assets/images/Stock_Van_icon_13.webp',
                        'Stock Van',
                        true,
                        () => _navigateTo(const StockManagementScreen()),
                      ),
                      /*_buildSquareIconButton(
                          'assets/images/Stock_Van_icon_13.webp',
                          'Stock Van',
                          true,
                          () => _navigateTo(const StockScreen())),
                      _buildSquareIconButton(
                          'assets/images/Dechar_icon_14.webp',
                          'Décharge',
                          true,
                          () => _navigateTo(const StockScreenDecharge())),
                      _buildSquareIconButton('assets/images/Charge_13.webp',
                          'D.Charge', false, null),*/
                      _buildSquareIconButton(
                          'assets/images/Clients_icon_16.webp',
                          'Client',
                          false,
                          null),
                      _buildSquareIconButton('assets/images/Pieces_15.webp',
                          'Pièces', false, null),
                      /*_buildSquareIconButton('assets/images/Promotion_16.webp',
                          'Promotion', false, null),*/

                      /*_buildSquareIconButton('assets/images/Parametres_18.webp',
                          'Parametres', false, null),*/
                    ]),
                const SizedBox(height: 40),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                          child: _buildDataCard('Chiffre d\'affaire',
                              '${chiffreAffaire.toStringAsFixed(2)} DA')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildDataCard('Encaissement',
                              '${encaissement.toStringAsFixed(2)} DA')),
                    ]),
              ]),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 10,
              right: 10,
              top: 5,
              bottom: 5 + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: Row(children: [
              Expanded(
                  child: _buildBottomButton('Clôture', _showClotureDialog)),
              const SizedBox(width: 10),
              //Expanded(child: _buildBottomButton('Synchroniser', () {})),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildCustomButton(String label, String iconPath, VoidCallback onTap) {
    final screenWidth = MediaQuery.of(context).size.width;
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF19264C),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 8,
        shadowColor: Colors.black45,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset(iconPath,
            width: screenWidth * 0.08, height: screenWidth * 0.1),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontFamily: 'ZTGatha'),
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildSquareIconButton(
      String iconPath, String label, bool enabled, VoidCallback? onTap) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      width: screenWidth * 0.22, // Slightly less than 25% to allow spacing
      child: Column(
        children: [
          Container(
            height: screenWidth * 0.15, // Make card taller
            padding: const EdgeInsets.all(8), // Add internal spacing
            decoration: BoxDecoration(
              color: enabled ? const Color(0xFFB0BEC5) : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(8),
              child: Center(
                child: Image.asset(
                  iconPath,
                  width: screenWidth * 0.11, // Smaller image
                  height: screenWidth * 0.11,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontFamily: 'ZTGatha'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard(String title, String value) => Card(
        color: const Color(0xFFD9F4E9),
        elevation: 8,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontFamily: 'Odin Rounded')),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontFamily: 'Odin Rounded', fontWeight: FontWeight.bold)),
          ]),
        ),
      );

  Widget _buildBottomButton(String label, VoidCallback onTap) => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF19264C),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 8,
          shadowColor: Colors.black45,
        ),
        child: Text(label, style: const TextStyle(fontFamily: 'ZTGatha')),
      );

  Widget _buildDrawerItem(IconData icon, String title,
          {VoidCallback? action}) =>
      ListTile(
        leading: Icon(icon, color: const Color(0xFF19264C)),
        title: Text(title, style: const TextStyle(fontFamily: 'Odin Rounded')),
        onTap: action ?? () => Navigator.pop(context),
      );

  Future<void> _handleExport() async {
    try {
      Navigator.pop(context); // Close drawer
      
      // Get database path
      final dbPath = await DatabaseHelper().getDatabasePath();
      final dbFile = File(dbPath);
      
      if (!await dbFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base de données introuvable')),
        );
        return;
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Préparation de l\'export...')),
      );

      // Create a temporary file to share
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      // Use .db.bin to bypass Gmail/Android restrictions on .db files
      final tempFile = File('${tempDir.path}/bsoft_backup_$timestamp.db.bin');
      
      // Copy database to temp file
      await dbFile.copy(tempFile.path);

      // Share the file using native share sheet
      // This allows saving to "Downloads", "Drive", etc.
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Sauvegarde Base de données Bsoft - $timestamp',
        subject: 'Bsoft Backup $timestamp',
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'export: $e')),
        );
      }
    }
  }

  Future<void> _handleImport() async {
    try {
      Navigator.pop(context); // Close drawer
      
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFFAFAFF),
          title: const Text(
            'Importer la base de données',
            style: TextStyle(color: Color(0xFF19264C), fontFamily: 'Bahnschrift'),
          ),
          content: const Text(
            'Attention: L\'importation remplacera toutes les données actuelles. Votre base actuelle sera sauvegardée par sécurité. Êtes-vous sûr?',
            style: TextStyle(fontFamily: 'ZTGatha', color: Color(0xFF19264C)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler', style: TextStyle(fontFamily: 'ZTGatha')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF19264C),
              ),
              child: const Text('Importer', style: TextStyle(fontFamily: 'ZTGatha')),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Use FilePicker to select the .db file from anywhere (Downloads, etc.)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // .db files often need general picking
      );

      if (result == null || result.files.single.path == null) return;

      final selectedFile = File(result.files.single.path!);
      
      // Validation: accept .db or .bin extensions
      final pathLower = selectedFile.path.toLowerCase();
      if (!pathLower.endsWith('.db') && !pathLower.endsWith('.bin')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fichier invalide. Veuillez sélectionner un fichier .db ou .bin')),
          );
        }
        return;
      }

      // Get current database path
      final dbPath = await DatabaseHelper().getDatabasePath();
      final dbFile = File(dbPath);

      // Backup current database before replacing (extra safety)
      final backupPath = '$dbPath.backup_${DateTime.now().millisecondsSinceEpoch}';
      if (await dbFile.exists()) {
        await dbFile.copy(backupPath);
      }

      // Copy imported file to database location
      await selectedFile.copy(dbPath);
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Import réussi'),
            content: const Text('La base de données a été importée. L\'application va maintenant se fermer pour appliquer les changements. Veuillez la redémarrer manuellement.'),
            actions: [
              ElevatedButton(
                onPressed: () => exit(0),
                child: const Text('Quitter'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'import: $e')),
        );
      }
    }
  }

  void _showCloturesHistory() {
    Navigator.pop(context); // Close drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CloturesHistoryScreen()),
    );
  }
}
