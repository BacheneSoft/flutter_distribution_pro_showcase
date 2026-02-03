/// lib/userscreen_sells.dart
import 'package:file_picker/file_picker.dart';
import 'database_helper.dart';
import 'pdfgen.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'allowed_users.dart';
import 'vente_pdf_screen.dart';
import 'reglement_pdf_screen.dart';
import 'dart:io';

import 'AddVenteScreen.dart';
import 'bluetooth_print_helper.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
//import 'sold_screen.dart';


String? selectedDepotId;
List<Map<String, dynamic>> selectedDepotMarchandises = [];
List<Map<String, dynamic>> depots = [];

// Variables to hold our subscriptions so we can cancel them
// StreamSubscription<DatabaseEvent>? clientSubscription;
// StreamSubscription<DatabaseEvent>? ventesSubscription;
// StreamSubscription<DatabaseEvent>? versementsSubscription;

//late StreamSubscription<List<ConnectivityResult>> connectivitySubscription;

class ClientDetailsScreen extends StatefulWidget {
  final String clientId;
  final String clientName;

  ClientDetailsScreen({required this.clientId, required this.clientName});

  @override
  _ClientDetailsScreenState createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  Map<dynamic, dynamic> clientData = {}; // Initialize as an empty map
  List<Map<dynamic, dynamic>> ventesList = [];
  List<Map<dynamic, dynamic>> versementsList = [];
  String? vanId;
  double tva = 0.0;

  // control items per page
  final List<int?> ventesOptions = [25, 50, 100, null]; // null = "All"
  int? selectedVentesLimit = 25;

  final TextEditingController _venteMontantController = TextEditingController();

  // isValide: Controls whether the vente is "validated" (paid) or "non-validated" (pending payment)
  // - Valide (true): Payment is complete, sale is marked as 'paid', montant payé field is shown
  // - Non Valide (false): Payment is pending, sale is marked as 'pending', montant payé is set to 0
  bool isValide = false;

  // Add these with existing state variables
  List<Map<String, dynamic>> selectedItems = [];
  double totalAmount = 0.0;
  String? selectedPriceType = 'detail'; // 'détail' or 'gros'
  double _oldResteAPayer = 0.0;
  bool _oldIsValide = false;
  double _oldTotalAmount = 0.0;
  double _oldMontantPaye = 0.0;

  // offline
  bool isOffline = false;
  
  // Toggle between ventes and reglements view
  bool showReglements = false;

  bool _isPrintingUI = false;

  @override
  void initState() {
    super.initState();
    _loadVanId();
  }

  final BluetoothPrintHelper _printHelper = BluetoothPrintHelper();

