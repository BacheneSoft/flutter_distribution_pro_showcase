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

class ReglementPdfScreen extends StatefulWidget {
  final Map<String, dynamic> reglement;
  final Map<dynamic, dynamic> clientData;

  const ReglementPdfScreen({
    Key? key,
    required this.reglement,
    required this.clientData,
  }) : super(key: key);

  @override
  _ReglementPdfScreenState createState() => _ReglementPdfScreenState();
}

class _ReglementPdfScreenState extends State<ReglementPdfScreen> {
  bool _isPrintingUI = false;

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
      if (!mounted) return;
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
                            if (mounted) setState(() => _isPrintingUI = false);
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
        if (mounted) setState(() => _isPrintingUI = false);
      }
    }
  }

  Future<void> _doPrint(BuildContext context, BluetoothPrintHelper printHelper) async {
    try {
      await printHelper.printReglement(widget.reglement, widget.clientData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'impression: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aperçu PDF Règlement'),
        backgroundColor: const Color(0xFF141E46),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => generateReglementPdfData(format, widget.reglement),
        pageFormats: const {
          'A4': PdfPageFormat.a4,
          'A5': PdfPageFormat.a5,
          'Ticket 58mm': PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm),
        },
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.print),
            onPressed: _isPrintingUI ? null : (context, build, pageFormat) => _handleDirectPrint(context),
          ),
        ],
      ),
    );
  }
}

