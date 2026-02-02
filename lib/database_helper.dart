// ignore: depend_on_referenced_packages
//import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'clients.db');
    print("Database path: $path"); // Debugging: Show the database path
    return await openDatabase(path,
        version: 13, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add code and email columns to clients table
      try {
        await db.execute('ALTER TABLE clients ADD COLUMN code TEXT');
        await db.execute('ALTER TABLE clients ADD COLUMN email TEXT');
      } catch (e) {
        // Columns might already exist, ignore error
        print("Migration note: $e");
      }
    }
    if (oldVersion < 3) {
      // Add payment_amount column to sold table
      try {
        await db.execute('ALTER TABLE sold ADD COLUMN payment_amount REAL DEFAULT 0.0');
      } catch (e) {
        // Column might already exist, ignore error
        print("Migration note: $e");
      }
    }
    if (oldVersion < 4) {
      // Add clotures_history table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS clotures_history (
            id_cloture INTEGER PRIMARY KEY AUTOINCREMENT,
            cloture_date TEXT NOT NULL,
            montant REAL DEFAULT 0.0,
            encaissement REAL DEFAULT 0.0,
            chiffre_affaire REAL DEFAULT 0.0,
            created_at TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now'))
          )
        ''');
      } catch (e) {
        print("Migration note: $e");
      }
    }
    if (oldVersion < 5) {
      // Add quantity tracking columns to item table
      try {
        await db.execute('ALTER TABLE item ADD COLUMN quantity_sold INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE item ADD COLUMN quantity_char INTEGER DEFAULT 0');
      } catch (e) {
        // Columns might already exist, ignore error
        print("Migration note: $e");
      }
    }
    if (oldVersion < 6) {
      // Add code_article column to item table
      try {
        await db.execute('ALTER TABLE item ADD COLUMN code_article TEXT');
      } catch (e) {
        // Column might already exist, ignore error
        print("Migration note: $e");
      }
    }
    if (oldVersion < 7) {
      // Add num_bl column to item table
      try {
        await db.execute('ALTER TABLE item ADD COLUMN num_bl TEXT');
      } catch (e) {
        // Column might already exist, ignore error
        print("Migration note: $e");
      }
    }
    if (oldVersion < 10) {
      // Ensure quantity_units and quantity_cartons exist (added in v9 but missed in v9 onCreate)
      try {
        await db.execute('ALTER TABLE sold_items ADD COLUMN quantity_units INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE sold_items ADD COLUMN quantity_cartons INTEGER DEFAULT 0');
      } catch (e) {
        // Columns might already exist, ignore error
        print("Migration note: $e");
      }
    }
    if (oldVersion < 11) {
      // Add solde_init column to clients table
      try {
        await db.execute('ALTER TABLE clients ADD COLUMN solde_init REAL DEFAULT 0.0');
        // Initialize solde_init with current solde for existing clients
        await db.execute('UPDATE clients SET solde_init = solde');
      } catch (e) {
        print("Migration note: $e");
      }
    }
    if (oldVersion < 12) {
      // Add payment_method column to sold table if missing
      try {
        await db.execute('ALTER TABLE sold ADD COLUMN payment_method TEXT');
      } catch (e) {
        print("Migration note: $e");
      }
    }
    if (oldVersion < 13) {
      // Add designation column to sold_items table if missing
      try {
        await db.execute('ALTER TABLE sold_items ADD COLUMN designation TEXT');
      } catch (e) {
        print("Migration note: $e");
      }
    }
  }

  void _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE users (
      id_user INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT,
      password TEXT,
      route TEXT,
      date_creation TEXT,
      date_modification TEXT
    )
  ''');

    await db.execute('''
    CREATE TABLE clients (
      id_client INTEGER PRIMARY KEY AUTOINCREMENT,
      nom TEXT,
      tel TEXT,
      type_client TEXT,
      commune TEXT,
      cite TEXT,
      id_route INTEGER,
      etat TEXT,
      latitude TEXT,
      longitude TEXT,
      solde REAL DEFAULT 0.0,
      solde_init REAL DEFAULT 0.0,
      ca REAL DEFAULT 0.0,
      vers REAL DEFAULT 0.0,
      code TEXT,
      email TEXT,
      FOREIGN KEY (id_route) REFERENCES route (id_route)
    )
  ''');

    await db.execute('''
    CREATE TABLE item (
      id_item INTEGER PRIMARY KEY AUTOINCREMENT,
      item_name TEXT NOT NULL,
      description TEXT,
      unit_price REAL NOT NULL,
      stock_quantity INTEGER,
      category TEXT,
      code_article TEXT,
      pu_art_gros REAL DEFAULT 0.0,
      nbre_colis INTEGER DEFAULT 0,
      cond INTEGER DEFAULT 0,
      quantity_sold INTEGER DEFAULT 0,
      quantity_char INTEGER DEFAULT 0,
      num_bl TEXT,
      created_at TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
      updated_at TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now'))
    )
  ''');

    await db.execute('''
      CREATE TABLE sold (
        id_sale INTEGER PRIMARY KEY,
        id_client INTEGER,
        id_user INTEGER,
        sale_date TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
        total_amount REAL NOT NULL,
        payment_amount REAL DEFAULT 0.0,
        payment_method TEXT,
        payment_status TEXT,
        discount REAL DEFAULT 0.00,
        tax REAL DEFAULT 0.00,
        notes TEXT,
        FOREIGN KEY (id_client) REFERENCES clients(id_client),
        FOREIGN KEY (id_user) REFERENCES users(id_user)
      )
    ''');

    // Create the 'sold_items' table
    await db.execute('''
      CREATE TABLE sold_items (
        id_sold_item INTEGER PRIMARY KEY,
        id_sale INTEGER,
        id_item INTEGER,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        quantity_units INTEGER DEFAULT 0,
        quantity_cartons INTEGER DEFAULT 0,
        designation TEXT,
        FOREIGN KEY (id_sale) REFERENCES sold(id_sale),
        FOREIGN KEY (id_item) REFERENCES item(id_item)
      )
    ''');

    await db.execute('''
    CREATE TABLE route (
      id_route INTEGER PRIMARY KEY AUTOINCREMENT,
      id_commune INTEGER,
      FOREIGN KEY (id_commune) REFERENCES commune (id_commune)
    )
  ''');

    await db.execute('''
    CREATE TABLE commune (
      id_commune INTEGER PRIMARY KEY AUTOINCREMENT,
      commune TEXT,
      cite TEXT,
      code_postal TEXT
    )
  ''');

    await db.execute('''
    CREATE TABLE vans (
      id_van INTEGER PRIMARY KEY AUTOINCREMENT,
      van_name TEXT,
      id_user INTEGER,
      encaissement REAL DEFAULT 0.0,
      chiffre_affaire REAL DEFAULT 0.0,
      FOREIGN KEY (id_user) REFERENCES users(id_user)
    )
  ''');

    await db.execute('''
    CREATE TABLE depots (
      id_depot INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      id_van INTEGER,
      FOREIGN KEY (id_van) REFERENCES vans(id_van)
    )
  ''');

    await db.execute('''
    CREATE TABLE depot_items (
      id_depot_item INTEGER PRIMARY KEY AUTOINCREMENT,
      id_depot INTEGER,
      id_item INTEGER,
      quantity INTEGER DEFAULT 0,
      quantity_livre INTEGER DEFAULT 0,
      FOREIGN KEY (id_depot) REFERENCES depots(id_depot),
      FOREIGN KEY (id_item) REFERENCES item(id_item)
    )
  ''');

    await db.execute('''
    CREATE TABLE payments (
      id_payment INTEGER PRIMARY KEY AUTOINCREMENT,
      id_client INTEGER,
      amount REAL,
      date TEXT,
      method TEXT,
      reference TEXT,
      FOREIGN KEY (id_client) REFERENCES clients(id_client)
    )
  ''');

    await db.execute('''
    CREATE TABLE categories (
      id_category INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE
    )
  ''');

    await db.execute('''
    CREATE TABLE clotures_history (
      id_cloture INTEGER PRIMARY KEY AUTOINCREMENT,
      cloture_date TEXT NOT NULL,
      montant REAL DEFAULT 0.0,
      encaissement REAL DEFAULT 0.0,
      chiffre_affaire REAL DEFAULT 0.0,
      created_at TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now'))
    )
  ''');

    // Insert the default user after creating the tables
    // Insert default admin user
    await db.insert('users', {
      'nom': 'admin',
      'password': '123',
      'route': 'Route 1, Route 2',
      'date_creation': DateTime.now().toString(),
      'date_modification': DateTime.now().toString(),
    });
    
    // Default data removed as per request (vans, depots, items)
    //print("Admin user inserted into the database.");
  }

  Future<int> insertClient(Map<String, dynamic> client) async {
    Database db = await database;

    // Insert into the 'clients' table
    int result = await db.insert('clients', {
      'nom': client['nom'],
      'tel': client['telephone'],
      'type_client': client['type_client'],
      'commune': client['commune'],
      'latitude': client['Latitude'],
      'longitude': client['Longitude'],
      'cite': client['cite'],
      'etat': 'non validé', // You can set default or get from input
      'id_route': client[
          'id_route'], // This value can be from another table, update accordingly
      'code': client['code'] ?? '',
      'email': client['email'] ?? '',
      'solde': client['solde'] ?? 0.0,
      'solde_init': client['solde'] ?? 0.0,
    });

    print("Insert result: $result"); // Debugging: Log the result of the insert
    return result;
  }

  // Method to update a client
  Future<int> updateClient(Map<String, dynamic> client) async {
    final db = await database;
    return await db.update(
      'clients',
      client,
      where: 'id_client = ?', // Correct the 'id_client' column name
      whereArgs: [client['id_client']], // Use the correct id field
    );
  }

  // Method to delete a client
  Future<void> deleteClient(int id) async {
    final db = await database;
    await db.delete(
      'clients',
      where: 'id_client = ?', // Correct the 'id_client' column name
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    Database db = await database;
    return await db.query('clients');
  }

  Future<String> getNextClientCode() async {
    Database db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('SELECT MAX(CAST(code AS INTEGER)) as max_code FROM clients');
    int maxCode = 0;
    if (result.isNotEmpty && result.first['max_code'] != null) {
      maxCode = result.first['max_code'] as int;
    }
    return (maxCode + 1).toString();
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    Database db = await database;
    return await db.query('users');
  }

  Future<int> addLocalUser({
    required String name,
    required String password,
    String route = '',
  }) async {
    final db = await database;
    final now = DateTime.now().toString();
    return db.insert('users', {
      'nom': name,
      'password': password,
      'route': route,
      'date_creation': now,
      'date_modification': now,
    });
  }

  // Authentication
  Future<Map<String, dynamic>?> authenticateUser(
      String username, String password) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'nom = ? AND password = ?',
      whereArgs: [username, password],
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // Van Management
  Future<Map<String, dynamic>?> getVanByUserId(int userId) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'vans',
      where: 'id_user = ?',
      whereArgs: [userId],
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<void> updateVanStats(
      int vanId, double encaissement, double chiffreAffaire) async {
    Database db = await database;
    await db.update(
      'vans',
      {
        'encaissement': encaissement,
        'chiffre_affaire': chiffreAffaire,
      },
      where: 'id_van = ?',
      whereArgs: [vanId],
    );
  }
  
  Future<void> resetVanStats(int vanId) async {
    Database db = await database;
    await db.update(
      'vans',
      {
        'encaissement': 0.0,
        'chiffre_affaire': 0.0,
      },
      where: 'id_van = ?',
      whereArgs: [vanId],
    );
  }

  // Stock Management (Placeholder - assuming items are linked to vans or global stock)
  Future<List<Map<String, dynamic>>> getItems() async {
    Database db = await database;
    return await db.query('item');
  }

  Future<int> addItem(Map<String, dynamic> item) async {
    Database db = await database;
    return await db.insert('item', item);
  }

  Future<int> updateItem(Map<String, dynamic> item) async {
    Database db = await database;
    return await db.update(
      'item',
      item,
      where: 'id_item = ?',
      whereArgs: [item['id_item']],
    );
  }

  Future<void> deleteItem(int id) async {
    Database db = await database;
    await db.delete(
      'item',
      where: 'id_item = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllItems() async {
    Database db = await database;
    await db.delete('item');
    // Also clear depot_items since they refer to these items
    await db.delete('depot_items');
  }

  // Category Management
  Future<int> addCategory(String name) async {
    Database db = await database;
    return await db.insert('categories', {'name': name});
  }

  Future<List<String>> getCategories() async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query('categories');
    return results.map((c) => c['name'] as String).toList();
  }

  // Depot Management
  Future<List<Map<String, dynamic>>> getDepots(int vanId) async {
    Database db = await database;
    return await db.query('depots', where: 'id_van = ?', whereArgs: [vanId]);
  }

  Future<List<Map<String, dynamic>>> getDepotItems(int depotId) async {
    Database db = await database;
    // Join with item table to get item details
    return await db.rawQuery('''
      SELECT di.*, i.item_name, i.item_name as designation, i.item_name as DESIGNATION, i.unit_price, i.code_article, i.code_article as COD_ARTICLE, i.pu_art_gros, i.cond, i.nbre_colis, i.id_item
      FROM depot_items di
      INNER JOIN item i ON di.id_item = i.id_item
      WHERE di.id_depot = ?
    ''', [depotId]);
  }

  // Update depot item quantities (quantity and/or quantity_livre)
  Future<void> updateDepotItem(int depotItemId,
      {int? quantity, int? quantityLivre}) async {
    Database db = await database;
    Map<String, dynamic> updates = {};
    if (quantity != null) updates['quantity'] = quantity;
    if (quantityLivre != null) updates['quantity_livre'] = quantityLivre;
    if (updates.isNotEmpty) {
      await db.update('depot_items', updates,
          where: 'id_depot_item = ?', whereArgs: [depotItemId]);
    }
  }

  // Update item stock quantity
  Future<void> updateItemStock(int itemId,
      {int? quantityUnits, int? quantityCartons}) async {
    Database db = await database;
    // Get current item
    List<Map<String, dynamic>> results =
        await db.query('item', where: 'id_item = ?', whereArgs: [itemId]);
    if (results.isEmpty) return;

    Map<String, dynamic> item = results.first;
    Map<String, dynamic> updates = {};

    // Update stock_quantity (units) if provided
    if (quantityUnits != null) {
      int currentStock = (item['stock_quantity'] as int?) ?? 0;
      int newStock =
          (currentStock - quantityUnits).clamp(0, double.infinity).toInt();
      updates['stock_quantity'] = newStock;
    }

    // Update nbre_colis (cartons) if provided
    if (quantityCartons != null) {
      int currentCartons = (item['nbre_colis'] as int?) ?? 0;
      int newCartons =
          (currentCartons - quantityCartons).clamp(0, double.infinity).toInt();
      updates['nbre_colis'] = newCartons;
      // Also update stock_quantity based on cartons (cartons * cond)
      int cond = (item['cond'] as int?) ?? 0;
      if (cond > 0) {
        int currentStock = (item['stock_quantity'] as int?) ?? 0;
        int unitsToRemove = quantityCartons * cond;
        int newStock =
            (currentStock - unitsToRemove).clamp(0, double.infinity).toInt();
        updates['stock_quantity'] = newStock;
      }
    }

    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await db
          .update('item', updates, where: 'id_item = ?', whereArgs: [itemId]);
    }
  }

  // Sales Management
  Future<int> addSale(
      Map<String, dynamic> saleData, List<Map<String, dynamic>> items) async {
    Database db = await database;
    int saleId = 0;
    await db.transaction((txn) async {
      saleId = await txn.insert('sold', saleData);
      for (var item in items) {
        // Extract stock update info before inserting (these fields don't exist in sold_items table)
        int? quantityUnits = item['quantity_units'] as int?;
        int? quantityCartons = item['quantity_cartons'] as int?;
        
        // Create a copy without quantity_units and quantity_cartons for database insert
        Map<String, dynamic> itemForInsert = Map<String, dynamic>.from(item);
        // We now want to save these fields, so do not remove them
        // itemForInsert.remove('quantity_units');
        // itemForInsert.remove('quantity_cartons');
        itemForInsert['id_sale'] = saleId;
        
        await txn.insert('sold_items', itemForInsert);
        
        // Update item stock quantity
        int? itemId = item['id_item'] as int?;
        if (itemId != null) {
          // Check if it's units or cartons
          if (quantityUnits != null || quantityCartons != null) {
            // Get current item to update
            List<Map<String, dynamic>> itemResults = await txn
                .query('item', where: 'id_item = ?', whereArgs: [itemId]);
            if (itemResults.isNotEmpty) {
              Map<String, dynamic> currentItem = itemResults.first;
              Map<String, dynamic> updates = {};

              if (quantityUnits != null) {
                int currentStock = (currentItem['stock_quantity'] as int?) ?? 0;
                int newStock = (currentStock - quantityUnits)
                    .clamp(0, double.infinity)
                    .toInt();
                updates['stock_quantity'] = newStock;
                
                // Increment quantity_sold
                int currentSold = (currentItem['quantity_sold'] as int?) ?? 0;
                updates['quantity_sold'] = currentSold + quantityUnits;
              }

              if (quantityCartons != null) {
                int currentCartons = (currentItem['nbre_colis'] as int?) ?? 0;
                int newCartons = (currentCartons - quantityCartons)
                    .clamp(0, double.infinity)
                    .toInt();
                updates['nbre_colis'] = newCartons;
                // Also reduce stock_quantity by cartons * cond
                int cond = (currentItem['cond'] as int?) ?? 0;
                if (cond > 0) {
                  int currentStock =
                      (currentItem['stock_quantity'] as int?) ?? 0;
                  int unitsToRemove = quantityCartons * cond;
                  int newStock = (currentStock - unitsToRemove)
                      .clamp(0, double.infinity)
                      .toInt();
                  updates['stock_quantity'] = newStock;
                  
                  // Increment quantity_sold by units from cartons
                  int currentSold = (currentItem['quantity_sold'] as int?) ?? 0;
                  updates['quantity_sold'] = currentSold + unitsToRemove;
                }
              }

              if (updates.isNotEmpty) {
                updates['updated_at'] = DateTime.now().toIso8601String();
                await txn.update('item', updates,
                    where: 'id_item = ?', whereArgs: [itemId]);
              }
            }
          }
        }
      }
    });
    return saleId;
  }

  Future<List<Map<String, dynamic>>> getSalesForClient(int clientId) async {
    Database db = await database;
    return await db.query('sold',
        where: 'id_client = ?',
        whereArgs: [clientId],
        orderBy: 'sale_date DESC');
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    Database db = await database;
    // Join with item table to get item names
    return await db.rawQuery('''
      SELECT si.*, COALESCE(i.item_name, si.designation, 'N/A') as item_name, 
             COALESCE(i.item_name, si.designation, 'N/A') as designation, 
             i.pu_art_gros, i.unit_price as item_unit_price, si.quantity_units, si.quantity_cartons, i.code_article
      FROM sold_items si
      LEFT JOIN item i ON si.id_item = i.id_item
      WHERE si.id_sale = ?
      ORDER BY si.id_sold_item
    ''', [saleId]);
  }

  // Payment Management
  Future<int> addPayment(Map<String, dynamic> paymentData) async {
    Database db = await database;
    return await db.insert('payments', paymentData);
  }

  Future<List<Map<String, dynamic>>> getPaymentsForClient(int clientId) async {
    Database db = await database;
    return await db.query('payments',
        where: 'id_client = ?', whereArgs: [clientId], orderBy: 'date DESC');
  }

  // Client Financials
  Future<void> updateClientFinancials(int clientId,
      {double? solde, double? ca, double? vers}) async {
    Database db = await database;
    Map<String, dynamic> updates = {};
    if (solde != null) updates['solde'] = solde;
    if (ca != null) updates['ca'] = ca;
    if (vers != null) updates['vers'] = vers;
    
    if (updates.isNotEmpty) {
      // Ensure solde_init is never updated through this method
      updates.remove('solde_init');
      
      await db.update('clients', updates,
          where: 'id_client = ?', whereArgs: [clientId]);
    }
  }

  Future<Map<String, dynamic>?> getClient(int clientId) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db
        .query('clients', where: 'id_client = ?', whereArgs: [clientId]);
    return results.isNotEmpty ? results.first : null;
  }

  // Clotures History Management
  Future<int> addCloture({
    required String clotureDate,
    required double montant,
    required double encaissement,
    required double chiffreAffaire,
  }) async {
    Database db = await database;
    return await db.insert('clotures_history', {
      'cloture_date': clotureDate,
      'montant': montant,
      'encaissement': encaissement,
      'chiffre_affaire': chiffreAffaire,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> resetInventoryTracking() async {
    Database db = await database;
    await db.rawUpdate('''
      UPDATE item 
      SET quantity_sold = 0, quantity_char = 0
    ''');
  }

  Future<List<Map<String, dynamic>>> getCloturesHistory() async {
    Database db = await database;
    return await db.query('clotures_history', orderBy: 'cloture_date DESC');
  }

  // Export Data Helpers
  Future<List<Map<String, dynamic>>> getSalesByDate(String date) async {
    Database db = await database;
    // Query for sales on the specific date (matching the YYYY-MM-DD part)
    return await db.query('sold',
        where: 'date(sale_date) = date(?)',
        whereArgs: [date],
        orderBy: 'sale_date ASC');
  }

  Future<List<Map<String, dynamic>>> getPaymentsByDate(String date) async {
    Database db = await database;
    // Query for payments on the specific date
    return await db.query('payments',
        where: 'date(date) = date(?)',
        whereArgs: [date],
        orderBy: 'date ASC');
  }

  Future<List<Map<String, dynamic>>> getClientsByIds(List<int> clientIds) async {
    if (clientIds.isEmpty) return [];
    Database db = await database;
    String ids = clientIds.join(',');
    return await db.rawQuery('SELECT * FROM clients WHERE id_client IN ($ids)');
  }
  
  Future<List<Map<String, dynamic>>> getAllSaleItemsForSales(List<int> saleIds) async {
    if (saleIds.isEmpty) return [];
    Database db = await database;
    String ids = saleIds.join(',');
    // Join with item table to get item codes
    return await db.rawQuery('''
      SELECT si.*, i.code_article, i.item_name 
      FROM sold_items si
      INNER JOIN item i ON si.id_item = i.id_item
      WHERE si.id_sale IN ($ids)
    ''');
  }

  Future<List<Map<String, dynamic>>> getSalesExportData(String date) async {
    Database db = await database;
    // Join sold, sold_items, item, and clients to get all required fields
    // Fields: id_client, code (as code_cl), id_sale, id_user, num_bl, sale_date,
    // code_article, tax, cond, designation (item_name), nbre_colis, 
    // quantity_sold (stock_quantity in export), unit_price, pu_art_gros, discount,
    // total_amount (sale), payment_amount (paid in sale), tel, type_client, commune, cite
    return await db.rawQuery('''
      SELECT 
        s.id_client, 
        c.code as code_cl, 
        c.nom as nom_cl,
        c.tel,
        c.type_client,
        c.commune,
        c.cite,
        c.solde,
        c.solde_init,
        s.id_sale, 
        s.id_user, 
        s.sale_date, 
        s.total_amount,
        s.tax, 
        s.discount,
        s.payment_status,
        i.num_bl,
        i.code_article, 
        i.cond, 
        i.item_name as designation, 
        si.quantity as quantity_sold, 
        si.unit_price, 
        i.pu_art_gros,
        i.stock_quantity,
        i.quantity_char,
        i.quantity_sold,
        s.payment_amount,
        s.payment_method
      FROM sold s
      JOIN sold_items si ON s.id_sale = si.id_sale
      JOIN item i ON si.id_item = i.id_item
      LEFT JOIN clients c ON s.id_client = c.id_client
      WHERE date(s.sale_date) = date(?)
      ORDER BY s.sale_date ASC
    ''', [date]);
  }

  Future<List<Map<String, dynamic>>> getPaymentsExportData(String date) async {
    Database db = await database;
    // Get standalone payments for the date
    return await db.rawQuery('''
      SELECT 
        p.id_payment,
        p.amount as reglement,
        p.date as payment_date,
        p.method,
        p.id_client,
        c.code as code_cl,
        c.nom as nom_cl,
        c.tel,
        c.type_client,
        c.commune,
        c.cite,
        c.solde,
        c.solde_init
      FROM payments p
      LEFT JOIN clients c ON p.id_client = c.id_client
      WHERE date(p.date) = date(?)
      ORDER BY p.date ASC
    ''', [date]);
  }

  // Export/Import Database
  Future<String> getDatabasePath() async {
    return join(await getDatabasesPath(), 'clients.db');
  }
}
