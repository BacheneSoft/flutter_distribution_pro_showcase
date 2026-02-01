import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';

class BluetoothPrintHelper {
  static final BluetoothPrintHelper _instance = BluetoothPrintHelper._internal();
  factory BluetoothPrintHelper() => _instance;
  BluetoothPrintHelper._internal();

  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? _connectedDevice;

  Future<List<BluetoothDevice>> getDevices() async {
    return await bluetooth.getBondedDevices();
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (await bluetooth.isConnected ?? false) {
      if (_connectedDevice?.address == device.address) {
        return true;
      }
      await bluetooth.disconnect();
    }
    
    try {
      await bluetooth.connect(device);
      _connectedDevice = device;
      return true;
    } catch (e) {
      print("Error connecting to printer: $e");
      return false;
    }
  }

  Future<void> disconnect() async {
    await bluetooth.disconnect();
    _connectedDevice = null;
  }

  Future<bool> isConnected() async {
    return await bluetooth.isConnected ?? false;
  }

  Future<void> printSale(Map<dynamic, dynamic> vente, Map<dynamic, dynamic> clientData, List<Map<String, dynamic>> items) async {
    if (!(await isConnected())) return;

    // Header
    bluetooth.printNewLine();
    bluetooth.printCustom("Bachene Soft", 3, 1); // Size 3, Center
    bluetooth.printCustom("Bon de Vente", 2, 1);
    bluetooth.printNewLine();

    // Client info
    bluetooth.printLeftRight("Client:", "${clientData['NOMCLIENT']}", 1);
    // Removed client code
    bluetooth.printLeftRight("Date:", "${vente['sale_date'] ?? vente['dateVente'] ?? ''}", 1);
    bluetooth.printNewLine();

    // Table Header
    bluetooth.printCustom("--------------------------------", 1, 1);
    bluetooth.printLeftRight("Art. | Qte | PU", "Total", 1);
    bluetooth.printCustom("--------------------------------", 1, 1);

    // Items
    for (var item in items) {
      String name = (item['designation']?.toString() ?? 
                    item['item_name']?.toString() ?? 
                    item['DESIGNATION']?.toString() ?? 
                    item['item_designation']?.toString() ?? 
                    'N/A');
      if (name == 'null' || name.isEmpty) name = 'N/A';
      if (name.length > 20) name = name.substring(0, 17) + "...";
      
      num qty = 0;
      if (item['quantity'] != null) qty = item['quantity'] as num;
      else if (item['quantity_units'] != null) qty = item['quantity_units'] as num;
      else if (item['quantity_cartons'] != null) qty = item['quantity_cartons'] as num;
      else if (item['QUANT_LIVRE'] != null) qty = item['QUANT_LIVRE'] as num;
      else if (item['NBRE_COLIS'] != null) qty = item['NBRE_COLIS'] as num;

      double price = (item['unit_price'] as num?)?.toDouble() ?? 
                    (item['item_unit_price'] as num?)?.toDouble() ??
                    (item['price'] as num?)?.toDouble() ?? 0.0;
      double total = (item['total_price'] as num?)?.toDouble() ?? (qty.toDouble() * price);

      bluetooth.printCustom(name, 1, 0);
      bluetooth.printLeftRight("  ${qty.toString()} x ${price.toStringAsFixed(2)}", "${total.toStringAsFixed(2)}", 1);
    }

    bluetooth.printCustom("--------------------------------", 1, 1);

    // Totals
    double totalAmount = (vente['total_amount'] as num?)?.toDouble() ?? (vente['montant'] as num?)?.toDouble() ?? 0.0;
    double paymentAmount = (vente['payment_amount'] as num?)?.toDouble() ?? (vente['montantPaye'] as num?)?.toDouble() ?? 0.0;
    double remaining = totalAmount - paymentAmount;

    bluetooth.printLeftRight("TOTAL:", "${totalAmount.toStringAsFixed(2)} DA", 2);
    bluetooth.printLeftRight("Vers.:", "${paymentAmount.toStringAsFixed(2)} DA", 1);
    bluetooth.printLeftRight("Reste:", "${remaining.toStringAsFixed(2)} DA", 1);
    
    bluetooth.printNewLine();
    bluetooth.printCustom("Merci pour votre visite!", 1, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  Future<void> printReglement(Map<dynamic, dynamic> reglement, Map<dynamic, dynamic> clientData) async {
    if (!(await isConnected())) return;

    bluetooth.printNewLine();
    bluetooth.printCustom("Bachene Soft", 3, 1);
    bluetooth.printCustom("Bon de Reglement", 2, 1);
    bluetooth.printNewLine();

    bluetooth.printLeftRight("Client:", "${clientData['NOMCLIENT']}", 1);
    bluetooth.printLeftRight("Date:", "${reglement['date'] ?? ''}", 1);
    bluetooth.printNewLine();

    bluetooth.printCustom("--------------------------------", 1, 1);
    bluetooth.printLeftRight("MONTANT:", "${reglement['amount']} DA", 2);
    String method = (reglement['method'] ?? 'N/A').toString().replaceAll('espèce', 'espece');
    bluetooth.printLeftRight("Mode:", method, 1);
    if (reglement['reference'] != null && reglement['reference'].toString().isNotEmpty) {
      bluetooth.printLeftRight("Ref:", "${reglement['reference']}", 1);
    }
    bluetooth.printCustom("--------------------------------", 1, 1);

    bluetooth.printNewLine();
    bluetooth.printCustom("Merci!", 1, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }
}
