import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class AddVenteScreen extends StatefulWidget {
  final String clientId;
  final String vanId;
  final Map<dynamic, dynamic> clientData;

  const AddVenteScreen({
    Key? key,
    required this.clientId,
    required this.vanId,
    required this.clientData,
  }) : super(key: key);

  @override
  _AddVenteScreenState createState() => _AddVenteScreenState();
}

class _AddVenteScreenState extends State<AddVenteScreen> {
  final TextEditingController _venteMontantController = TextEditingController();
  List<Map<String, dynamic>> selectedDepotMarchandises = [];
  List<Map<String, dynamic>> selectedItems = [];
  Map<String, int> enteredQuantities = {};
  Map<String, double> enteredPrices = {};
  double totalAmount = 0.0;
  bool isValide = false;
  bool isCarton = false; // false: unité, true: carton
  bool isLoading = true;
  String _paymentMethod = 'Espece';
  double globalTva = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    globalTva = prefs.getDouble('global_tva') ?? 0.0;
    await _loadItemsForVente();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadItemsForVente() async {
    final db = DatabaseHelper();
    final items = await db.getItems();
    setState(() {
      selectedDepotMarchandises = items.map((item) {
        return {
          'COD_ARTICLE': item['id_item']?.toString() ?? '',
          'DESIGNATION': item['item_name'] ?? '',
          'PU_ART': item['unit_price'] ?? 0.0,
          'PU_ART_GROS': item['pu_art_gros'] ?? 0.0,
          'QUANT_LIVRE': item['stock_quantity'] ?? 0,
          'NBRE_COLIS': item['nbre_colis'] ?? 0,
          'COND': item['cond'] ?? 0,
          'TVA': globalTva, // Use global TVA
          'CATEGORY': item['category'] ?? '',
        };
      }).toList();
    });
  }

  String _getClientType() {
    return widget.clientData['type_client'] ?? "Detail";
  }

  void _calculateTotal() {
    String clientType = _getClientType();
    bool isGros = clientType.toLowerCase() == "gros";
    double newTotal = 0.0;

    for (var article in selectedDepotMarchandises) {
      String code = article['COD_ARTICLE'].toString();
      int qty = enteredQuantities[code] ?? 0;
      if (qty <= 0) continue;

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

      // Use entered price if available, otherwise use default
      double currentPrice = enteredPrices[code] ?? defaultPrice;
      
      // Update enteredPrices if it was empty to show the default initially in the text field
      if (!enteredPrices.containsKey(code)) {
        enteredPrices[code] = defaultPrice;
      }

      double tva = (article['TVA'] as num).toDouble();
      newTotal += qty * currentPrice * (1.0 + (tva / 100.0));
    }

    setState(() {
      totalAmount = double.parse(newTotal.toStringAsFixed(2));
    });
  }

  Future<void> _updateClientSolde(double amount, {required bool isVente}) async {
    final db = DatabaseHelper();
    final database = await db.database;
    
    double currentSolde = 0.0;
    if (widget.clientData['solde'] != null) {
      currentSolde = double.tryParse(widget.clientData['solde'].toString()) ?? 0.0;
    }

    double newSolde = isVente ? currentSolde + amount : currentSolde - amount;

    await database.update(
      'clients', // Fixed table name: "clients" instead of "client"
      {'solde': newSolde},
      where: 'id_client = ?',
      whereArgs: [int.parse(widget.clientId)],
    );
    
    widget.clientData['solde'] = newSolde;
  }

