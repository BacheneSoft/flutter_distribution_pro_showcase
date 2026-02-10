import 'package:path/path.dart';

/// MOCK DatabaseHelper for Public Showcase
/// This version removes all SQLite dependencies and returns static demo data.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  
  // Real DB placeholder (not used in mock)
  static dynamic _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  // Simulated "database" getter
  Future<dynamic> get database async => null;

  // Mock static data
  final List<Map<String, dynamic>> _mockClients = [
    {
      'id_client': 1,
      'nom': 'Client Demo - Epicerie Rahma',
      'tel': '0550123456',
      'type_client': 'Gros',
      'commune': 'Alger',
      'cite': 'Hydra',
      'solde': 15000.0,
      'solde_init': 15000.0,
      'code': '1001'
    },
    {
      'id_client': 2,
      'nom': 'Client Demo - Superette Al Baraka',
      'tel': '0661987654',
      'type_client': 'Detail',
      'commune': 'Oran',
      'cite': 'Akid Lotfi',
      'solde': 0.0,
      'solde_init': 0.0,
      'code': '1002'
    },
  ];

  final List<Map<String, dynamic>> _mockItems = [
    {
      'id_item': 1,
      'item_name': 'Produit A - Jus d\'Orange 1L',
      'unit_price': 150.0,
      'pu_art_gros': 135.0, // Prix Gros added
      'stock_quantity': 500,
      'code_article': 'ART001',
      'cond': 12,
      'nbre_colis': 42,
    },
    {
      'id_item': 2,
      'item_name': 'Produit B - Eau Minérale 1.5L',
      'unit_price': 40.0,
      'pu_art_gros': 35.0, // Prix Gros added
      'stock_quantity': 1200,
      'code_article': 'ART002',
      'cond': 6,
      'nbre_colis': 200,
    },
  ];

  final List<Map<String, dynamic>> _mockSales = [
    {
      'id_sale': 777,
      'id_client': 1,
      'id_user': 1,
      'sale_date': '2026-02-10 10:30:00',
      'total_amount': 2250.0,
      'payment_amount': 2250.0,
      'payment_method': 'Espèces',
      'payment_status': 'Payé',
      'notes': 'Vente demo showcase',
    },
  ];

  final List<Map<String, dynamic>> _mockSaleItems = [
    {
      'id_sold_item': 1,
      'id_sale': 777,
      'id_item': 1,
      'quantity': 15,
      'unit_price': 150.0,
      'total_price': 2250.0,
      'designation': 'Produit A - Jus d\'Orange 1L',
      'item_name': 'Produit A - Jus d\'Orange 1L',
    },
  ];

  final List<Map<String, dynamic>> _mockPayments = [
    {
      'id_payment': 666,
      'id_client': 1,
      'amount': 5000.0,
      'date': '2026-02-10 11:00:00',
      'method': 'Versement',
      'reference': 'REF-DEMO-001',
    },
  ];

  // Mock Methods Implementation
  Future<List<Map<String, dynamic>>> getClients() async => _mockClients;
  Future<List<Map<String, dynamic>>> getItems() async => _mockItems;
  Future<List<Map<String, dynamic>>> getUsers() async => [
    {'id_user': 1, 'nom': 'admin', 'password': '123', 'route': 'Demo Route'}
  ];

  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    if (username == 'admin' && password == '123') {
      return {'id_user': 1, 'nom': 'admin', 'route': 'Demo Route'};
    }
    return null;
  }

  Future<int> addLocalUser({

    required String name,
    required String password,
    String route = '',
  }) async => 1;


  Future<int> insertClient(Map<String, dynamic> client) async => 999;
  Future<int> updateClient(Map<String, dynamic> client) async => 1;
  Future<void> deleteClient(int id) async {}
  Future<String> getNextClientCode() async => "1003";

  Future<Map<String, dynamic>?> getVanByUserId(int userId) async => {
    'id_van': 1, 
    'van_name': 'Van Demo 01', 
    'id_user': 1, 
    'encaissement': 145600.0, 
    'chiffre_affaire': 189250.0
  };

  Future<void> updateVanStats(int vanId, double encaissement, double chiffreAffaire) async {}
  Future<void> resetVanStats(int vanId) async {}

  Future<int> addItem(Map<String, dynamic> item) async => 888;
  Future<int> updateItem(Map<String, dynamic> item) async => 1;
  Future<void> deleteItem(int id) async {}
  Future<void> deleteAllItems() async {}

  Future<int> addCategory(String name) async => 555;

  Future<List<String>> getCategories() async => ['Boissons', 'Alimentation', 'Divers'];

  
  Future<List<Map<String, dynamic>>> getDepots(int vanId) async => [
    {'id_depot': 1, 'name': 'Stock Van Principal', 'id_van': 1}
  ];

  Future<List<Map<String, dynamic>>> getDepotItems(int depotId) async {
    return _mockItems.map((item) => {
      ...item,
      'id_depot_item': item['id_item'],
      'quantity': item['stock_quantity'],
      'quantity_livre': item['stock_quantity'],
      'designation': item['item_name'],
      'DESIGNATION': item['item_name'],
      'COD_ARTICLE': item['code_article'],
    }).toList();
  }

  Future<void> updateDepotItem(int depotItemId, {int? quantity, int? quantityLivre}) async {}
  Future<void> updateItemStock(int itemId, {int? quantityUnits, int? quantityCartons}) async {}

  Future<int> addSale(Map<String, dynamic> saleData, List<Map<String, dynamic>> items) async => 777;
  Future<void> updateSale(int saleId, Map<String, dynamic> saleData, List<Map<String, dynamic>> items) async {}

  Future<List<Map<String, dynamic>>> getSalesForClient(int clientId) async => _mockSales.where((s) => s['id_client'] == clientId).toList();
  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async => _mockSaleItems.where((si) => si['id_sale'] == saleId).toList();

  Future<int> addPayment(Map<String, dynamic> paymentData) async => 666;
  Future<List<Map<String, dynamic>>> getPaymentsForClient(int clientId) async => _mockPayments.where((p) => p['id_client'] == clientId).toList();

  Future<void> updateClientFinancials(int clientId, {double? solde, double? ca, double? vers}) async {}
  Future<Map<String, dynamic>?> getClient(int clientId) async => _mockClients.first;

  Future<int> addCloture({required String clotureDate, required double montant, required double encaissement, required double chiffreAffaire}) async => 555;
  Future<void> resetInventoryTracking() async {}
  
  Future<List<Map<String, dynamic>>> getCloturesHistory() async => [
    {
      'id_cloture': 1,
      'date_cloture': '2026-02-09',
      'montant': 125000.0,
      'encaissement': 125000.0,
      'chiffre_affaire': 150000.0,
      'status': 'Complet'
    },
    {
      'id_cloture': 2,
      'date_cloture': '2026-02-08',
      'montant': 98000.0,
      'encaissement': 98000.0,
      'chiffre_affaire': 115000.0,
      'status': 'Complet'
    },
  ];

  Future<List<Map<String, dynamic>>> getSalesByDate(String date) async => _mockSales;
  Future<List<Map<String, dynamic>>> getPaymentsByDate(String date) async => _mockPayments;
  Future<List<Map<String, dynamic>>> getClientsByIds(List<int> clientIds) async => _mockClients;
  
  Future<List<Map<String, dynamic>>> getAllSaleItemsForSales(List<int> saleIds) async => _mockSaleItems;
  Future<List<Map<String, dynamic>>> getSalesExportData(String date) async => [];
  Future<List<Map<String, dynamic>>> getPaymentsExportData(String date) async => [];

  Future<String> getDatabasePath() async => "mock_db_path";

}
