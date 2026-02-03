import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import 'pdfgen.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'database_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bluetooth_print_helper.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class VentePdfScreen extends StatefulWidget {
  final Map<String, dynamic> vente;
  final Map<dynamic, dynamic> clientData;

  const VentePdfScreen({
    Key? key,
    required this.vente,
    required this.clientData,
  }) : super(key: key);

  @override
  _VentePdfScreenState createState() => _VentePdfScreenState();
}

class _VentePdfScreenState extends State<VentePdfScreen> {
  bool _isPrintingUI = false;

  Future<void> _generateAndShareCSV(BuildContext context) async {
    List<List<dynamic>> rows = [];

    // Header
    rows.add([
      "Code Client",
      "Nom Client",
      "ID Vente",
      "Date Vente",
      "Montant Total",
      "Montant Payé",
      "Reste à Payer",
      "Statut",
      "Code Article",
      "Désignation",
      "Quantité",
      "Prix Unitaire",
      "Total Article"
    ]);

    // Client Info
    String clientCode = widget.clientData['CODECLTV']?.toString() ?? '';
    String clientName = widget.clientData['NOMCLIENT']?.toString() ?? '';

    // Sale Info
    String saleIdStr = widget.vente['idVente']?.toString() ?? 
                       widget.vente['id_sale']?.toString() ?? '';
    int? sId = int.tryParse(saleIdStr);
    
    String dateVente = widget.vente['dateVente']?.toString() ?? widget.vente['sale_date']?.toString() ?? '';
    double totalAmount = (widget.vente['montant'] as num?)?.toDouble() ?? 
                         (widget.vente['total_amount'] as num?)?.toDouble() ?? 0.0;
    double montantPaye = (widget.vente['montantPaye'] as num?)?.toDouble() ?? 
                         (widget.vente['payment_amount'] as num?)?.toDouble() ?? 0.0;
    double resteAPayer = totalAmount - montantPaye;
    String status = (widget.vente['valide'] == true || widget.vente['payment_status'] == 'paid') ? "Payé" : "Non Payé";

    // Items
    List<dynamic> items = widget.vente['items'] ?? widget.vente['selectedItems'] ?? [];
    if (items.isEmpty && sId != null && sId > 0) {
       final db = DatabaseHelper();
       try {
          items = await db.getSaleItems(sId);
       } catch (e) {
          print("Error fetching items for CSV: $e");
       }
    }

    if (items.isEmpty) {
      rows.add([
        clientCode,
        clientName,
        saleIdStr,
        dateVente,
        totalAmount,
        montantPaye,
        resteAPayer,
        status,
        "", "", "", "", ""
      ]);
    } else {
      for (var item in items) {
         String itemCode = item['COD_ARTICLE']?.toString() ?? item['code_article']?.toString() ?? item['id_item']?.toString() ?? '';
         String itemName = item['designation']?.toString() ?? item['item_name']?.toString() ?? item['DESIGNATION']?.toString() ?? '';
         
         int quantity = 0;
         if (item['quantity'] != null) quantity = item['quantity'] as int;
         else if (item['QUANT_LIVRE'] != null) quantity = item['QUANT_LIVRE'] as int;
         else if (item['NBRE_COLIS'] != null) quantity = item['NBRE_COLIS'] as int;

         double unitPrice = (item['unit_price'] as num?)?.toDouble() ?? (item['price'] as num?)?.toDouble() ?? 0.0;
         double itemTotal = (item['total_price'] as num?)?.toDouble() ?? (quantity * unitPrice);

         rows.add([
          clientCode,
          clientName,
          saleIdStr, // Use saleIdStr here, not sId
          dateVente,
          totalAmount,
          montantPaye,
          resteAPayer,
          status,
          itemCode,
          itemName,
          quantity,
          unitPrice,
          itemTotal
        ]);
      }
    }

    String csvData = const ListToCsvConverter().convert(rows);
    
    try {
      // 1. Try to save to Downloads folder
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
           final path = "${directory.path}/vente_${sId ?? 'temp'}_${DateTime.now().millisecondsSinceEpoch}.csv";
           final file = File(path);
           await file.writeAsString(csvData);
           
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text('Fichier sauvegardé dans: $path'),
             duration: const Duration(seconds: 5),
           ));
           return; // Exit if saved successfully
        }
      }

      // 2. Fallback to Share if permission denied or not Android
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/vente_${sId ?? 'temp'}_${DateTime.now().millisecondsSinceEpoch}.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(path)], text: 'Vente CSV');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de l\'export CSV: $e'),
        ));
      }
    }
  }

  void _handleDirectPrint(BuildContext context) async {
    if (_isPrintingUI) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impression en cours...')),
      );
      return;
    }

    final BluetoothPrintHelper printHelper = BluetoothPrintHelper();
    bool connected = await printHelper.isConnected();
    
    if (!connected) {
      List<BluetoothDevice> devices = await printHelper.getDevices();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Choisir une imprimante'),
          content: devices.isEmpty
              ? Text('Aucun appareil Bluetooth appairé trouvé.')
              : Container(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(devices[index].name ?? 'Inconnu'),
                        subtitle: Text(devices[index].address ?? ''),
                        onTap: () async {
                          Navigator.pop(context);
                          setState(() => _isPrintingUI = true);
                          try {
                            bool result = await printHelper.connect(devices[index]);
                            if (result) {
                              await _doPrint(context, printHelper);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Échec de la connexion.')),
                              );
                            }
                          } finally {
                            setState(() => _isPrintingUI = false);
                          }
                        },
                      );
                    },
                  ),
                ),
        ),
      );
    } else {
      setState(() => _isPrintingUI = true);
      try {
        await _doPrint(context, printHelper);
      } finally {
        setState(() => _isPrintingUI = false);
      }
    }
  }

  Future<void> _doPrint(BuildContext context, BluetoothPrintHelper printHelper) async {
    try {
      int saleId = int.tryParse(widget.vente['idVente']?.toString() ?? 
                            widget.vente['id_sale']?.toString() ?? '0') ?? 0;
      List<Map<String, dynamic>> items = [];
      if (saleId > 0) {
        items = await DatabaseHelper().getSaleItems(saleId);
      }
      // Fallback to internal items if database returned nothing
      if (items.isEmpty) {
        if (widget.vente['items'] != null) {
          items = List<Map<String, dynamic>>.from(widget.vente['items'] as List);
        } else if (widget.vente['selectedItems'] != null) {
          items = List<Map<String, dynamic>>.from(widget.vente['selectedItems'] as List);
        }
      }
      await printHelper.printSale(widget.vente, widget.clientData, items);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'impression: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aperçu PDF'),
        backgroundColor: const Color(0xFF141E46),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        allowPrinting: false,
        build: (format) => generateVentePdfData(format, widget.vente),
        pageFormats: const {
          'A4': PdfPageFormat.a4,
          'A5': PdfPageFormat.a5,
          'Ticket 58mm': PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm),
          'Ticket 80mm': PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        },
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.print),
            onPressed: _isPrintingUI ? null : (context, build, pageFormat) => _handleDirectPrint(context),
          ),
          PdfPreviewAction(
            icon: const Icon(Icons.file_download),
            onPressed: (context, build, pageFormat) => _generateAndShareCSV(context),
          ),
        ],
      ),
    );
  }
}