  void _addVente() async {
    // Collect selected items
    selectedItems.clear();
    String clientType = _getClientType();
    bool isGros = clientType.toLowerCase() == "gros";

    enteredQuantities.forEach((code, qty) {
      if (qty > 0) {
        var article = selectedDepotMarchandises.firstWhere(
            (a) => a['COD_ARTICLE'].toString() == code);
        
        double defaultPrice = isGros
            ? (article['PU_ART_GROS'] is num ? (article['PU_ART_GROS'] as num).toDouble() : 0.0)
            : (article['PU_ART'] is num ? (article['PU_ART'] as num).toDouble() : 0.0);

        if (isCarton) {
          defaultPrice *= (article['COND'] is num ? (article['COND'] as num).toDouble() : 1.0);
        }

        double currentPrice = enteredPrices[code] ?? defaultPrice;

        Map<String, dynamic> itemToAdd = Map.from(article);
        itemToAdd['price'] = currentPrice;
        if (isCarton) {
          itemToAdd['NBRE_COLIS'] = qty;
        } else {
          itemToAdd['QUANT_LIVRE'] = qty;
        }
        selectedItems.add(itemToAdd);
      }
    });

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Veuillez ajouter au moins un article'),
      ));
      return;
    }

    String montantPayeStr = _venteMontantController.text.trim();
    double montantPaye = double.tryParse(montantPayeStr) ?? 0.0;
    double remaining = totalAmount - montantPaye;

    if (remaining < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Le montant payé ne peut pas dépasser le total.')),
      );
      return;
    }

    // Prepare Vente Data
    Map<String, dynamic> venteData = {
      'sale_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'payment_status': isValide ? 'paid' : 'pending',
      'id_client': int.tryParse(widget.clientId),
      'total_amount': totalAmount,
      'payment_amount': montantPaye,
      'payment_method': _paymentMethod,
    };

    List<Map<String, dynamic>> saleItems = selectedItems.map((item) {
      double price = (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0;
      double tva = (item['TVA'] as num).toDouble();
      double priceWithTva = price * (1.0 + (tva / 100.0));
      priceWithTva = double.parse(priceWithTva.toStringAsFixed(2));

      int qty = 0;
      int? itemId = item['id_item'] is int ? item['id_item'] as int : int.tryParse(item['id_item']?.toString() ?? '');
      String designation = (item['DESIGNATION'] ?? item['item_name'] ?? '').toString();
      int? quantityUnits;
      int? quantityCartons;
      
      if (item.containsKey('QUANT_LIVRE') && !isCarton) {
        qty = item['QUANT_LIVRE'] as int? ?? 0;
        quantityUnits = qty;
      } else if (item.containsKey('NBRE_COLIS') || isCarton) {
        qty = item['NBRE_COLIS'] as int? ?? 0;
        quantityCartons = qty;
      }

      return {
        'id_item': itemId ?? 0,
        'designation': designation,
        'quantity': qty,
        'unit_price': priceWithTva,
        'total_price': priceWithTva * qty,
        'quantity_units': quantityUnits,
        'quantity_cartons': quantityCartons,
      };
    }).toList();

    // Update SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double currentEncaissement = prefs.getDouble('total_encaissement') ?? 0.0;
    double currentChiffreAffaire = prefs.getDouble('total_chiffre_affaire') ?? 0.0;
    
    currentEncaissement += montantPaye;
    currentChiffreAffaire += totalAmount;

    await prefs.setDouble('total_encaissement', currentEncaissement);
    await prefs.setDouble('total_chiffre_affaire', currentChiffreAffaire);

    // Save to Local DB
    final db = DatabaseHelper();
    await db.addSale(venteData, saleItems);

    // Update Client Financials
    double currentCa = double.tryParse(widget.clientData['CA']?.toString() ?? '0') ?? 0.0;
    double currentVers = double.tryParse(widget.clientData['VERS']?.toString() ?? '0') ?? 0.0;
    
    double newCa = currentCa + totalAmount;
    double newVers = currentVers + montantPaye;

    await db.updateClientFinancials(int.parse(widget.clientId), ca: newCa, vers: newVers);

    // Update Solde
    if (remaining > 0) {
      await _updateClientSolde(remaining, isVente: true);
    }

    Navigator.of(context).pop(true); // Return true to indicate success
  }

  @override
  Widget build(BuildContext context) {
    String clientType = _getClientType();
    bool isGros = clientType.toLowerCase() == "gros";

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFF),
      appBar: AppBar(
        title: const Text(
          'Nouvelle Vente',
          style: TextStyle(fontFamily: 'Bahnschrift', color: Color(0xFF19264C)),
        ),
        backgroundColor: const Color(0xFFFAFAFF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF19264C)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFF19264C).withOpacity(0.2),
            height: 1.0,
          ),
        ),
        actions: [
          Row(
            children: [
              const Text(
                'Unité',
                style: TextStyle(fontFamily: 'ZTGatha', color: Color(0xFF19264C), fontSize: 14),
              ),
              Switch(
                value: isCarton,
                onChanged: (value) {
                  setState(() {
                    isCarton = value;
                    enteredPrices.clear(); // Reset custom prices when switching mode
                    _calculateTotal();
                  });
                },
                activeColor: const Color(0xFFD9F4E9),
                activeTrackColor: const Color(0xFF19264C),
                inactiveThumbColor: const Color(0xFF19264C),
                inactiveTrackColor: const Color(0xFFD9F4E9),
              ),
              const Text(
                'Carton',
                style: TextStyle(fontFamily: 'ZTGatha', color: Color(0xFF19264C), fontSize: 14),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: DataTable(
                          columnSpacing: 20, // Increased spacing
                        horizontalMargin: 6,
                        dataRowHeight: 55,
                        columns: const [
                          DataColumn(label: Text("Produit", style: TextStyle(fontFamily: 'Bahnschrift', color: Color(0xFF19264C), fontSize: 15))),
                          DataColumn(label: Text("Prix", style: TextStyle(fontFamily: 'Bahnschrift', color: Color(0xFF19264C), fontSize: 15))),
                          DataColumn(label: Text("Qté", style: TextStyle(fontFamily: 'Bahnschrift', color: Color(0xFF19264C), fontSize: 15))),
                          DataColumn(label: Text("Total", style: TextStyle(fontFamily: 'Bahnschrift', color: Color(0xFF19264C), fontSize: 15))),
                        ],
                        rows: selectedDepotMarchandises.map((article) {
                          String code = article['COD_ARTICLE'].toString();
                          String designation = article['DESIGNATION'].toString();
                          int available = isCarton
                              ? (article['NBRE_COLIS'] as int? ?? 0)
                              : (article['QUANT_LIVRE'] as int? ?? 0);
                          int entered = enteredQuantities[code] ?? 0;
                          
                          double defaultPrice = isGros
                              ? (article['PU_ART_GROS'] is num ? (article['PU_ART_GROS'] as num).toDouble() : 0.0)
                              : (article['PU_ART'] is num ? (article['PU_ART'] as num).toDouble() : 0.0);
                          
                          if (isCarton) {
                            defaultPrice *= (article['COND'] is num ? (article['COND'] as num).toDouble() : 1.0);
                          }
                          
                          double currentPrice = enteredPrices[code] ?? defaultPrice;
                          
                          double tva = (article['TVA'] as num).toDouble();
                          double priceWithTva = currentPrice * (1.0 + (tva / 100.0));
                          double rowTotal = entered * priceWithTva;

                          return DataRow(
                            cells: [
                               DataCell(
                                Container(
                                   width: 170, // Increased width for better responsiveness
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(designation, 
                                        style: TextStyle(fontFamily: 'ZTGatha', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF19264C)), 
                                        overflow: TextOverflow.ellipsis, 
                                        maxLines: 2
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.production_quantity_limits, size: 12, color: Color(0xFF19264C)),
                                          const SizedBox(width: 2),
                                          Text(available.toString(), 
                                            style: const TextStyle(fontFamily: 'ZTGatha', fontSize: 12, color: Color(0xFF19264C))
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 65,
                                  child: TextFormField(
                                    key: Key('price_${code}_${isCarton}'),
                                    initialValue: currentPrice.toStringAsFixed(2),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontFamily: 'ZTGatha', color: Color(0xFF19264C), fontSize: 13),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF19264C))),
                                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFB0ACFD))),
                                    ),
                                    onChanged: (value) {
                                      double? newPrice = double.tryParse(value);
                                      if (newPrice != null) {
                                        setState(() {
                                          enteredPrices[code] = newPrice;
                                          _calculateTotal();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 50,
                                  child: TextFormField(
                                    initialValue: entered > 0 ? entered.toString() : '',
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontFamily: 'ZTGatha', color: Color(0xFF19264C)),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF19264C))),
                                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFB0ACFD))),
                                    ),
                                    onChanged: (value) {
                                      int qty = int.tryParse(value) ?? 0;
                                      if (qty > available) qty = available;
                                      setState(() {
                                        enteredQuantities[code] = qty;
                                        _calculateTotal();
                                      });
                                    },
                                  ),
                                ),
                              ),
                              DataCell(Text(rowTotal.toStringAsFixed(2), style: const TextStyle(fontFamily: 'ZTGatha', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF19264C)))),
                            ],
                          );
                        }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                    ),
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total General:', style: TextStyle(fontFamily: 'Bahnschrift', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF19264C))),
                              Text('${totalAmount.toStringAsFixed(2)} DZD', style: const TextStyle(fontFamily: 'Bahnschrift', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF141E46))),
                            ],
                          ),
                          const Spacer(),
                          ChoiceChip(
                            label: const Text('Espece'),
                            selected: _paymentMethod == 'Espece',
                            onSelected: (selected) {
                              if (selected) setState(() => _paymentMethod = 'Espece');
                            },
                            selectedColor: const Color(0xFFD9F4E9),
                            backgroundColor: const Color(0xFFD9F4E9),
                            side: BorderSide(
                              color: _paymentMethod == 'Espece' ? const Color(0xFF19264C) : Colors.transparent,
                              width: 1,
                            ),
                            labelStyle: const TextStyle(
                              color: Color(0xFF19264C),
                              fontFamily: 'ZTGatha',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text('Carte'),
                            selected: _paymentMethod == 'Carte',
                            onSelected: (selected) {
                              if (selected) setState(() => _paymentMethod = 'Carte');
                            },
                            selectedColor: const Color(0xFFD9F4E9),
                            backgroundColor: const Color(0xFFD9F4E9),
                            side: BorderSide(
                              color: _paymentMethod == 'Carte' ? const Color(0xFF19264C) : Colors.transparent,
                              width: 1,
                            ),
                            labelStyle: const TextStyle(
                              color: Color(0xFF19264C),
                              fontFamily: 'ZTGatha',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _venteMontantController,
                              decoration: InputDecoration(
                                labelText: 'Montant versé',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: 10),
                          Row(
                            children: [
                              Checkbox(
                                value: isValide,
                                activeColor: Colors.green,
                                checkColor: Colors.white,
                                side: BorderSide(
                                  color: isValide ? Colors.green : Colors.red,
                                  width: 2,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    isValide = value ?? false;
                                  });
                                },
                              ),
                              Text(
                                'Validé', 
                                style: TextStyle(
                                  fontFamily: 'ZTGatha',
                                  color: isValide ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD9F4E9), 
                                foregroundColor: const Color(0xFF19264C),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              child: const Text('Annuler', style: TextStyle(fontFamily: 'ZTGatha')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _addVente,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF141E46), 
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              child: const Text('Valider', style: TextStyle(fontFamily: 'ZTGatha')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
