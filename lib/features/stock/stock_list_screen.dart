/// lib/stock.dart
import 'package:bsoft_app_dist/data/database_helper.dart';
import 'package:bsoft_app_dist/features/sales/sales_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({Key? key}) : super(key: key);
  @override
  _StockScreenState createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  // Offline connectivity flag.
  // bool isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadDepots();
  }

  @override
  void dispose() {
    // connectivitySubscription.cancel();
    super.dispose();
  }

  // Fetch depots from Local DB.
  Future<void> _loadDepots() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('userId');
    
    if (username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur : utilisateur non connecté'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final db = DatabaseHelper();
    final users = await db.getUsers();
    final user = users.firstWhere((u) => u['nom'] == username, orElse: () => {});
    
    if (user.isNotEmpty) {
       final van = await db.getVanByUserId(user['id_user']);
       if (van != null) {
         List<Map<String, dynamic>> depotList = await db.getDepots(van['id_van']);
         
         if (!mounted) return;
         
         setState(() {
            depots = depotList;
            if (depotList.isNotEmpty) {
              selectedDepotId = depotList[0]['id_depot'].toString();
              _loadDepotItems(depotList[0]['id_depot']);
            }
         });
       }
    }
  }

  Future<void> _loadDepotItems(int depotId) async {
    final db = DatabaseHelper();
    List<Map<String, dynamic>> items = await db.getDepotItems(depotId);
    setState(() {
      // Map DB items to the structure expected by the UI
      selectedDepotMarchandises = items.map((item) {
        return {
          'DESIGNATION': item['item_name'],
          'QTE_DECHARGE': item['quantity'], // Assuming quantity is what we want to show
          'PU_ART': item['unit_price'],
          'PU_ART_GROS': item['unit_price'], // Placeholder
          ...item
        };
      }).toList();
    });
  }

  // Change the selected depot.
  void _onDepotSelected(String? depotId) {
    if (depotId != null) {
      setState(() {
        selectedDepotId = depotId;
      });
      _loadDepotItems(int.parse(depotId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Stock Van',
          style: TextStyle(
            color: Color(0xFF19264C),
            fontFamily: 'Bahnschrift',
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: depots.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Offline banner.
                /*if (isOffline)
                  Container(
                    width: double.infinity,
                    color: Colors.red,
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'déconnecté',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),*/
                // Dropdown to select a depot.
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButton<String>(
                    dropdownColor: Color(0xFFFAFAFF),
                    value: selectedDepotId,
                    onChanged: _onDepotSelected,
                    items: depots.map((depot) {
                      return DropdownMenuItem<String>(
                        value: depot['id_depot'].toString(),
                        child: Text(
                          depot['name'],
                          style: TextStyle(
                            fontFamily: 'ZTGatha',
                            color: Color(0xFF19264C),
                            fontSize: 18,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Display selected depot's articles.
                Expanded(
                  child: ListView.builder(
                    itemCount: selectedDepotMarchandises.length,
                    itemBuilder: (context, index) {
                      var item = selectedDepotMarchandises[index];
                      return _buildItemCard(item);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  // Widget to display each article.
  Widget _buildItemCard(Map<String, dynamic> item) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: Color(0xFFFAFAFF),
      elevation: 2,
      child: ListTile(
        title: Text(
          item['DESIGNATION'] ?? 'Unnamed Item',
          style: TextStyle(
            fontSize: 20, // Smaller font for the name
            fontWeight: FontWeight.bold,
            fontFamily: 'Bahnschrift',
            color: Color(0xFF19264C),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quantité (unité): ${item['QTE_DECHARGE'] ?? 'N/A'}', // NBRE_COLIS FOR CARTON
              style: TextStyle(
                fontSize: 12, // Smaller font for the address
                fontFamily: 'ZTGatha',
                color: Color.fromARGB(255, 156, 156, 158),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Prix (Détails): ${item['PU_ART'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 12, // Smaller font for the address
                fontFamily: 'ZTGatha',
                color: Color.fromARGB(255, 156, 156, 158),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Prix (Gros): ${item['PU_ART_GROS'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 12, // Smaller font for the address
                fontFamily: 'ZTGatha',
                color: Color.fromARGB(255, 156, 156, 158),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            //Text('Taille (Poids): ${item['POIDS'] ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }
}
