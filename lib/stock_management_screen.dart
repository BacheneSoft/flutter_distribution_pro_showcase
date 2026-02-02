import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';
import 'pdfgen.dart';

class StockManagementScreen extends StatefulWidget {
  const StockManagementScreen({Key? key}) : super(key: key);
  @override
  _StockManagementScreenState createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> _items = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = true;
  String _vanName = '';

  @override
  void initState() {
    super.initState();
    _loadVanName();
    _loadData();
  }

  Future<void> _loadVanName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vanName = prefs.getString('van_name') ?? '';
    });
  }

  Future<void> _loadData() async {
    final items = await _db.getItems();
    final categories = await _db.getCategories();
    if (!mounted) return;
    setState(() {
      _items = items;
      _categories = categories;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredItems => _selectedCategory == null
      ? _items
      : _items
          .where((item) => item['category'] == _selectedCategory)
          .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Stock',
          style: TextStyle(
            color: Color(0xFF19264C),
            fontFamily: 'Bahnschrift',
          ),
        ),
        backgroundColor: const Color(0xFFFAFAFF),
        actions: [
          // CSV Import/Export - Commented for future use
          // IconButton(
          //   icon: const Icon(Icons.file_upload, color: Color(0xFF19264C)),
          //   tooltip: 'Importer CSV',
          //   onPressed: _importFromCSV,
          // ),
          // IconButton(
          //   icon: const Icon(Icons.file_download, color: Color(0xFF19264C)),
          //   tooltip: 'Exporter CSV',
          //   onPressed: _exportToCSV,
          // ),
          
          // XML Import/Export
          IconButton(
            icon: const Icon(Icons.upload_file, color: Color(0xFF19264C)),
            tooltip: 'Importer XML',
            onPressed: _importFromXML,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF19264C)),
            tooltip: 'Exporter XML',
            onPressed: _exportToXML,
          ),
          IconButton(
            icon: const Icon(Icons.print, color: Color(0xFF19264C)),
            tooltip: 'Imprimer Stock',
            onPressed: () => generateStockPDF(_filteredItems),
          ),
          DropdownButton<String?>(
            value: _selectedCategory,
            hint: const Text('Catégorie'),
            underline: const SizedBox.shrink(),
            dropdownColor: Colors.white,
            onChanged: (value) => setState(() => _selectedCategory = value),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Toutes catégories'),
              ),
              ..._categories.map(
                (cat) => DropdownMenuItem<String?>(
                  value: cat,
                  child: Text(cat),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filteredItems.isEmpty
              ? const Center(child: Text('Aucun article'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    itemCount: _filteredItems.length,
                    itemBuilder: (_, index) {
                      final item = _filteredItems[index];
                      return Card(
                        color: const Color(0xFFFAFAFF),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(
                            item['item_name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Bahnschrift',
                              color: Color(0xFF19264C),
                            ),
                          ),
                          subtitle: Text(
                            '${item['category'] ?? 'Sans catégorie'} • Stock: ${item['stock_quantity'] ?? 0}',
                            style: const TextStyle(
                              fontFamily: 'ZTGatha',
                              fontSize: 13,
                              color: Color.fromARGB(255, 156, 156, 158),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditDialog(item),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom,
        ),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFFB0ACFD),
          onPressed: _showAddDialog,
          child: const Icon(Icons.add, color: Color(0xFF19264C)),
        ),
      ),
    );
  }

  // CSV Export - Commented for future use
  // Future<void> _exportToCSV() async {
  //   try {
  //     List<List<dynamic>> rows = [];
  //     
  //     // Header row
  //     rows.add([
  //       'Nom Van',
  //       'Code Article',
  //       'Designation',
  //       'Categorie',
  //       'Prix Detail',
  //       'Prix Gros',
  //       'Stock (Unites)',
  //       'Cartons',
  //       'Unites/Carton',
  //       'Quantite Vendue',
  //       'Quantite Chargée',
  //     ]);
  //     
  //     // Data rows
  //     for (var item in _items) {
  //       rows.add([
  //         _vanName,
  //         item['code_article']?.toString() ?? '',
  //         item['item_name'] ?? '',
  //         item['category'] ?? '',
  //         item['unit_price']?.toString() ?? '0',
  //         item['pu_art_gros']?.toString() ?? '0',
  //         item['stock_quantity']?.toString() ?? '0',
  //         item['nbre_colis']?.toString() ?? '0',
  //         item['cond']?.toString() ?? '0',
  //         item['quantity_sold']?.toString() ?? '0',
  //         item['quantity_char']?.toString() ?? '0',
  //       ]);
  //     }
  //     
  //     String csvData = const ListToCsvConverter().convert(rows);
  //     final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  //     
  //     // Show dialog to choose action
  //     if (!mounted) return;
  //     final action = await showDialog<String>(
  //       context: context,
  //       builder: (context) => AlertDialog(
  //         backgroundColor: const Color(0xFFFAFAFF),
  //         title: const Text(
  //           'Exporter Stock',
  //           style: TextStyle(color: Color(0xFF19264C), fontFamily: 'Bahnschrift'),
  //         ),
  //         content: const Text(
  //           'Choisissez une action:',
  //           style: TextStyle(fontFamily: 'ZTGatha'),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context, 'cancel'),
  //             child: const Text('Annuler', style: TextStyle(fontFamily: 'ZTGatha')),
  //           ),
  //           ElevatedButton.icon(
  //             icon: const Icon(Icons.folder),
  //             label: const Text('Enregistrer', style: TextStyle(fontFamily: 'ZTGatha')),
  //             style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF19264C)),
  //             onPressed: () => Navigator.pop(context, 'save'),
  //           ),
  //           ElevatedButton.icon(
  //             icon: const Icon(Icons.share),
  //             label: const Text('Partager', style: TextStyle(fontFamily: 'ZTGatha')),
  //             style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF19264C)),
  //             onPressed: () => Navigator.pop(context, 'share'),
  //           ),
  //         ],
  //       ),
  //     );
  //     
  //     if (action == null || action == 'cancel') return;
  //     
  //     if (action == 'save') {
  //       // Save to Downloads folder
  //       if (Platform.isAndroid) {
  //         var status = await Permission.storage.status;
  //         if (!status.isGranted) {
  //           status = await Permission.storage.request();
  //         }
  //
  //         if (status.isGranted) {
  //           final directory = Directory('/storage/emulated/0/Download');
  //           if (!await directory.exists()) {
  //             await directory.create(recursive: true);
  //           }
  //           final path = "${directory.path}/stock_export_$timestamp.csv";
  //           final file = File(path);
  //           await file.writeAsString(csvData);
  //           
  //           if (!mounted) return;
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(
  //               content: Text('Fichier sauvegardé dans:\n$path'),
  //               duration: const Duration(seconds: 5),
  //             ),
  //           );
  //           return;
  //         } else {
  //           if (!mounted) return;
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             const SnackBar(content: Text('Permission de stockage refusée')),
  //           );
  //           return;
  //         }
  //       }
  //     } else if (action == 'share') {
  //       // Share via apps
  //       final directory = await getApplicationDocumentsDirectory();
  //       final path = "${directory.path}/stock_export_$timestamp.csv";
  //       final file = File(path);
  //       await file.writeAsString(csvData);
  //       
  //       await Share.shareXFiles([XFile(path)], text: 'Export Stock');
  //       
  //       if (!mounted) return;
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Partage en cours...')),
  //       );
  //     }
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Erreur lors de l\'export: $e')),
  //     );
  //   }
  // }


    Future<void> _exportToXML() async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      
      // Fetch flat sales data
      final salesData = await _db.getSalesExportData(dateStr);
      final paymentsData = await _db.getPaymentsExportData(dateStr);
      // Fetch all items for "rest of items" tracking
      final allItems = await _db.getItems();

      // Build XML content
      StringBuffer xmlBuffer = StringBuffer();
      xmlBuffer.writeln('<?xml version="1.0" standalone="yes"?>');
      xmlBuffer.writeln('<DATAPACKET Version="2.0">');
      xmlBuffer.writeln('<METADATA>');
      xmlBuffer.writeln('<FIELDS>');
      
      // Define flat fields as requested
      xmlBuffer.writeln('<FIELD FieldName="NO_ORDRE" DisplayLabel="NO_ORDRE" FieldType="Integer" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="nom_cl" DisplayLabel="nom_cl" FieldType="String" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="code_cl" DisplayLabel="code_cl" FieldType="Integer" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="ADRESSE" DisplayLabel="ADRESSE" FieldType="String" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="TELEPHONE" DisplayLabel="TELEPHONE" FieldType="String" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="TYPE" DisplayLabel="TYPE" FieldType="String" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="id_sale" DisplayLabel="id_sale" FieldType="Integer" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="id_user" DisplayLabel="id_user" FieldType="String" FieldClass="TField"/>'); // Using String for van name
      xmlBuffer.writeln('<FIELD FieldName="NUM_BL" DisplayLabel="NUM_BL" FieldType="String" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="DATE_P" DisplayLabel="DATE_P" FieldType="Date" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="TIME_P" DisplayLabel="TIME_P" FieldType="Time" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="TOTAL_AMOUNT" DisplayLabel="TOTAL_AMOUNT" FieldType="Float" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="TOTAL_PAYMENT" DisplayLabel="TOTAL_PAYMENT" FieldType="Float" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="REGLEMENT" DisplayLabel="REGLEMENT" FieldType="Float" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="SOLDE" DisplayLabel="SOLDE" FieldType="Float" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="code_article" DisplayLabel="code_article" FieldType="String" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="tax" DisplayLabel="tax" FieldType="Float" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="cond" DisplayLabel="cond" FieldType="Float" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="designation" DisplayLabel="designation" FieldType="String" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="nbre_colis" DisplayLabel="nbre_colis" FieldType="Float" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="stock_quantity" DisplayLabel="stock_quantity" FieldType="Float" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="unit_price" DisplayLabel="unit_price" FieldType="Float" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="pu_art_gros" DisplayLabel="pu_art_gros" FieldType="Float" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="discount" DisplayLabel="discount" FieldType="Float" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="SOLDE_INIT" DisplayLabel="SOLDE_INIT" FieldType="Float" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="VALIDE" DisplayLabel="VALIDE" FieldType="String" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="MODE_PAIEMENT" DisplayLabel="MODE_PAIEMENT" FieldType="String" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="QUANT_CHARGEE" DisplayLabel="QUANT_CHARGEE" FieldType="Float" FieldClass="TField"/>');
      xmlBuffer.writeln('<FIELD FieldName="RESTE_VAN" DisplayLabel="RESTE_VAN" FieldType="Float" FieldClass="TField"/>');
      
      xmlBuffer.writeln('</FIELDS>');
      xmlBuffer.writeln('</METADATA>');
      xmlBuffer.writeln('<ROWDATA>');
      
      final vanName = _escapeXmlAttribute(_vanName);
      int noOrdre = 1;
      
      // 1. Export Sales
      for (var row in salesData) {
        final quantitySold = row['quantity_sold'] as int? ?? 0;
        final cond = row['cond'] as int? ?? 1; // Avoid division by zero
        final nbreColis = cond > 0 ? (quantitySold / cond).floor() : 0;
        
        final adresse = _escapeXmlAttribute('${row['commune'] ?? ''} ${row['cite'] ?? ''}'.trim());
        
        xmlBuffer.write('<ROW NO_ORDRE="$noOrdre" ');
        xmlBuffer.write('nom_cl="${_escapeXmlAttribute(row['nom_cl']?.toString() ?? '')}" ');
        xmlBuffer.write('code_cl="${_escapeXmlAttribute(row['code_cl']?.toString() ?? '')}" ');
        xmlBuffer.write('ADRESSE="$adresse" ');
        xmlBuffer.write('TELEPHONE="${_escapeXmlAttribute(row['tel']?.toString() ?? '')}" ');
        xmlBuffer.write('TYPE="${_escapeXmlAttribute(row['type_client']?.toString() ?? '')}" ');
        xmlBuffer.write('id_sale="${row['id_sale']}" ');
        xmlBuffer.write('id_user="$vanName" ');
        xmlBuffer.write('NUM_BL="${_escapeXmlAttribute(row['num_bl']?.toString() ?? '')}" ');
        
        String timestamp = row['sale_date']?.toString() ?? '';
        String dateP = timestamp.split(' ')[0];
        if (dateP.contains('-')) {
          List<String> parts = dateP.split('-');
          if (parts.length == 3) {
            dateP = "${parts[2]}-${parts[1]}-${parts[0]}";
          }
        }
        String timeP = timestamp.contains(' ') ? timestamp.split(' ')[1] : '';
        
        xmlBuffer.write('DATE_P="$dateP" ');
        xmlBuffer.write('TIME_P="$timeP" ');
        xmlBuffer.write('TOTAL_AMOUNT="${row['total_amount'] ?? 0}" ');
        xmlBuffer.write('TOTAL_PAYMENT="${row['payment_amount'] ?? 0}" ');
        xmlBuffer.write('REGLEMENT="0" ');
        xmlBuffer.write('SOLDE="${((row['solde'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}" ');
        xmlBuffer.write('code_article="${_escapeXmlAttribute(row['code_article']?.toString() ?? '')}" ');
        xmlBuffer.write('tax="${row['tax'] ?? 0}" ');
        xmlBuffer.write('cond="${row['cond'] ?? 0}" ');
        xmlBuffer.write('designation="${_escapeXmlAttribute(row['designation']?.toString() ?? '')}" ');
        xmlBuffer.write('nbre_colis="$nbreColis" ');
        xmlBuffer.write('stock_quantity="$quantitySold" ');
        xmlBuffer.write('unit_price="${row['unit_price'] ?? 0}" ');
        xmlBuffer.write('pu_art_gros="${row['pu_art_gros'] ?? 0}" ');
        xmlBuffer.write('discount="${row['discount'] ?? 0}" ');
        xmlBuffer.write('SOLDE_INIT="${((row['solde_init'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}" ');
        xmlBuffer.write('VALIDE="${row['payment_status'] == 'paid' ? 'oui' : 'non'}" ');
        xmlBuffer.write('MODE_PAIEMENT="${_escapeXmlAttribute(row['payment_method']?.toString() ?? 'Espece')}" ');
        xmlBuffer.write('QUANT_CHARGEE="${row['quantity_char'] ?? 0}" ');
        xmlBuffer.write('RESTE_VAN="${row['stock_quantity'] ?? 0}"');
        xmlBuffer.writeln('/>');
        noOrdre++;
      }

      // 2. Export Standalone Payments (Reglements)
      for (var row in paymentsData) {
        final adresse = _escapeXmlAttribute('${row['commune'] ?? ''} ${row['cite'] ?? ''}'.trim());
        
        xmlBuffer.write('<ROW NO_ORDRE="$noOrdre" ');
        xmlBuffer.write('nom_cl="${_escapeXmlAttribute(row['nom_cl']?.toString() ?? '')}" ');
        xmlBuffer.write('code_cl="${_escapeXmlAttribute(row['code_cl']?.toString() ?? '')}" ');
        xmlBuffer.write('ADRESSE="$adresse" ');
        xmlBuffer.write('TELEPHONE="${_escapeXmlAttribute(row['tel']?.toString() ?? '')}" ');
        xmlBuffer.write('TYPE="${_escapeXmlAttribute(row['type_client']?.toString() ?? '')}" ');
        xmlBuffer.write('id_sale="0" '); // No sale ID for reglement
        xmlBuffer.write('id_user="$vanName" ');
        xmlBuffer.write('NUM_BL="" ');
        
        String timestamp = row['payment_date']?.toString() ?? '';
        String dateP = timestamp.split(' ')[0];
        if (dateP.contains('-')) {
          List<String> parts = dateP.split('-');
          if (parts.length == 3) {
            dateP = "${parts[2]}-${parts[1]}-${parts[0]}";
          }
        }
        String timeP = timestamp.contains(' ') ? timestamp.split(' ')[1] : '';
        
        xmlBuffer.write('DATE_P="$dateP" ');
        xmlBuffer.write('TIME_P="$timeP" ');
        xmlBuffer.write('TOTAL_AMOUNT="0" ');
        xmlBuffer.write('TOTAL_PAYMENT="0" ');
        xmlBuffer.write('REGLEMENT="${((row['reglement'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}" ');
        xmlBuffer.write('SOLDE="0" ');
        xmlBuffer.write('code_article="" ');
        xmlBuffer.write('tax="0" ');
        xmlBuffer.write('cond="0" ');
        xmlBuffer.write('designation="REGLEMENT ${row['method'] ?? ''}" ');
        xmlBuffer.write('nbre_colis="0" ');
        xmlBuffer.write('stock_quantity="0" ');
        xmlBuffer.write('unit_price="0" ');
        xmlBuffer.write('pu_art_gros="0" ');
        xmlBuffer.write('discount="0" ');
        xmlBuffer.write('SOLDE_INIT="${((row['solde_init'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}" ');
        xmlBuffer.write('VALIDE="oui" ');
        xmlBuffer.write('MODE_PAIEMENT="${_escapeXmlAttribute(row['method']?.toString() ?? 'Espece')}" ');
        xmlBuffer.write('QUANT_CHARGEE="0" ');
        xmlBuffer.write('RESTE_VAN="0"');
        xmlBuffer.writeln('/>');
        noOrdre++;
      }

      // 3. Export Inventory Status (All Items)
      // This includes items not sold today as well
      final todayStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      for (var item in allItems) {
        xmlBuffer.write('<ROW NO_ORDRE="$noOrdre" ');
        xmlBuffer.write('nom_cl="INVENTAIRE" ');
        xmlBuffer.write('code_cl="0" ');
        xmlBuffer.write('ADRESSE="" ');
        xmlBuffer.write('TELEPHONE="" ');
        xmlBuffer.write('TYPE="" ');
        xmlBuffer.write('id_sale="0" ');
        xmlBuffer.write('id_user="$vanName" ');
        xmlBuffer.write('NUM_BL="${_escapeXmlAttribute(item['num_bl']?.toString() ?? '')}" ');
        xmlBuffer.write('DATE_P="$todayStr" ');
        xmlBuffer.write('TIME_P="" ');
        xmlBuffer.write('TOTAL_AMOUNT="0" ');
        xmlBuffer.write('TOTAL_PAYMENT="0" ');
        xmlBuffer.write('REGLEMENT="0" ');
        xmlBuffer.write('SOLDE="0" ');
        xmlBuffer.write('code_article="${_escapeXmlAttribute(item['code_article']?.toString() ?? '')}" ');
        xmlBuffer.write('tax="0" ');
        xmlBuffer.write('cond="${item['cond'] ?? 0}" ');
        xmlBuffer.write('designation="${_escapeXmlAttribute(item['item_name']?.toString() ?? '')}" ');
        xmlBuffer.write('nbre_colis="0" ');
        xmlBuffer.write('stock_quantity="0" ');
        xmlBuffer.write('unit_price="${item['unit_price'] ?? 0}" ');
        xmlBuffer.write('pu_art_gros="${item['pu_art_gros'] ?? 0}" ');
        xmlBuffer.write('discount="0" ');
        xmlBuffer.write('SOLDE_INIT="0" ');
        xmlBuffer.write('VALIDE="oui" ');
        xmlBuffer.write('MODE_PAIEMENT="Inventaire" ');
        xmlBuffer.write('QUANT_CHARGEE="${item['quantity_char'] ?? 0}" ');
        xmlBuffer.write('RESTE_VAN="${item['stock_quantity'] ?? 0}"');
        xmlBuffer.writeln('/>');
        noOrdre++;
      }

      xmlBuffer.writeln('</ROWDATA>');
      xmlBuffer.writeln('</DATAPACKET>');

      
      String xmlData = xmlBuffer.toString();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      
      // Show dialog to choose action
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFFAFAFF),
          title: const Text(
            'Exporter Global (XML)',
            style: TextStyle(color: Color(0xFF19264C), fontFamily: 'Bahnschrift'),
          ),
          content: const Text(
            'Données: Stock, Clients, Ventes, Paiements\nChoisissez une action:',
            style: TextStyle(fontFamily: 'ZTGatha'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Annuler', style: TextStyle(fontFamily: 'ZTGatha')),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder),
              label: const Text('Enregistrer', style: TextStyle(fontFamily: 'ZTGatha')),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF19264C)),
              onPressed: () => Navigator.pop(context, 'save'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Partager', style: TextStyle(fontFamily: 'ZTGatha')),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF19264C)),
              onPressed: () => Navigator.pop(context, 'share'),
            ),
          ],
        ),
      );
      
      if (action == null || action == 'cancel') return;
      
      if (action == 'save') {
        // Save to Downloads folder
        if (Platform.isAndroid) {
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }

          if (status.isGranted) {
            final directory = Directory('/storage/emulated/0/Download');
            if (!await directory.exists()) {
              await directory.create(recursive: true);
            }
            final path = "${directory.path}/global_export_$timestamp.xml";
            final file = File(path);
            await file.writeAsString(xmlData);
            
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Fichier XML sauvegardé dans:\n$path'),
                duration: const Duration(seconds: 5),
              ),
            );
            return;
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permission de stockage refusée')),
            );
            return;
          }
        }
      } else if (action == 'share') {
        // Share via apps
        final directory = await getApplicationDocumentsDirectory();
        final path = "${directory.path}/global_export_$timestamp.xml";
        final file = File(path);
        await file.writeAsString(xmlData);
        
        await Share.shareXFiles([XFile(path)], text: 'Export Global XML');
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partage en cours...')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'export XML: $e')),
      );
    }
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _escapeXmlAttribute(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }



  // CSV Import - Commented for future use
  // Future<void> _importFromCSV() async {
  //   try {
  //     // Pick CSV file from device
  //     FilePickerResult? result = await FilePicker.platform.pickFiles(
  //       type: FileType.custom,
  //       allowedExtensions: ['csv'],
  //     );
  //
  //     if (result == null || result.files.single.path == null) {
  //       return; // User canceled the picker
  //     }
  //
  //     final filePath = result.files.single.path!;
  //     final file = File(filePath);
  //     
  //     // Read and parse CSV
  //     final csvString = await file.readAsString();
  //     final List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);
  //     
  //     if (csvData.isEmpty || csvData.length < 2) {
  //       if (!mounted) return;
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Fichier CSV vide ou invalide')),
  //       );
  //       return;
  //     }
  //     
  //     // Skip header row (index 0), process data rows
  //     int importedCount = 0;
  //     int skippedCount = 0;
  //     
  //     for (int i = 1; i < csvData.length; i++) {
  //       final row = csvData[i];
  //       
  //       // Validate row has enough columns (now we have Nom Van as first column)
  //       if (row.length < 8) {
  //         skippedCount++;
  //         continue;
  //       }
  //       
  //       try {
  //         final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  //         // Row indices: 0=Nom Van (skip), 1=Code Article, 2=Designation, 3=Category, 4=Prix Detail, 5=Prix Gros, 6=Stock, 7=Cartons, 8=Cond, 9=Qty Sold, 10=Qty Char
  //         final stockQty = int.tryParse(row[6]?.toString() ?? '0') ?? 0;
  //         
  //         await _db.addItem({
  //           'item_name': row[2]?.toString() ?? 'Sans nom',
  //           'description': '',
  //           'code_article': row[1]?.toString() ?? '',
  //           'category': row[3]?.toString() ?? '',
  //           'unit_price': double.tryParse(row[4]?.toString() ?? '0') ?? 0.0,
  //           'pu_art_gros': double.tryParse(row[5]?.toString() ?? '0') ?? 0.0,
  //           'stock_quantity': stockQty,
  //           'nbre_colis': int.tryParse(row[7]?.toString() ?? '0') ?? 0,
  //           'cond': int.tryParse(row[8]?.toString() ?? '0') ?? 0,
  //           'quantity_sold': row.length > 9 ? (int.tryParse(row[9]?.toString() ?? '0') ?? 0) : 0,
  //           'quantity_char': row.length > 10 ? (int.tryParse(row[10]?.toString() ?? '0') ?? stockQty) : stockQty,
  //           'created_at': now,
  //           'updated_at': now,
  //         });
  //         importedCount++;
  //       } catch (e) {
  //         skippedCount++;
  //         print('Error importing row $i: $e');
  //       }
  //     }
  //     
  //     // Reload data
  //     await _loadData();
  //     
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Importation terminée: $importedCount ajouté(s), $skippedCount ignoré(s)'),
  //         duration: const Duration(seconds: 3),
  //       ),
  //     );
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Erreur lors de l\'import: $e')),
  //     );
  //   }
  // }

  // XML Import - Parse DATAPACKET format
  Future<void> _importFromXML() async {
    try {
      // Pick XML file from device
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml'],
      );

      if (result == null || result.files.single.path == null) {
        return; // User canceled the picker
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);
      
      // Read and parse XML
      final xmlString = await file.readAsString();
      final document = XmlDocument.parse(xmlString);
      
      // Clear existing stock data before import
      await _db.deleteAllItems();
      
      // Find ROWDATA element
      final rowData = document.findAllElements('ROWDATA').firstOrNull;
      if (rowData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier XML invalide: ROWDATA non trouvé')),
        );
        return;
      }
      
      // Process each ROW element
      int importedCount = 0;
      int skippedCount = 0;
      
      for (var row in rowData.findElements('ROW')) {
        try {
          final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
          
          // Extract attributes from ROW element
          final codeArticle = row.getAttribute('COD_ARTICLE') ?? '';
          final designation = row.getAttribute('DESIGNATION') ?? 'Sans nom';
          final category = row.getAttribute('CATEGORIE') ?? '';
          final numBl = row.getAttribute('NUM_BL') ?? '';

          // Parse numbers - handle comma-formatted numbers (e.g., "1,296.00")
          
          // Parse numbers - handle comma-formatted numbers (e.g., "1,296.00")
          final prixDetailStr = (row.getAttribute('PRIX_DETAIL') ?? '0').replaceAll(',', '');
          final prixGrosStr = (row.getAttribute('PRIX_GROS') ?? '0').replaceAll(',', '');
          final quantiteChargeeStr = (row.getAttribute('QUANTITE_CHARGEE') ?? '0').replaceAll(',', '');
          final stockUnitesStr = (row.getAttribute('STOCK_UNITES') ?? quantiteChargeeStr).replaceAll(',', '');
          final nbreColisStr = (row.getAttribute('NBRE_COLIS') ?? '0').replaceAll(',', '');
          final unitesParCartonStr = (row.getAttribute('UNITES_PAR_CARTON') ?? '0').replaceAll(',', '');
          final quantiteVendueStr = (row.getAttribute('QUANTITE_VENDUE') ?? '0').replaceAll(',', '');
          
          final prixDetail = double.tryParse(prixDetailStr) ?? 0.0;
          final prixGros = double.tryParse(prixGrosStr) ?? 0.0;
          
          // QUANTITE_CHARGEE is used for both stock_quantity and quantity_char if STOCK_UNITES is not present
          final quantiteChargee = double.tryParse(quantiteChargeeStr)?.toInt() ?? 0;
          final stockUnites = double.tryParse(stockUnitesStr)?.toInt() ?? quantiteChargee;
          
          final nbreColis = double.tryParse(nbreColisStr)?.toInt() ?? 0;
          final unitesParCarton = double.tryParse(unitesParCartonStr)?.toInt() ?? 0;
          final quantiteVendue = double.tryParse(quantiteVendueStr)?.toInt() ?? 0;
          
          // Add item to database
          await _db.addItem({
            'item_name': designation,
            'description': '',
            'code_article': codeArticle,
            'category': category,
            'unit_price': prixDetail,
            'pu_art_gros': prixGros,
            'stock_quantity': stockUnites,
            'nbre_colis': nbreColis,
            'cond': unitesParCarton,
            'quantity_sold': quantiteVendue,
            'quantity_char': quantiteChargee,
            'num_bl': numBl,
            'created_at': now,
            'updated_at': now,
          });
          importedCount++;
        } catch (e) {
          skippedCount++;
          print('Error importing row: $e');
        }
      }
      
      // Reload data
      await _loadData();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Importation XML terminée: $importedCount ajouté(s), $skippedCount ignoré(s)'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'import XML: $e')),
      );
    }
  }



  Future<void> _showAddDialog() async {
    final designation = TextEditingController();
    final codeArticle = TextEditingController();
    final detailPrice = TextEditingController();
    final wholesalePrice = TextEditingController();
    final unitQty = TextEditingController();
    final cartonQty = TextEditingController();
    final unitsPerCarton = TextEditingController();
    String? category = _categories.isNotEmpty ? _categories.first : null;
    bool isCarton = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final bool canSave =
              (designation.text.trim().isNotEmpty && category != null);

          return AlertDialog(
            backgroundColor: const Color(0xFFFAFAFF),
            title: const Text(
              'Ajouter un article',
              style: TextStyle(
                  color: Color(0xFF19264C), fontFamily: 'Bahnschrift'),
            ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: designation,
                    decoration:
                        const InputDecoration(labelText: 'Désignation'),
                    onChanged: (_) => setStateDialog(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeArticle,
                    decoration:
                        const InputDecoration(labelText: 'Code Article'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: category,
                          isExpanded: true,
                          hint: const Text('Catégorie'),
                          dropdownColor: const Color(0xFFFAFAFF),
                          items: _categories
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setStateDialog(() => category = value),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final newCat = await _showNewCategoryDialog();
                          if (newCat != null) {
                            await _db.addCategory(newCat);
                            await _loadData();
                            setStateDialog(() => category = newCat);
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('Unité',
                            style: TextStyle(
                                color: !isCarton
                                    ? Colors.white
                                    : const Color(0xFF19264C))),
                        selected: !isCarton,
                        selectedColor: const Color(0xFF141E46),
                        backgroundColor: const Color(0xFFFAFAFF),
                        onSelected: (_) =>
                            setStateDialog(() => isCarton = false),
                      ),
                      ChoiceChip(
                        label: Text('Carton',
                            style: TextStyle(
                                color: isCarton
                                    ? Colors.white
                                    : const Color(0xFF19264C))),
                        selected: isCarton,
                        selectedColor: const Color(0xFF141E46),
                        backgroundColor: const Color(0xFFFAFAFF),
                        onSelected: (_) =>
                            setStateDialog(() => isCarton = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailPrice,
                    decoration:
                        const InputDecoration(labelText: 'Prix détail'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: wholesalePrice,
                    decoration:
                        const InputDecoration(labelText: 'Prix gros'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  if (!isCarton)
                    TextField(
                      controller: unitQty,
                      decoration:
                          const InputDecoration(labelText: 'Quantité (unités)'),
                      keyboardType: TextInputType.number,
                    )
                  else ...[
                    TextField(
                      controller: cartonQty,
                      decoration: const InputDecoration(
                          labelText: 'Nombre de cartons'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: unitsPerCarton,
                      decoration: const InputDecoration(
                          labelText: 'Unités par carton'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: const Color(0xFFD9F4E9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Annuler',
                      style: TextStyle(
                          fontFamily: 'ZTGatha', color: Color(0xFF19264C))),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: const Color(0xFF141E46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: canSave
                    ? () async {
                        final now = DateFormat('yyyy-MM-dd HH:mm:ss')
                            .format(DateTime.now());
                        final qtyUnit = int.tryParse(unitQty.text) ?? 0;
                        final qtyCarton = int.tryParse(cartonQty.text) ?? 0;
                        final qtyPerCarton =
                            int.tryParse(unitsPerCarton.text) ?? 0;

                        final stockQty = !isCarton
                            ? qtyUnit
                            : qtyCarton * qtyPerCarton;
                        
                        await _db.addItem({
                          'item_name': designation.text.trim(),
                          'description': '',
                          'code_article': codeArticle.text.trim(),
                          'unit_price':
                              double.tryParse(detailPrice.text) ?? 0.0,
                          'stock_quantity': stockQty,
                          'quantity_char': stockQty, // Set initial loaded quantity
                          'quantity_sold': 0,
                          'category': category,
                          'pu_art_gros':
                              double.tryParse(wholesalePrice.text) ?? 0.0,
                          'nbre_colis': isCarton ? qtyCarton : 0,
                          'cond': isCarton ? qtyPerCarton : 0,
                          'created_at': now,
                          'updated_at': now,
                        });
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        await _loadData();
                      }
                    : null,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Enregistrer',
                      style: TextStyle(fontFamily: 'ZTGatha', color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _showNewCategoryDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAFAFF),
        title: const Text(
          'Nouvelle catégorie',
          style: TextStyle(
              color: Color(0xFF19264C), fontFamily: 'Bahnschrift'),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nom'),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF141E46)),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(ctx, value);
              }
            },
            child: const Text('Ajouter',
                style: TextStyle(fontFamily: 'ZTGatha')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9F4E9)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style:
                    TextStyle(fontFamily: 'ZTGatha', color: Color(0xFF19264C))),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> item) async {
    final designation =
        TextEditingController(text: item['item_name']?.toString() ?? '');
    final codeArticle =
        TextEditingController(text: item['code_article']?.toString() ?? '');
    final detailPrice = TextEditingController(
        text: (item['unit_price'] ?? 0).toString());
    final wholesalePrice = TextEditingController(
        text: (item['pu_art_gros'] ?? 0).toString());
    final unitQty = TextEditingController(
        text: (item['stock_quantity'] ?? 0).toString());
    final cartonQty =
        TextEditingController(text: (item['nbre_colis'] ?? 0).toString());
    final unitsPerCarton =
        TextEditingController(text: (item['cond'] ?? 0).toString());
    String? category = item['category'];
    bool isCarton = (item['nbre_colis'] ?? 0) > 0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFAFAFF),
            title: const Text(
              'Modifier article',
              style: TextStyle(
                  color: Color(0xFF19264C), fontFamily: 'Bahnschrift'),
            ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: designation,
                    decoration:
                        const InputDecoration(labelText: 'Désignation'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeArticle,
                    decoration:
                        const InputDecoration(labelText: 'Code Article'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: category,
                          isExpanded: true,
                          hint: const Text('Catégorie'),
                          dropdownColor: const Color(0xFFFAFAFF),
                          items: _categories
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setStateDialog(() => category = value),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final newCat = await _showNewCategoryDialog();
                          if (newCat != null) {
                            await _db.addCategory(newCat);
                            await _loadData();
                            setStateDialog(() => category = newCat);
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('Unité',
                            style: TextStyle(
                                color: !isCarton
                                    ? Colors.white
                                    : const Color(0xFF19264C))),
                        selected: !isCarton,
                        selectedColor: const Color(0xFF141E46),
                        backgroundColor: const Color(0xFFFAFAFF),
                        onSelected: (_) =>
                            setStateDialog(() => isCarton = false),
                      ),
                      ChoiceChip(
                        label: Text('Carton',
                            style: TextStyle(
                                color: isCarton
                                    ? Colors.white
                                    : const Color(0xFF19264C))),
                        selected: isCarton,
                        selectedColor: const Color(0xFF141E46),
                        backgroundColor: const Color(0xFFFAFAFF),
                        onSelected: (_) =>
                            setStateDialog(() => isCarton = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailPrice,
                    decoration:
                        const InputDecoration(labelText: 'Prix détail'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: wholesalePrice,
                    decoration:
                        const InputDecoration(labelText: 'Prix gros'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  if (!isCarton)
                    TextField(
                      controller: unitQty,
                      decoration:
                          const InputDecoration(labelText: 'Quantité'),
                      keyboardType: TextInputType.number,
                    )
                  else ...[
                    TextField(
                      controller: cartonQty,
                      decoration: const InputDecoration(
                          labelText: 'Nombre de cartons'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: unitsPerCarton,
                      decoration: const InputDecoration(
                          labelText: 'Unités par carton'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  backgroundColor: const Color(0xFFD9F4E9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Annuler',
                      style: TextStyle(fontFamily: 'ZTGatha', color: Color(0xFF19264C))),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  await _db.deleteItem(item['id_item'] as int);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  await _loadData();
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  backgroundColor: const Color(0xFF141E46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  await _db.updateItem({
                    'id_item': item['id_item'],
                    'item_name': designation.text.trim(),
                    'code_article': codeArticle.text.trim(),
                    'unit_price':
                        double.tryParse(detailPrice.text) ?? item['unit_price'],
                    'pu_art_gros': double.tryParse(wholesalePrice.text) ??
                        item['pu_art_gros'],
                    'stock_quantity': !isCarton
                        ? int.tryParse(unitQty.text) ?? item['stock_quantity']
                        : (int.tryParse(cartonQty.text) ?? 0) *
                            (int.tryParse(unitsPerCarton.text) ?? 0),
                    'nbre_colis':
                        isCarton ? int.tryParse(cartonQty.text) ?? 0 : 0,
                    'cond':
                        isCarton ? int.tryParse(unitsPerCarton.text) ?? 0 : 0,
                    'category': category,
                    'updated_at': DateTime.now().toString(),
                  });
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  await _loadData();
                },
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Enregistrer',
                      style: TextStyle(fontFamily: 'ZTGatha', color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