  void _showPrinterSelectionDialog(Function(BluetoothDevice) onSelected) async {
    List<BluetoothDevice> devices = await _printHelper.getDevices();
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
                      onTap: () {
                        Navigator.pop(context);
                        onSelected(devices[index]);
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
        ],
      ),
    );
  }

  void _handleDirectPrint(Map<dynamic, dynamic> data, bool isSale) async {
    if (_isPrintingUI) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impression en cours...')),
      );
      return;
    }

    bool connected = await _printHelper.isConnected();
    if (!connected) {
      _showPrinterSelectionDialog((device) async {
        setState(() => _isPrintingUI = true);
        try {
          bool result = await _printHelper.connect(device);
          if (result) {
            await _doPrint(data, isSale);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Échec de la connexion à l\'imprimante.')),
            );
          }
        } finally {
          setState(() => _isPrintingUI = false);
        }
      });
    } else {
      setState(() => _isPrintingUI = true);
      try {
        await _doPrint(data, isSale);
      } finally {
        setState(() => _isPrintingUI = false);
      }
    }
  }

  Future<void> _doPrint(Map<dynamic, dynamic> data, bool isSale) async {
    try {
      if (isSale) {
        int saleId = int.tryParse(data['idVente']?.toString() ?? 
                              data['id_sale']?.toString() ?? '0') ?? 0;
        List<Map<String, dynamic>> items = [];
        if (saleId > 0) {
          items = await DatabaseHelper().getSaleItems(saleId);
        }
        await _printHelper.printSale(data, clientData, items);
      } else {
        await _printHelper.printReglement(data, clientData);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'impression: $e')),
      );
    }
  }

  Future<void> _loadVanId() async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      vanId = prefs.getString('userId');
      tva = prefs.getDouble('global_tva') ?? 0.0;
    });
    _loadDepots();
    _fetchClientDetails();
  }

  @override
  void dispose() {
    // clientSubscription?.cancel();
    // ventesSubscription?.cancel();
    // versementsSubscription?.cancel();
    // connectivitySubscription?.cancel();
    super.dispose();
  }

  // void _updateOffline(ConnectivityResult result) {
  //   setState(() => isOffline = (result == ConnectivityResult.none));
  // }

  Future<void> _loadDepots() async {
    // Assuming we can get vanId from SharedPreferences or passed down
    // For now, let's assume we have the vanId (userId in this context might need mapping to vanId)
    // But DatabaseHelper.getDepots takes vanId (int).
    // We need to get the actual van ID from the database using the username (vanId string variable).

    if (vanId == null) return;

    final db = DatabaseHelper();
    final users = await db.getUsers();
    final user = users.firstWhere((u) => u['nom'] == vanId, orElse: () => {});

    if (user.isNotEmpty) {
      final van = await db.getVanByUserId(user['id_user']);
      if (van != null) {
        List<Map<String, dynamic>> depotList =
            await db.getDepots(van['id_van']);

        // We also need to fetch items for the first depot if selected
        if (depotList.isNotEmpty) {
          setState(() {
            depots = depotList;
            selectedDepotId = depotList[0]['id_depot'].toString();
          });
          _loadDepotItems(depotList[0]['id_depot']);
        } else {
          setState(() {
            depots = [];
          });
        }
      }
    }
  }

  Future<void> _loadDepotItems(int depotId) async {
    final db = DatabaseHelper();
    List<Map<String, dynamic>> items = await db.getDepotItems(depotId);
    setState(() {
      selectedDepotMarchandises = items;
    });
  }

  // Fetch client details, ventes, and versements for the logged-in van
  Future<void> _fetchClientDetails() async {
    final db = DatabaseHelper();
    final cId = int.tryParse(widget.clientId) ?? 0;
    final client = await db.getClient(cId);

    if (client != null) {
      final mutableClient = Map<String, dynamic>.from(client);
      final solde = (mutableClient['solde'] as num?)?.toDouble() ?? 0.0;
      final ca = (mutableClient['ca'] as num?)?.toDouble() ?? 0.0;
      final vers = (mutableClient['vers'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        clientData = mutableClient
          ..['SOLDEINI'] = solde
          ..['CA'] = ca
          ..['VERS'] = vers
          ..['NOMCLIENT'] =
              mutableClient['NOMCLIENT'] ?? mutableClient['nom'] ?? ''
          ..['CODECLTV'] = mutableClient['CODECLTV'] ??
              mutableClient['code'] ??
              mutableClient['id_client']?.toString() ??
              widget.clientId
          ..['ADRESSE'] =
              mutableClient['ADRESSE'] ?? mutableClient['commune'] ?? ''
          ..['EMAIL'] =
              mutableClient['EMAIL'] ?? mutableClient['email'] ?? 'N/A'
          ..['TEL'] = mutableClient['TEL'] ?? mutableClient['tel'] ?? ''
          ..['type_client'] = mutableClient['type_client'] ??
              mutableClient['TYPE_CLIENT'] ??
              'Detail';
      });
    }

    _subscribeVentes();
    _subscribeVersements();
  }

  Future<void> _subscribeVentes() async {
    final db = DatabaseHelper();
    int cId = int.tryParse(widget.clientId) ?? 0;
    List<Map<String, dynamic>> sales = await db.getSalesForClient(cId);
    
    // Apply limit if selected (null means show all)
    if (selectedVentesLimit != null) {
      sales = sales.take(selectedVentesLimit!).toList();
    }
    
    // Map database fields to UI expected fields
    setState(() {
      ventesList = sales.map((sale) {
        double totalAmount = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
        double paymentAmount = (sale['payment_amount'] as num?)?.toDouble() ?? 0.0;
        double remaining = totalAmount - paymentAmount;
        bool isPaid = sale['payment_status'] == 'paid';
        
        return {
          'idVente': sale['id_sale']?.toString() ?? '',
          'montant': totalAmount,
          'dateVente': sale['sale_date'] ?? '',
          'valide': isPaid,
          'montantPaye': paymentAmount, // Use actual payment amount from database
          'resteAPayer': remaining, // Calculate remaining amount
          ...sale, // Include all original fields
        };
      }).toList();
    });
  }

  Future<void> _subscribeVersements() async {
    final db = DatabaseHelper();
    int cId = int.tryParse(widget.clientId) ?? 0;
    List<Map<String, dynamic>> payments = await db.getPaymentsForClient(cId);
    setState(() {
      versementsList = payments;
    });
  }

  Future<void> _updateDepotQuantities() async {
    // This is now handled by DatabaseHelper.addSale mostly,
    // or we can implement a specific method if needed.
    // For now, we'll assume addSale updates the stock.
  }

  void _addVente(BuildContext dialogContext, bool isValide) async {
    String montantPayeStr = _venteMontantController.text.trim();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Veuillez ajouter au moins un article'),
      ));
      return;
    }

    double montantPaye = double.tryParse(montantPayeStr) ?? 0.0;
    double remaining = totalAmount - montantPaye;

    if (remaining < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Le montant payé ne peut pas dépasser le total.'),
        ),
      );
      return;
    }

    // Fetch the client type.
    String clientType = await _getClientType();

    // String newVenteKey = "vente_${DateTime.now().millisecondsSinceEpoch}";
    Map<String, dynamic> venteData = {
      // 'idVente': newVenteKey, // Auto-incremented in SQLite
      'sale_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      // payment_status: 'paid' if isValide=true (client paid), 'pending' if isValide=false (payment pending)
      'payment_status': isValide ? 'paid' : 'pending',
      'id_client': int.tryParse(widget.clientId),
      // 'depotId': selectedDepotId, // Store if needed in sold table or linked
      // Iterate over each selected item and build its sale data.
      'total_amount': totalAmount,
      'payment_amount': montantPaye,
      // 'resteAPayer': remaining,
    };

    List<Map<String, dynamic>> saleItems = selectedItems.map((item) {
      double price =
          (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0;

      double priceWithTva = price * (1.0 + (tva / 100.0));
      priceWithTva = double.parse(priceWithTva.toStringAsFixed(2));

      int qty = 0;
      int? itemId = int.tryParse(item['id_item']?.toString() ?? '');
      int? quantityUnits;
      int? quantityCartons;
      
      if (item.containsKey('QUANT_LIVRE')) {
        qty = item['QUANT_LIVRE'] as int? ?? 0;
        quantityUnits = qty;
      } else if (item.containsKey('NBRE_COLIS')) {
        qty = item['NBRE_COLIS'] as int? ?? 0;
        quantityCartons = qty;
      }

      return {
        'id_item': itemId ?? 0,
        'quantity': qty,
        'unit_price': priceWithTva,
        'total_price': priceWithTva * qty,
        'quantity_units': quantityUnits,
        'quantity_cartons': quantityCartons,
      };
    }).toList();

    // Fetch current values from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double currentEncaissement = prefs.getDouble('total_encaissement') ?? 0.0;
    double currentChiffreAffaire =
        prefs.getDouble('total_chiffre_affaire') ?? 0.0;
    // update the values
    currentEncaissement += montantPaye;
    currentChiffreAffaire += totalAmount;

    // Save back to SharedPreferences
    await prefs.setDouble('total_encaissement', currentEncaissement);
    await prefs.setDouble('total_chiffre_affaire', currentChiffreAffaire);

    // Save to Local DB
    final db = DatabaseHelper();
    await db.addSale(venteData, saleItems);

    // Retrieve the current CA value.
    double currentCa = 0.0;
    if (clientData['CA'] != null) {
      currentCa = double.tryParse(clientData['CA'].toString()) ?? 0.0;
    }
    // Always add the amount to CA
    double newCa = currentCa + totalAmount;

    // Retrieve the current VERS value.
    double currentVers = 0.0;
    if (clientData['VERS'] != null) {
      currentVers = double.tryParse(clientData['VERS'].toString()) ?? 0.0;
    }
    // Always add the amount to VERS
    double newVers = currentVers + montantPaye;

    // Update Client Financials
    await db.updateClientFinancials(int.parse(widget.clientId),
        ca: newCa, vers: newVers);

    // Update solde (credit): 
    // - Client owes the remaining part (total - paid)
    if (remaining > 0) {
      _updateClientSolde(remaining, isVente: true);
    }

    // Refresh UI
    setState(() {
      clientData['VERS'] = newVers;
      clientData['CA'] = newCa;
    });

    _subscribeVentes(); // Refresh list
    
    // Reload items to show updated quantities
    await _loadItemsForVente();

    Navigator.of(dialogContext).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Vente Added Successfully (Local)'),
    ));
  }

  void _updateClientSolde(double amount, {required bool isVente}) async {
    // Credit (solde) calculation:
    // - Credit = SOLDEINI in the database
    // - When adding a vente:
    //   * Non valide: full totalAmount is added to credit (client owes full amount)
    //   * Valide with partial payment: remaining amount (totalAmount - montantPaye) is added to credit
    //   * Valide with full payment: nothing added to credit (client paid in full)
    // - When adding a payment (reglement): amount is subtracted from credit
    // - Credit represents the total amount the client owes
    
    // Retrieve the current solde.
    double currentSolde = 0.0;
    if (clientData['SOLDEINI'] != null) {
      currentSolde = double.tryParse(clientData['SOLDEINI'].toString()) ?? 0.0;
    }
    // For a vente update, add the amount (if negative, it subtracts).
    double newSolde =
        isVente ? (currentSolde + amount) : (currentSolde - amount);
    
    // Round to 2 decimal places to avoid floating point precision issues
    newSolde = double.parse(newSolde.toStringAsFixed(2));

    final db = DatabaseHelper();
    await db.updateClientFinancials(int.parse(widget.clientId),
        solde: newSolde);

    setState(() {
      clientData['SOLDEINI'] = newSolde;
    });
  }

  // A read-only table widget displaying the selected items.
  Widget _buildReadOnlyItemTable() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(
              label: Text(
                "Produit",
                style: TextStyle(
                  fontFamily: 'ZTGatha',
                  color: Color(0xFF19264C),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Quantité vendue",
                style: TextStyle(
                  fontFamily: 'ZTGatha',
                  color: Color(0xFF19264C),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Mode",
                style: TextStyle(
                  fontFamily: 'ZTGatha',
                  color: Color(0xFF19264C),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Total",
                style: TextStyle(
                  fontFamily: 'ZTGatha',
                  color: Color(0xFF19264C),
                ),
              ),
            ),
          ],
          rows: selectedItems.map((item) {
            String designation = item['DESIGNATION'].toString();
            int qty = 0;
            String mode = "";
            // Check which mode was used based on the saved key.
            if (item.containsKey('NBRE_COLIS') && item['NBRE_COLIS'] != null) {
              qty = item['NBRE_COLIS'] is int ? item['NBRE_COLIS'] as int : 0;
              mode = "Carton";
            } else {
              qty = item['QUANT_LIVRE'] is int ? item['QUANT_LIVRE'] as int : 0;
              mode = "Unité";
            }
            double price =
                item['price'] is num ? (item['price'] as num).toDouble() : 0.0;
            double subtotal = qty * price;
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    designation,
                    style: const TextStyle(
                      fontFamily: 'ZTGatha',
                      color: Color(0xFF19264C),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    qty.toString(),
                    style: const TextStyle(
                      fontFamily: 'ZTGatha',
                      color: Color(0xFF19264C),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    mode,
                    style: const TextStyle(
                      fontFamily: 'ZTGatha',
                      color: Color(0xFF19264C),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    subtotal.toStringAsFixed(2),
                    style: const TextStyle(
                      fontFamily: 'ZTGatha',
                      color: Color(0xFF19264C),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showEditVenteDialog(Map<dynamic, dynamic> vente) async {
    // Pre-fill vente fields.
    isValide = vente['valide'] ?? false;
    
    // Get the actual montant from the vente (total_amount from database)
    double venteMontant = (vente['montant'] as num?)?.toDouble() ?? 
                         (vente['total_amount'] as num?)?.toDouble() ?? 0.0;
    
    // Get the actual payment amount from database (payment_amount field)
    double actualPaymentAmount = (vente['payment_amount'] as num?)?.toDouble() ?? 
                                 (vente['montantPaye'] as num?)?.toDouble() ?? 0.0;
    
    // Store old values for solde calculation
    _oldIsValide = isValide;
    _oldTotalAmount = venteMontant;
    _oldMontantPaye = actualPaymentAmount;
    
    // Set montantPaye - show the actual amount paid from database
    _venteMontantController.text = actualPaymentAmount.toStringAsFixed(2);

    // Calculate old resteAPayer: total - montantPaye
    _oldResteAPayer = _oldTotalAmount - _oldMontantPaye;

    // Fetch sale items from database
    final db = DatabaseHelper();
    int saleId = int.tryParse(vente['idVente']?.toString() ?? 
                              vente['id_sale']?.toString() ?? '0') ?? 0;
    
    List<Map<String, dynamic>> dbItems = [];
    if (saleId > 0) {
      dbItems = await db.getSaleItems(saleId);
    }

    // Convert database items to UI format
    selectedItems = dbItems.map((item) {
      // Retrieve values from the database
      int quantity = (item['quantity'] as int?) ?? 0;
      int quantityUnits = (item['quantity_units'] as int?) ?? 0;
      int quantityCartons = (item['quantity_cartons'] as int?) ?? 0;
      double unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      
      // Determine if we should show as Cartons or Units
      // If cartons were saved, prioritize showing that.
      int? displayCartons;
      int displayUnits = 0;
      
      if (quantityCartons > 0) {
        displayCartons = quantityCartons;
      } else {
        // Fallback or explicit units
        displayUnits = quantityUnits > 0 ? quantityUnits : quantity;
      }

      return {
        'COD_ARTICLE': item['id_item']?.toString() ?? '',
        'DESIGNATION': item['item_name'] ?? '',
        'price': unitPrice,
        'QUANT_LIVRE': displayUnits,
        'NBRE_COLIS': displayCartons,
      };
    }).toList();

    // Use the actual vente montant instead of recalculating
    totalAmount = venteMontant;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, localSetState) {
            return AlertDialog(
              backgroundColor: Color(0xFFFAFAFF),
              title: Text(
                'Modifier Vente',
                style: TextStyle(
                  color: Color(0xFF19264C),
                  fontFamily: 'Bahnschrift',
                ),
              ),
              content: Container(
                width: 400,
                height: MediaQuery.of(context).size.height * 0.6,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      // Read-only table of selected items.
                      _buildReadOnlyItemTable(),
                      const SizedBox(height: 20),
                      // Validé Checkbox.
                      Row(
                        children: [
                          const Text(
                            'Validé: ',
                            style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF19264C),
                                fontFamily: 'ZTGatha'),
                          ),
                          Checkbox(
                            value: isValide,
                            activeColor: Colors.green,
                            onChanged: (bool? value) {
                              localSetState(() {
                                isValide = value ?? false;
                                // If vente is not valid, clear the montant field.
                                if (!isValide) {
                                  _venteMontantController.text = "0";
                                }
                              });
                            },
                          ),
                          Text(
                            isValide ? 'Valide' : 'Non Valide',
                            style: TextStyle(
                              fontSize: 16,
                              color: isValide ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'ZTGatha',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Display Montant payé Field.
                      TextField(
                          controller: _venteMontantController,
                          decoration: InputDecoration(
                            labelText: 'Montant payé (da)',
                            labelStyle: const TextStyle(
                                color: Color(0xFF19264C),
                                fontFamily: 'ZTGatha'),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                                  const BorderSide(color: Color(0xFF19264C)),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                                  const BorderSide(color: Color(0xFFB0ACFD)),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      const SizedBox(height: 10),
                      // Total Amount Display.
                      Text(
                        'Total: ${totalAmount.toStringAsFixed(2)} da',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF19264C),
                            fontFamily: 'ZTGatha'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141E46),
                  ),
                  onPressed: () {
                    _updateVente(context, vente['idVente']);
                  },
                  child: const Text(
                    'Modifier',
                    style: TextStyle(fontFamily: 'ZTGatha'),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD9F4E9),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Annuler',
                    style: TextStyle(
                        fontFamily: 'ZTGatha', color: Color(0xFF19264C)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateVente(BuildContext dialogContext, String venteId) async {
    String montantPayeStr = _venteMontantController.text.trim();
    double montantPaye = double.tryParse(montantPayeStr) ?? 0.0;
    double remaining = totalAmount - montantPaye;
    
    if (remaining < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Le montant payé ne peut pas dépasser le total.')),
      );
      return;
    }

    // Calculate solde difference:
    // Old credit = old total - old paid
    // New credit = new total - new paid
    double oldCredit = _oldTotalAmount - _oldMontantPaye;
    double newCredit = totalAmount - montantPaye;

    // Calculate the difference in credit
    double soldeDiff = newCredit - oldCredit;

    // Update SharedPreferences encaissement (adjust by payment difference)
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double currentEncaissement = prefs.getDouble('total_encaissement') ?? 0.0;
    double encaissementDiff = montantPaye - _oldMontantPaye;
    currentEncaissement += encaissementDiff;
    await prefs.setDouble('total_encaissement', currentEncaissement);

    // Update VERS (total payments): adjust by payment difference
    double currentVers = 0.0;
    if (clientData['VERS'] != null) {
      currentVers = double.tryParse(clientData['VERS'].toString()) ?? 0.0;
    }
    double newVers = currentVers + encaissementDiff;

    final db = DatabaseHelper();
    final database = await db.database;
    
    // Update the sale payment_status and payment_amount in database
    int saleIdInt = int.tryParse(venteId) ?? 0;
    if (saleIdInt > 0) {
      await database.update('sold', {
        'payment_status': isValide ? 'paid' : 'pending',
        'payment_amount': montantPaye,
      }, where: 'id_sale = ?', whereArgs: [saleIdInt]);
    }

    // Update client financials
    await db.updateClientFinancials(int.parse(widget.clientId), vers: newVers);
    
    // Update solde (credit) by the difference
    if (soldeDiff != 0) {
      _updateClientSolde(soldeDiff.abs(), isVente: soldeDiff > 0);
    }

    setState(() {
      clientData['VERS'] = newVers;
    });

    // Refresh ventes list
    _subscribeVentes();

    Navigator.of(dialogContext).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Vente Updated Successfully (Local)'),
    ));
  }

  void _showAddReglementDialog() {
    final TextEditingController _montantController = TextEditingController();
    final TextEditingController _libelleController = TextEditingController();
    final TextEditingController _referenceController = TextEditingController();
    // Local variable for payment mode (default to "espèce").
    String paymentMode = 'espece'; // or "carte"

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, localSetState) {
            return AlertDialog(
              backgroundColor: Color(0xFFFAFAFF),
              title: Text(
                'Règlement',
                style: TextStyle(
                  color: Color(0xFF19264C),
                  fontFamily: 'Bahnschrift',
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Montant field.
                    TextField(
                      controller: _montantController,
                      decoration: InputDecoration(
                        labelText: 'Montant',
                        labelStyle: const TextStyle(
                          fontFamily: 'ZTGatha',
                          color: Color(0xFF19264C),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Color(0xFF19264C)),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Color(0xFFB0ACFD)),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 10),
                    // Payment mode dropdown.
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFFFAFAFF),
                      isExpanded: true,
                      value: paymentMode,
                      items: [
                        DropdownMenuItem(
                          value: 'espece',
                          child: Text(
                            'Espèce',
                            style: const TextStyle(
                              fontFamily: 'ZTGatha',
                              color: Color(0xFF19264C),
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'carte',
                          child: Text(
                            'Carte',
                            style: const TextStyle(
                              fontFamily: 'ZTGatha',
                              color: Color(0xFF19264C),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        localSetState(() {
                          paymentMode = value ?? 'espece';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Mode de Paiement',
                        labelStyle: const TextStyle(
                          fontFamily: 'ZTGatha',
                          color: Color(0xFF19264C),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Color(0xFF19264C)),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Color(0xFFB0ACFD)),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                    ),

                    SizedBox(height: 10),
                    // Libellé field.
                    TextField(
                      controller: _libelleController,
                      decoration: InputDecoration(
                        labelText: 'Libellé',
                        labelStyle: const TextStyle(
                          fontFamily: 'ZTGatha',
                          color: Color(0xFF19264C),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Color(0xFF19264C)),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Color(0xFFB0ACFD)),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    // Reference field.
                    TextField(
                      controller: _referenceController,
                      decoration: InputDecoration(
                        labelText: 'Reference',
                        labelStyle: const TextStyle(
                          fontFamily: 'ZTGatha',
                          color: Color(0xFF19264C),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Color(0xFF19264C)),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Color(0xFFB0ACFD)),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF141E46),
                  ),
                  onPressed: () async {
                    // Validate montant.
                    double montant =
                        double.tryParse(_montantController.text.trim()) ?? 0.0;
                    if (montant <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Veuillez saisir un montant valide')),
                      );
                      return;
                    }

                    Map<String, dynamic> reglementData = {
                      'id_client': int.tryParse(widget.clientId),
                      'date': DateFormat('yyyy-MM-dd HH:mm:ss')
                          .format(DateTime.now()),
                      'amount': montant,
                      'method': paymentMode,
                      'reference': _referenceController.text.trim(),
                    };

                    // Fetch current values from SharedPreferences
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    double currentEncaissement =
                        prefs.getDouble('total_encaissement') ?? 0.0;
                    // update the values
                    currentEncaissement += montant;

                    // Save back to SharedPreferences
                    await prefs.setDouble(
                        'total_encaissement', currentEncaissement);

                    final db = DatabaseHelper();
                    await db.addPayment(reglementData);

                    // Retrieve and update VERS: always add the montantPaye.
                    double currentVers = 0.0;
                    if (clientData['VERS'] != null) {
                      currentVers =
                          double.tryParse(clientData['VERS'].toString()) ?? 0.0;
                    }
                    double newVers = currentVers + montant;

                    await db.updateClientFinancials(int.parse(widget.clientId),
                        vers: newVers);

                    setState(() {
                      clientData['VERS'] = newVers;
                    });
                    _updateClientSolde(montant, isVente: false);
                    _subscribeVersements(); // Refresh list

                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Règlement ajouté avec succès (Local)'),
                    ));
                    // generateReglementPDF(reglementData); // Adapt if needed
                  },
                  child: Text(
                    'Ajouter',
                    style: TextStyle(
                      fontFamily: 'ZTGatha',
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD9F4E9),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Annuler',
                    style: TextStyle(
                      fontFamily: 'ZTGatha',
                      color: Color(0xFF19264C),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMainAddDialog() {
    final UserType userType = resolveUserType(vanId);

    // Determine button permissions based on user type.
    final bool canClickVente = userType == UserType.All ||
        userType == UserType.VenteReglementOnly ||
        userType == UserType.AllExceptEdit;
    final bool canClickReglement = userType == UserType.All ||
        userType == UserType.VenteReglementOnly ||
        userType == UserType.AllExceptEdit;
    final bool canClickPreVente = userType == UserType.All ||
        userType == UserType.PreVenteOnly ||
        userType == UserType.AllExceptEdit;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFAFAFF),
          title: const Text(
            'Ajouter',
            style: TextStyle(
              color: Color(0xFF19264C),
              fontFamily: 'Bahnschrift',
            ),
          ),
          content: const Text(
            'Choisissez une action à effectuer',
            style: TextStyle(
              color: Color(0xFF19264C),
              fontFamily: 'ZTGatha',
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Vente button and label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 176, 172, 253),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: canClickVente
                          ? () {
                              Navigator.of(context).pop();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddVenteScreen(
                                    clientId: widget.clientId,
                                    vanId: vanId!,
                                    clientData: clientData,
                                  ),
                                ),
                              ).then((value) {
                                if (value == true) {
                                  _subscribeVentes();
                                  _fetchClientDetails();
                                }
                              });
                            }
                          : null,
                      child: Image.asset(
                        'assets/images/vente.webp',
                        width: 22,
                        height: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      color: Colors.white,
                      child: const Text(
                        'Vente',
                        style: TextStyle(
                          color: Color(0xFF19264C),
                          fontSize: 12,
                          fontFamily: 'ZTGatha',
                        ),
                      ),
                    ),
                  ],
                ),
                // Règlement button and label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 176, 172, 253),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: canClickReglement
                          ? () {
                              Navigator.of(context).pop();
                              _showAddReglementDialog();
                            }
                          : null,
                      child: Image.asset(
                        'assets/images/regle.webp',
                        width: 22,
                        height: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      color: Colors.white,
                      child: const Text(
                        'Règlement',
                        style: TextStyle(
                          color: Color(0xFF19264C),
                          fontSize: 12,
                          fontFamily: 'ZTGatha',
                        ),
                      ),
                    ),
                  ],
                ),
                // Pré vente button and label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /*ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 176, 172, 253),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: canClickPreVente
                          ? () {
                              Navigator.of(context).pop();
                              //_showAddPreVenteDialog();
                            }
                          : null,
                      child: Image.asset(
                        'assets/images/regle.webp',
                        width: 22,
                        height: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      color: Colors.white,
                      child: const Text(
                        'Pré vente',
                        style: TextStyle(
                          color: Color(0xFF19264C),
                          fontSize: 12,
                          fontFamily: 'ZTGatha',
                        ),
                      ),
                    ),*/
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<String> _getClientType() async {
    // For now, default to Detail or fetch from clientData if stored
    return clientData['type_client'] ?? "Detail";
  }

  Future<void> _loadItemsForVente() async {
    final db = DatabaseHelper();
    final items = await db.getItems();
    // Map items to the format expected by the vente dialog
    setState(() {
      selectedDepotMarchandises = items.map((item) {
        return {
          'id_item': item['id_item'],
          'COD_ARTICLE': item['id_item']?.toString() ?? '',
          'DESIGNATION': item['item_name'] ?? '',
          'PU_ART': item['unit_price'] ?? 0.0,
          'PU_ART_GROS': item['pu_art_gros'] ?? 0.0,
          'QUANT_LIVRE': item['stock_quantity'] ?? 0,
          'NBRE_COLIS': item['nbre_colis'] ?? 0,
          'COND': item['cond'] ?? 0,
          'TVA': tva, // Use global TVA
          'CATEGORY': item['category'] ?? '',
        };
      }).toList();
    });
  }

  Future<void> _showAddVenteDialog() async {
    // Load items from database before showing dialog
    await _loadItemsForVente();
    
    // Check if items were loaded
    if (selectedDepotMarchandises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Aucun article disponible. Veuillez ajouter des articles dans le stock.'),
      ));
      return;
    }

    // Fetch client type before showing the dialog.
    String clientType = await _getClientType();

    // Clear controllers and state.
    _venteMontantController.clear();
    selectedItems.clear();
    totalAmount = 0.0;
    isValide = false;

    // Local Map to store the quantity entered for each product.
    Map<String, int> enteredQuantities = {};
    Map<String, double> enteredPrices = {};

    // Define the toggle variable for unité/carton.
    bool isCarton = false; // false: unité, true: carton

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool isGros = clientType.toLowerCase() == "gros";
            double newTotal = 0.0;
            // Calculate the new total amount.
            for (var article in selectedDepotMarchandises) {
              String code = article['COD_ARTICLE'].toString();
              int qty = enteredQuantities[code] ?? 0;
              // Get the base price depending on client type.
              double defaultPrice = isGros
                  ? (article['PU_ART_GROS'] is num
                      ? (article['PU_ART_GROS'] as num).toDouble()
                      : 0.0)
                  : (article['PU_ART'] is num
                      ? (article['PU_ART'] as num).toDouble()
                      : 0.0);
              // For carton mode, multiply the base price by 'COND'.
              if (isCarton) {
                defaultPrice *= (article['COND'] is num
                    ? (article['COND'] as num).toDouble()
                    : 1.0);
              }

              // Use entered price if available, otherwise use default
              double currentPrice = enteredPrices[code] ?? defaultPrice;

              // Update enteredPrices if it was empty to show the default initially in the text field
              if (!enteredPrices.containsKey(code)) {
                enteredPrices[code] = defaultPrice;
              }

              double tva = (article['TVA'] as num).toDouble();
              newTotal += qty *
                  currentPrice *
                  (1.0 + (tva / 100.0)); // becomes 1 + (19/100) = 1.19;
            }
            totalAmount = double.parse(newTotal.toStringAsFixed(2));

            return AlertDialog(
              backgroundColor: Color(0xFFFAFAFF),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vente',
                    style: TextStyle(
                      color: const Color(0xFF19264C),
                      fontFamily: 'Bahnschrift',
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Unité',
                        style: TextStyle(
                          fontFamily: 'ZTGatha',
                          color: const Color(0xFF19264C),
                          fontSize: 14,
                        ),
                      ),
                      Switch(
                        value: isCarton,
                        onChanged: (value) {
                          setState(() {
                            isCarton = value;
                          });
                        },
                        activeColor: const Color(0xFFD9F4E9),
                        activeTrackColor: const Color(0xFF19264C),
                        inactiveThumbColor: const Color(0xFF19264C),
                        inactiveTrackColor: const Color(0xFFD9F4E9),
                      ),
                      Text(
                        'Carton',
                        style: TextStyle(
                          fontFamily: 'ZTGatha',
                          color: const Color(0xFF19264C),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              insetPadding: const EdgeInsets.all(20),
              content: Container(
                width: 500,
                height: MediaQuery.of(context).size.height * 0.8,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Depot selection removed - we load all items directly from database
                      // _buildDepotSelection(setState),

                      const SizedBox(height: 10),
                      // DataTable showing articles with custom layout for article details.
                      // Wrap the DataTable with two SingleChildScrollViews: one for vertical and one for horizontal scrolling.
                      Container(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: SingleChildScrollView(
                          // Vertical scrolling

                          child: DataTable(
                            dataRowHeight: 100,
                            columns: const [
                              DataColumn(
                                label: Text(
                                  "Produit",
                                  style: TextStyle(
                                    fontFamily: 'ZTGatha',
                                    color: Color(0xFF19264C),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Total",
                                  style: TextStyle(
                                    fontFamily: 'ZTGatha',
                                    color: Color(0xFF19264C),
                                  ),
                                ),
                              ),
                            ],
                            rows: selectedDepotMarchandises.map((article) {
                              String code = article['COD_ARTICLE'].toString();
                              String designation =
                                  (article['DESIGNATION'] ?? article['item_name'] ?? '').toString();
                              // Calculate available quantity
                              int available = isCarton
                                  ? (article['NBRE_COLIS'] is int
                                      ? article['NBRE_COLIS'] as int
                                      : 0)
                                  : (article['QUANT_LIVRE'] is int
                                      ? article['QUANT_LIVRE'] as int
                                      : 0);
                              int entered = enteredQuantities[code] ?? 0;
                              // Calculate price
                              double basePrice = isGros
                                  ? (article['PU_ART_GROS'] is num
                                      ? (article['PU_ART_GROS'] as num)
                                          .toDouble()
                                      : 0.0)
                                  : (article['PU_ART'] is num
                                      ? (article['PU_ART'] as num).toDouble()
                                      : 0.0);
                              if (isCarton) {
                                basePrice *= (article['COND'] is num
                                    ? (article['COND'] as num).toDouble()
                                    : 1.0);
                              }

                              double tva = (article['TVA'] as num).toDouble();
                              double subtotal = entered *
                                  basePrice *
                                  (1.0 +
                                      (tva /
                                          100.0)); // becomes 1 + (19/100) = 1.19;
                              subtotal = double.parse(subtotal.toStringAsFixed(
                                  2)); // Round to 2 decimal places

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        /*Image.asset(
                                          "assets/images/vch.webp",
                                          width: 80,
                                          height: 80,
                                        ),
                                        const SizedBox(width: 8),*/
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                designation,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'ZTGatha',
                                                  color: Color(0xFF19264C),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .production_quantity_limits,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        available.toString(),
                                                        style: const TextStyle(
                                                          fontFamily: 'ZTGatha',
                                                          color:
                                                              Color(0xFF19264C),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 100,
                                                    child: TextFormField(
                                                      initialValue:
                                                          entered.toString(),
                                                      keyboardType:
                                                          TextInputType.number,
                                                      style: const TextStyle(
                                                        fontFamily: 'ZTGatha',
                                                        color:
                                                            Color(0xFF19264C),
                                                      ),
                                                      decoration:
                                                          InputDecoration(
                                                        hintText: "Ajouter",
                                                        hintStyle:
                                                            const TextStyle(
                                                          fontFamily: 'ZTGatha',
                                                          color:
                                                              Color(0xFF19264C),
                                                        ),
                                                        enabledBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              const BorderSide(
                                                                  color: Color(
                                                                      0xFF19264C)),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      4.0),
                                                        ),
                                                        focusedBorder:
                                                            OutlineInputBorder(
                                                          borderSide:
                                                              const BorderSide(
                                                                  color: Color(
                                                                      0xFFB0ACFD)),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      4.0),
                                                        ),
                                                        isDense: true,
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .all(8),
                                                      ),
                                                      onChanged: (value) {
                                                        int qty = int.tryParse(
                                                                value) ??
                                                            0;
                                                        if (qty > available) {
                                                          qty = available;
                                                        }
                                                        setState(() {
                                                          enteredQuantities[
                                                              code] = qty;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      subtotal.toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontFamily: 'ZTGatha',
                                        color: Color(0xFF19264C),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Display real-time total.
                      Text(
                        'Total: ${totalAmount.toStringAsFixed(2)} DA',
                        style: const TextStyle(
                            fontSize: 18,
                            fontFamily: 'ZTGatha',
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                      const SizedBox(height: 20),
                      // Validé checkbox.
                      Row(
                        children: [
                          const Text(
                            'Validé: ',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF19264C),
                              fontFamily: 'ZTGatha',
                            ),
                          ),
                          Checkbox(
                            value: isValide,
                            activeColor: Colors.green,
                            onChanged: (bool? value) {
                              setState(() {
                                isValide = value ?? false;
                                if (!isValide) {
                                  _venteMontantController.text = "0";
                                }
                              });
                            },
                          ),
                          Text(
                            isValide ? 'Valide' : 'Non Valide',
                            style: TextStyle(
                              fontSize: 16,
                              color: isValide ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'ZTGatha',
                            ),
                          ),
                        ],
                      ),
                      // Montant payé field if vente is valid.
                      if (isValide)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: TextField(
                            controller: _venteMontantController,
                            decoration: InputDecoration(
                              labelText: 'Montant payé (DA)',
                              labelStyle: const TextStyle(
                                color: Color(0xFF19264C),
                                fontFamily: 'ZTGatha',
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide:
                                    const BorderSide(color: Color(0xFF19264C)),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide:
                                    const BorderSide(color: Color(0xFFB0ACFD)),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141E46),
                  ),
                  onPressed: () {
                    if (!isValide) {
                      _venteMontantController.text = "0";
                    }
                    // Build the list of selected items.
                    selectedItems.clear();
                    for (var article in selectedDepotMarchandises) {
                      String code = article['COD_ARTICLE'].toString();
                      String designation = (article['DESIGNATION'] ?? article['item_name'] ?? '').toString();
                      int qty = enteredQuantities[code] ?? 0;
                      if (qty > 0) {
                        double defaultPrice = isGros
                            ? (article['PU_ART_GROS'] is num
                                ? (article['PU_ART_GROS'] as num).toDouble()
                                : 0.0)
                            : (article['PU_ART'] is num
                                ? (article['PU_ART'] as num).toDouble()
                                : 0.0);
                        if (isCarton) {
                          defaultPrice *= (article['COND'] is num
                              ? (article['COND'] as num).toDouble()
                              : 1.0);
                        }
                        double currentPrice = enteredPrices[code] ?? defaultPrice;

                        if (!isCarton) {
                          // Unité mode: use QUANT_LIVRE.
                          selectedItems.add({
                            'id_item': article['id_item'],
                            'COD_ARTICLE': article['COD_ARTICLE'] ?? article['code_article'],
                            'DESIGNATION': designation,
                            'price_type': clientType,
                            'QUANT_LIVRE': qty,
                            'price': currentPrice,
                          });
                          // Decrease available quantity in unité.
                          article['QUANT_LIVRE'] =
                              (article['QUANT_LIVRE'] as int) - qty;
                        } else {
                          // Carton mode: calculate price multiplied by 'COND'.
                          selectedItems.add({
                            'id_item': article['id_item'],
                            'COD_ARTICLE': article['COD_ARTICLE'] ?? article['code_article'],
                            'DESIGNATION': designation,
                            'price_type': clientType,
                            'NBRE_COLIS': qty,
                            'price': currentPrice,
                          });
                          // Decrease available quantity in carton.
                          article['NBRE_COLIS'] =
                              (article['NBRE_COLIS'] as int) - qty;
                        }
                      }
                    }
                    _addVente(context, isValide);
                  },
                  child: const Text(
                    'Ajouter',
                    style: TextStyle(
                      fontFamily: 'ZTGatha',
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD9F4E9),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(
                      fontFamily: 'ZTGatha',
                      color: Color(0xFF19264C),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

// Updated depot selection: uses 'id_depot' and loads items from database
  Widget _buildDepotSelection(StateSetter localSetState) {
    // Since we're loading items directly from database, depot selection is optional
    // If no depots, hide the dropdown
    if (depots.isEmpty) {
      return const SizedBox.shrink();
    }

    // Remove duplicates by using a Set to track seen values
    final seenIds = <String>{};
    final uniqueDepots = depots.where((depot) {
      final id = (depot['id_depot'] ?? depot['iddepot'])?.toString() ?? '';
      if (id.isEmpty || seenIds.contains(id)) {
        return false;
      }
      seenIds.add(id);
      return true;
    }).toList();

    // Ensure selectedDepotId is valid or set to first depot
    String? validSelectedId = selectedDepotId;
    if (validSelectedId == null || !seenIds.contains(validSelectedId)) {
      validSelectedId = uniqueDepots.isNotEmpty
          ? (uniqueDepots[0]['id_depot'] ?? uniqueDepots[0]['iddepot'])
              ?.toString()
          : null;
    }

    return DropdownButton<String>(
      value: validSelectedId,
      hint: const Text(
        'Select Depot',
        style: TextStyle(
          fontFamily: 'ZTGatha',
          color: Color(0xFF19264C),
        ),
      ),
      isExpanded: true,
      dropdownColor: const Color(0xFFFAFAFF),
      items: uniqueDepots.map((depot) {
        final depotId =
            (depot['id_depot'] ?? depot['iddepot'])?.toString() ?? '';
        final depotName = depot['name']?.toString() ?? 'Unnamed Depot';
        return DropdownMenuItem<String>(
          value: depotId,
          child: Text(
            depotName,
            style: const TextStyle(
              fontFamily: 'ZTGatha',
              color: Color(0xFF19264C),
            ),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue == null) return;
        localSetState(() {
          selectedDepotId = newValue;
          // Load items for the selected depot
          final depotId = int.tryParse(newValue);
          if (depotId != null) {
            _loadDepotItems(depotId);
          } else {
            // If no valid depot, reload all items
            _loadItemsForVente();
          }
          selectedItems.clear();
          totalAmount = 0.0;
        });
      },
    );
  }

  // UI for ventes limit selector
  Widget _buildVentesHeader() {
    return Column(
      children: [
        // Toggle between Ventes and Reglements
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: !showReglements 
                      ? const Color(0xFF141E46) 
                      : const Color(0xFFD9F4E9),
                  foregroundColor: !showReglements 
                      ? Colors.white 
                      : const Color(0xFF19264C),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    showReglements = false;
                  });
                },
                child: const Text(
                  'Ventes',
                  style: TextStyle(fontFamily: 'ZTGatha', fontSize: 16),
                ),
              ),
            ),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: showReglements 
                      ? const Color(0xFF141E46) 
                      : const Color(0xFFD9F4E9),
                  foregroundColor: showReglements 
                      ? Colors.white 
                      : const Color(0xFF19264C),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    showReglements = true;
                  });
                },
                child: const Text(
                  'Règlements',
                  style: TextStyle(fontFamily: 'ZTGatha', fontSize: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Show limit dropdown only for ventes
        if (!showReglements)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ventes:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF19264C),
                  fontFamily: 'ZTGatha',
                ),
              ),
              Row(
                children: [
                  Text('Afficher: ', style: TextStyle(fontFamily: 'ZTGatha')),
                  DropdownButton<int?>(
                    value: selectedVentesLimit,
                    items: ventesOptions
                        .map((n) => DropdownMenuItem(
                            value: n,
                            child: Text(n == null ? 'Tous' : n.toString())))
                        .toList(),
                    onChanged: (v) {
                      setState(() => selectedVentesLimit = v);
                      _subscribeVentes();
                    },
                  ),
                ],
              ),
            ],
          )
        else
          Row(
            children: [
              Text(
                'Règlements:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF19264C),
                  fontFamily: 'ZTGatha',
                ),
              ),
            ],
          ),
      ],
    );
  }



  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.clientName} - Details',
            style: TextStyle(
              color: Color(0xFF19264C),
              fontFamily: 'Bahnschrift',
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFF),
          ),
          child: clientData.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name, Code & Credit at top (centered)
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    clientData['NOMCLIENT'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF19264C),
                                      fontFamily: 'ZTGatha',
                                    ),
                                  ),
                                  Text(
                                    'Code: ${clientData['CODECLTV'] ?? ''}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[700],
                                      fontFamily: 'ZTGatha',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Details Card with shadow
                            Card(
                              elevation: 8,
                              color: Color(0xFFFAFAFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Address row
                                    Row(
                                      children: [
                                        Image.asset('assets/images/ads.webp',
                                            width: 20, height: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            clientData['ADRESSE'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Color(0xFF19264C),
                                              fontFamily: 'ZTGatha',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Email row
                                    Row(
                                      children: [
                                        Image.asset('assets/images/mail.webp',
                                            width: 20, height: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            clientData['EMAIL'] ?? 'N/A',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Color(0xFF19264C),
                                              fontFamily: 'ZTGatha',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Phone row with "Crédit" on right
                                    Row(
                                      children: [
                                        Image.asset('assets/images/tel.webp',
                                            width: 20, height: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          clientData['TEL'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF19264C),
                                            fontFamily: 'ZTGatha',
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color.fromARGB(
                                                255, 172, 168, 243),
                                            borderRadius: BorderRadius.circular(
                                                14.0), // More rounded corners
                                          ),
                                          child: Text(
                                            'Crédit: ${((clientData['SOLDEINI'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} DA',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF19264C),
                                              fontFamily: 'ZTGatha',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Ventes Section
                            _buildVentesHeader(),
                            SizedBox(height: 10),

                            const SizedBox(height: 10),
                            // Conditional list display based on toggle
                            if (!showReglements)
                              // Ventes List
                              for (var vente in ventesList)
                                ListTile(
                                  contentPadding: const EdgeInsets.only(left: 8, right: 0),
                                  leading: Image.asset('assets/images/box.webp',
                                      width: 40, height: 40),
                                  title: Text(
                                    'Total: ${((vente['montant'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} DA',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color.fromARGB(255, 92, 114, 180),
                                      fontFamily: 'ZTGatha',
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Date: ${vente['dateVente'] ?? 'Unknown Date'}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: const Color.fromARGB(
                                          255, 160, 160, 160),
                                      fontFamily: 'ZTGatha',
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Image.asset(
                                            'assets/images/pdf.webp',
                                            width: 16,
                                            height: 16),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => VentePdfScreen(
                                                vente: Map<String, dynamic>.from(vente),
                                                clientData: clientData,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(Icons.print, color: Color(0xFF19264C), size: 16),
                                        onPressed: () => _handleDirectPrint(vente, true),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Image.asset(
                                            'assets/images/edit.webp',
                                            width: 14,
                                            height: 14),
                                        onPressed: () {
                                          _showEditVenteDialog(vente);
                                        },
                                      ),
                                    ],
                                  ),
                                )

                            else
                              // Reglements List
                              for (var reglement in versementsList)
                                Card(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 8),
                                  elevation: 2,
                                  color: const Color(0xFFFAFAFF),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.only(left: 8, right: 0),
                                    leading: const Icon(
                                      Icons.payment,
                                      color: Color(0xFF141E46),
                                      size: 35,
                                    ),
                                    title: Text(
                                      'Montant: ${((reglement['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} DA',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF19264C),
                                        fontFamily: 'ZTGatha',
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Date: ${reglement['date'] ?? 'Unknown Date'}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color.fromARGB(255, 160, 160, 160),
                                            fontFamily: 'ZTGatha',
                                          ),
                                        ),
                                        Text(
                                          'Mode: ${reglement['method'] ?? 'N/A'}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF19264C),
                                            fontFamily: 'ZTGatha',
                                          ),
                                        ),
                                        if (reglement['reference'] != null && 
                                            reglement['reference'].toString().isNotEmpty)
                                          Text(
                                            'Réf: ${reglement['reference']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color.fromARGB(255, 120, 120, 120),
                                              fontFamily: 'ZTGatha',
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: Image.asset(
                                              'assets/images/pdf.webp',
                                              width: 16,
                                              height: 16),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ReglementPdfScreen(
                                                  reglement: Map<String, dynamic>.from(reglement),
                                                  clientData: clientData,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: Icon(Icons.print, color: Color(0xFF19264C), size: 16),
                                          onPressed: () => _handleDirectPrint(reglement, false),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                    // Floating add button positioned at bottom-right
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromARGB(255, 176, 172, 253),
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(16),
                          ),
                          onPressed: () => _showMainAddDialog(),
                          child: const Icon(
                            Icons.add,
                            size: 25,
                            color: Color(0xFF19264C),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          ),
        );
  }
}
