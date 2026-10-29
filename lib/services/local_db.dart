import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  static Database? _db;

  static Future<Database> get _database async {
    _db ??= await openDatabase(
      join(await getDatabasesPath(), 'campus_eats_local.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE saved_restaurants (
            restaurant_id TEXT PRIMARY KEY,
            saved_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  static Future<Set<String>> getSavedIds() async {
    final db = await _database;
    final rows = await db.query('saved_restaurants', orderBy: 'saved_at DESC');
    return rows.map((r) => r['restaurant_id'] as String).toSet();
  }

  static Future<void> replaceSavedIds(Set<String> ids) async {
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('saved_restaurants');
      for (final id in ids) {
        await txn.insert('saved_restaurants', {'restaurant_id': id, 'saved_at': now});
      }
    });
  }

  static Future<void> addSaved(String restaurantId) async {
    final db = await _database;
    await db.insert(
      'saved_restaurants',
      {'restaurant_id': restaurantId, 'saved_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> removeSaved(String restaurantId) async {
    final db = await _database;
    await db.delete('saved_restaurants', where: 'restaurant_id = ?', whereArgs: [restaurantId]);
  }

  static Future<void> clearSaved() async {
    final db = await _database;
    await db.delete('saved_restaurants');
  }
}
