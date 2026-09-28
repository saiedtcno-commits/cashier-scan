import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'cashier_scan.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          barcode TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          price REAL NOT NULL
        )
      ''');
      await db.insert('products', {'barcode': '6223000550012', 'name': 'مياه معدنية', 'price': 10.0});
      await db.insert('products', {'barcode': '6224000000011', 'name': 'عصير مانجو', 'price': 25.0});
    });
    return _db!;
  }

  Future<List<Product>> getProducts([String query = '']) async {
    final db = await database;
    final q = query.trim();
    final rows = q.isEmpty
        ? await db.query('products', orderBy: 'name COLLATE NOCASE')
        : await db.query('products',
            where: 'name LIKE ? OR barcode LIKE ?',
            whereArgs: ['%$q%', '%$q%'],
            orderBy: 'name COLLATE NOCASE');
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> findByBarcode(String barcode) async {
    final db = await database;
    final rows = await db.query('products', where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return db.insert('products', product.toMap()..remove('id'));
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return db.update('products', product.toMap()..remove('id'), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }
}
