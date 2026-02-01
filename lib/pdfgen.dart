/// lib/pdfgen.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'database_helper.dart';

Future<void> generateDechargePDF(Map<String, dynamic> decharge) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Bon de Décharge',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Date: ${decharge['dateDecharge']}'),
            pw.SizedBox(height: 10),
            // Loop through each depot in the decharge details.
            ...List<pw.Widget>.from(
              (decharge['depots'] as List<dynamic>).map((depot) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Depot: ${depot['depotName']}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Table.fromTextArray(
                      headers: [
                        'Article',
                        'Quantité Déchargée',
                        'Prix Unitaire',
                        'Total'
                      ],
                      data: List<List<String>>.from(
                        (depot['items'] as List<dynamic>).map((item) {
                          // Calculate total, for example as quantity * unit price.
                          num quantity = item['QTE_DECHARGE'] is num
                              ? item['QTE_DECHARGE']
                              : 0;
                          double tva = (item['TVA'] as num).toDouble();
                          num price =
                              item['PU_ART'] is num ? item['PU_ART'] : 0;
                          price = price * (1.0 + (tva / 100.0));
                          num total = quantity * price;

                          return [
                            item['DESIGNATION'].toString(),
                            quantity.toString(),
                            price.toStringAsFixed(2),
                            total.toStringAsFixed(2),
                          ];
                        }),
                      ),
                    ),
                    pw.SizedBox(height: 20),
                  ],
                );
              }),
            ),
          ],
        );
      },
    ),
  );

  // Open the PDF preview (or allow printing/sharing).
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
  );
}

Future<void> generateReglementPDF(Map<String, dynamic> reglement) async {
  await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => generateReglementPdfData(format, reglement));
}

Future<Uint8List> generateReglementPdfData(PdfPageFormat format, Map<String, dynamic> reglement) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      pageFormat: format,
      build: (context) {
        return pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Bon de Règlement',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Date: ${reglement['date'] ?? 'N/A'}'),
              pw.Text('Montant: ${reglement['amount']} DA'),
              pw.Text('Mode de Paiement: ${(reglement['method'] ?? 'N/A').toString().replaceAll('espèce', 'espece')}'),
              if (reglement['reference'] != null && reglement['reference'].toString().isNotEmpty)
                pw.Text('Reference: ${reglement['reference']}'),
            ],
          ),
        );
      },
    ),
  );

  return pdf.save();
}

Future<Uint8List> generateVentePdfData(PdfPageFormat format, Map<String, dynamic> vente) async {
  final pdf = pw.Document();

  // Compute remaining amount
  num total = (vente['montant'] as num?)?.toDouble() ?? 0.0;
  num montantPaye = (vente['montantPaye'] as num?)?.toDouble() ?? 0.0;
  num resteAPayer = total - montantPaye;

  // Get sale ID to fetch items
  int? saleId = int.tryParse(vente['idVente']?.toString() ?? '') ?? 
                int.tryParse(vente['id_sale']?.toString() ?? '') ??
                (vente['id_sale'] is int ? vente['id_sale'] as int : null);
  
  // Fetch items from database if not already in vente
  List<Map<String, dynamic>> items = [];
  if (saleId != null && saleId > 0) {
    try {
      items = await DatabaseHelper().getSaleItems(saleId);
    } catch (e) {
      print('Error fetching sale items: $e');
    }
  }
  
  // Fallback to items in vente if available
  if (items.isEmpty) {
    if (vente['items'] != null) {
      items = List<Map<String, dynamic>>.from(vente['items'] as List);
    } else if (vente['selectedItems'] != null) {
      items = List<Map<String, dynamic>>.from(vente['selectedItems'] as List);
    }
  }

  pdf.addPage(
    pw.Page(
      pageFormat: format,
      build: (context) {
        return pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Bon de Vente',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Date: ${vente['dateVente'] ?? vente['sale_date'] ?? 'N/A'}'),
              pw.SizedBox(height: 10),
              pw.Text('Total: ${total.toStringAsFixed(2)} DA'),
              pw.Text('Montant payé: ${montantPaye.toStringAsFixed(2)} DA'),
              pw.Text('Reste à payer: ${resteAPayer.toStringAsFixed(2)} DA'),
              pw.SizedBox(height: 20),
              if (items.isNotEmpty) ...[
                pw.Text('Articles:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  data: <List<String>>[
                    // Table headers
                    <String>[
                      'Article',
                      'Quantité',
                      'Prix Unitaire',
                      'Total'
                    ],
                    ...List<List<String>>.from(
                      items.map((item) {
                        String itemName = (item['designation']?.toString() ?? 
                                         item['item_name']?.toString() ?? 
                                         item['DESIGNATION']?.toString() ?? 
                                         'N/A');
                        if (itemName == 'null' || itemName.isEmpty) itemName = 'N/A';
                        num quantity = 0;
                        if (item['quantity'] != null) quantity = item['quantity'] as num;
                        else if (item['quantity_units'] != null) quantity = item['quantity_units'] as num;
                        else if (item['quantity_cartons'] != null) quantity = item['quantity_cartons'] as num;
                        else if (item['QUANT_LIVRE'] != null) quantity = item['QUANT_LIVRE'] as num;
                        else if (item['NBRE_COLIS'] != null) quantity = item['NBRE_COLIS'] as num;
                        
                        double unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 
                                          (item['item_unit_price'] as num?)?.toDouble() ??
                                          (item['price'] as num?)?.toDouble() ?? 0.0;
                        double itemTotal = (item['total_price'] as num?)?.toDouble() ?? 
                                          (unitPrice * quantity.toDouble());
                        
                        return [
                          itemName,
                          quantity.toString(),
                          unitPrice.toStringAsFixed(2),
                          itemTotal.toStringAsFixed(2),
                        ];
                      }),
                    ),
                  ],
                ),
              ] else ...[
                pw.Text('Aucun article trouvé', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
              ],
            ],
          ),
        );
      },
    ),
  );

  return pdf.save();
}

Future<void> generateStockPDF(List<Map<String, dynamic>> items) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Liste du Stock', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Désignation', 'Catégorie', 'Code', 'Stock (Unités)'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            data: items.map((item) {
              return [
                item['item_name']?.toString() ?? 'N/A',
                item['category']?.toString() ?? 'N/A',
                item['code_article']?.toString() ?? 'N/A',
                item['stock_quantity']?.toString() ?? '0',
              ];
            }).toList(),
          ),
        ];
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
    name: 'stock_report.pdf',
  );
}
