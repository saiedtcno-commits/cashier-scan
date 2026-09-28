import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/product.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  // ============================================================
  // DATABASE
  // ============================================================

  Future<Database> get database async {
    if (_db != null) return _db!;

    final path = join(
      await getDatabasesPath(),
      'cashier_scan.db',
    );

    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createDatabase(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToVersion2(db);
        }
      },
    );

    return _db!;
  }

  // ============================================================
  // CREATE DATABASE
  // ============================================================

  Future<void> _createDatabase(Database db) async {
    // ----------------------------------------------------------
    // PRODUCTS
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity REAL NOT NULL DEFAULT 0
      )
    ''');

    // ----------------------------------------------------------
    // INVOICES
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number INTEGER NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0
      )
    ''');

    // ----------------------------------------------------------
    // INVOICE ITEMS
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        barcode TEXT NOT NULL,
        product_name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity REAL NOT NULL,
        line_total REAL NOT NULL,

        FOREIGN KEY (invoice_id)
          REFERENCES invoices(id)
          ON DELETE CASCADE
      )
    ''');

    // ----------------------------------------------------------
    // STOCK MOVEMENTS
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        created_at TEXT NOT NULL,
        note TEXT,

        FOREIGN KEY (product_id)
          REFERENCES products(id)
          ON DELETE CASCADE
      )
    ''');

    // ----------------------------------------------------------
    // INDEXES
    // ----------------------------------------------------------

    await db.execute('''
      CREATE INDEX idx_products_barcode
      ON products(barcode)
    ''');

    await db.execute('''
      CREATE INDEX idx_invoices_created_at
      ON invoices(created_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_invoice_items_invoice_id
      ON invoice_items(invoice_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_stock_movements_product_id
      ON stock_movements(product_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_stock_movements_created_at
      ON stock_movements(created_at)
    ''');

    // ----------------------------------------------------------
    // SAMPLE PRODUCTS
    // ----------------------------------------------------------

    await db.insert(
      'products',
      {
        'barcode': '6223000550012',
        'name': 'مياه معدنية',
        'price': 10.0,
        'quantity': 100.0,
      },
    );

    await db.insert(
      'products',
      {
        'barcode': '6224000000011',
        'name': 'عصير مانجو',
        'price': 25.0,
        'quantity': 100.0,
      },
    );
  }

  // ============================================================
  // DATABASE UPGRADE
  // Version 1 → Version 2
  // ============================================================

  Future<void> _upgradeToVersion2(Database db) async {
    // ----------------------------------------------------------
    // Add quantity to existing products
    // ----------------------------------------------------------

    await db.execute('''
      ALTER TABLE products
      ADD COLUMN quantity REAL NOT NULL DEFAULT 0
    ''');

    // ----------------------------------------------------------
    // INVOICES
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number INTEGER NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0
      )
    ''');

    // ----------------------------------------------------------
    // INVOICE ITEMS
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        barcode TEXT NOT NULL,
        product_name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity REAL NOT NULL,
        line_total REAL NOT NULL,

        FOREIGN KEY (invoice_id)
          REFERENCES invoices(id)
          ON DELETE CASCADE
      )
    ''');

    // ----------------------------------------------------------
    // STOCK MOVEMENTS
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        created_at TEXT NOT NULL,
        note TEXT,

        FOREIGN KEY (product_id)
          REFERENCES products(id)
          ON DELETE CASCADE
      )
    ''');

    // ----------------------------------------------------------
    // INDEXES
    // ----------------------------------------------------------

    await db.execute('''
      CREATE INDEX idx_products_barcode
      ON products(barcode)
    ''');

    await db.execute('''
      CREATE INDEX idx_invoices_created_at
      ON invoices(created_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_invoice_items_invoice_id
      ON invoice_items(invoice_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_stock_movements_product_id
      ON stock_movements(product_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_stock_movements_created_at
      ON stock_movements(created_at)
    ''');
  }

  // ============================================================
  // PRODUCTS
  // ============================================================

  Future<List<Product>> getProducts([
    String query = '',
  ]) async {
    final db = await database;

    final q = query.trim();

    final rows = q.isEmpty
        ? await db.query(
            'products',
            orderBy: 'name COLLATE NOCASE',
          )
        : await db.query(
            'products',
            where: 'name LIKE ? OR barcode LIKE ?',
            whereArgs: [
              '%$q%',
              '%$q%',
            ],
            orderBy: 'name COLLATE NOCASE',
          );

    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> findByBarcode(
    String barcode,
  ) async {
    final db = await database;

    final rows = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );

    return rows.isEmpty
        ? null
        : Product.fromMap(rows.first);
  }

  Future<int> insertProduct(
    Product product,
  ) async {
    final db = await database;

    final data = product.toMap()
      ..remove('id');

    // quantity لو الموديل الحالي لسه مش متحدث
    data.putIfAbsent('quantity', () => 0.0);

    return db.insert(
      'products',
      data,
    );
  }

  Future<int> updateProduct(
    Product product,
  ) async {
    final db = await database;

    final data = product.toMap()
      ..remove('id');

    return db.update(
      'products',
      data,
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(
    int id,
  ) async {
    final db = await database;

    return db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // STOCK
  // ============================================================

  Future<double> getStockQuantity(
    int productId,
  ) async {
    final db = await database;

    final rows = await db.query(
      'products',
      columns: ['quantity'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return 0;
    }

    return (rows.first['quantity'] as num).toDouble();
  }

  Future<void> addStock({
    required int productId,
    required double quantity,
    String? note,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError(
        'Quantity must be greater than zero.',
      );
    }

    final db = await database;

    await db.transaction(
      (txn) async {
        await txn.rawUpdate(
          '''
          UPDATE products
          SET quantity = quantity + ?
          WHERE id = ?
          ''',
          [
            quantity,
            productId,
          ],
        );

        await txn.insert(
          'stock_movements',
          {
            'product_id': productId,
            'type': 'IN',
            'quantity': quantity,
            'created_at':
                DateTime.now().toIso8601String(),
            'note': note,
          },
        );
      },
    );
  }

  Future<void> removeStock({
    required int productId,
    required double quantity,
    String? note,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError(
        'Quantity must be greater than zero.',
      );
    }

    final db = await database;

    await db.transaction(
      (txn) async {
        final rows = await txn.query(
          'products',
          columns: ['quantity'],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );

        if (rows.isEmpty) {
          throw Exception(
            'Product not found.',
          );
        }

        final currentQuantity =
            (rows.first['quantity'] as num)
                .toDouble();

        if (currentQuantity < quantity) {
          throw Exception(
            'الكمية المتاحة غير كافية.',
          );
        }

        await txn.rawUpdate(
          '''
          UPDATE products
          SET quantity = quantity - ?
          WHERE id = ?
          ''',
          [
            quantity,
            productId,
          ],
        );

        await txn.insert(
          'stock_movements',
          {
            'product_id': productId,
            'type': 'OUT',
            'quantity': quantity,
            'created_at':
                DateTime.now().toIso8601String(),
            'note': note,
          },
        );
      },
    );
  }

  // ============================================================
  // STOCK MOVEMENTS
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getStockMovements({
    int? productId,
  }) async {
    final db = await database;

    if (productId == null) {
      return db.query(
        'stock_movements',
        orderBy: 'created_at DESC',
      );
    }

    return db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
  }

  // ============================================================
  // INVOICE NUMBER
  // ============================================================

  Future<int> getNextInvoiceNumber() async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT MAX(invoice_number) AS max_number
      FROM invoices
      ''',
    );

    final maxNumber = rows.first['max_number'];

    if (maxNumber == null) {
      return 1;
    }

    return (maxNumber as num).toInt() + 1;
  }

  // ============================================================
  // SAVE INVOICE
  // ============================================================

  Future<int> saveInvoice({
    required List<Map<String, dynamic>> items,
    required double total,
  }) async {
    final db = await database;

    return db.transaction(
      (txn) async {
        final invoiceNumber =
            await _getNextInvoiceNumber(txn);

        final invoiceId = await txn.insert(
          'invoices',
          {
            'invoice_number': invoiceNumber,
            'created_at':
                DateTime.now().toIso8601String(),
            'total': total,
          },
        );

        for (final item in items) {
          final productId =
              item['product_id'] as int;

          final quantity =
              (item['quantity'] as num).toDouble();

          // Check stock
          final productRows = await txn.query(
            'products',
            columns: [
              'quantity',
            ],
            where: 'id = ?',
            whereArgs: [productId],
            limit: 1,
          );

          if (productRows.isEmpty) {
            throw Exception(
              'Product not found.',
            );
          }

          final currentStock =
              (productRows.first['quantity']
                      as num)
                  .toDouble();

          if (currentStock < quantity) {
            throw Exception(
              'الكمية المتاحة غير كافية للمنتج: '
              '${item['product_name']}',
            );
          }

          // Save invoice item
          await txn.insert(
            'invoice_items',
            {
              'invoice_id': invoiceId,
              'product_id': productId,
              'barcode': item['barcode'],
              'product_name':
                  item['product_name'],
              'price': item['price'],
              'quantity': quantity,
              'line_total':
                  item['line_total'],
            },
          );

          // Decrease stock
          await txn.rawUpdate(
            '''
            UPDATE products
            SET quantity = quantity - ?
            WHERE id = ?
            ''',
            [
              quantity,
              productId,
            ],
          );

          // Stock movement
          await txn.insert(
            'stock_movements',
            {
              'product_id': productId,
              'type': 'SALE',
              'quantity': quantity,
              'created_at':
                  DateTime.now()
                      .toIso8601String(),
              'note':
                  'Invoice #$invoiceNumber',
            },
          );
        }

        return invoiceId;
      },
    );
  }

  Future<int> _getNextInvoiceNumber(
    Transaction txn,
  ) async {
    final rows = await txn.rawQuery(
      '''
      SELECT MAX(invoice_number) AS max_number
      FROM invoices
      ''',
    );

    final maxNumber = rows.first['max_number'];

    if (maxNumber == null) {
      return 1;
    }

    return (maxNumber as num).toInt() + 1;
  }

  // ============================================================
  // INVOICES
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getInvoices({
    String query = '',
  }) async {
    final db = await database;

    final q = query.trim();

    if (q.isEmpty) {
      return db.query(
        'invoices',
        orderBy: 'created_at DESC',
      );
    }

    return db.query(
      'invoices',
      where: 'CAST(invoice_number AS TEXT) LIKE ?',
      whereArgs: ['%$q%'],
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?>
      getInvoice(int invoiceId) async {
    final db = await database;

    final invoices = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );

    if (invoices.isEmpty) {
      return null;
    }

    final items = await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );

    return {
      'invoice': invoices.first,
      'items': items,
    };
  }

  // ============================================================
  // REPORTS
  // ============================================================

  Future<Map<String, dynamic>>
      getSalesReport({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;

    final fromText =
        from.toIso8601String();

    final toText =
        to.toIso8601String();

    final summary = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS invoice_count,
        COALESCE(SUM(total), 0) AS total_sales
      FROM invoices
      WHERE created_at >= ?
        AND created_at <= ?
      ''',
      [
        fromText,
        toText,
      ],
    );

    final items = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(ii.quantity), 0) AS item_count
      FROM invoice_items ii
      INNER JOIN invoices i
        ON i.id = ii.invoice_id
      WHERE i.created_at >= ?
        AND i.created_at <= ?
      ''',
      [
        fromText,
        toText,
      ],
    );

    return {
      'invoice_count':
          (summary.first['invoice_count']
                  as num)
              .toInt(),
      'total_sales':
          (summary.first['total_sales']
                  as num)
              .toDouble(),
      'item_count':
          (items.first['item_count']
                  as num)
              .toDouble(),
    };
  }

  Future<List<Map<String, dynamic>>>
      getTopSellingProducts({
    required DateTime from,
    required DateTime to,
    int limit = 10,
  }) async {
    final db = await database;

    return db.rawQuery(
      '''
      SELECT
        product_id,
        product_name,
        SUM(quantity) AS total_quantity,
        SUM(line_total) AS total_sales
      FROM invoice_items
      INNER JOIN invoices
        ON invoices.id = invoice_items.invoice_id
      WHERE invoices.created_at >= ?
        AND invoices.created_at <= ?
      GROUP BY product_id, product_name
      ORDER BY total_quantity DESC
      LIMIT ?
      ''',
      [
        from.toIso8601String(),
        to.toIso8601String(),
        limit,
      ],
    );
  }
}
