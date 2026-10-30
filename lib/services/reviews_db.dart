import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/review.dart';
import 'review_service.dart';

// Persistent cache of the reviews (slides 14 - Local Storage). Relational because the data is structured:
// 1 restaurant -> N reviews, always read by restaurant and ordered by date.
// Its own file (not LocalDb) so its schema and migrations never collide with the Saved module
class ReviewsDb {
  // I keep the Future of the opening, not the Database: two simultaneous first calls share one opening
  static Future<Database>? _opening;
  static Future<Database> get _database => _opening ??= _open();

  static Future<Database> _open() async {
    return openDatabase(
      join(await getDatabasesPath(), 'reviews_cache.db'),
      version: 1,
      // SQLite ships with foreign keys OFF; without this ON DELETE CASCADE does nothing
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE restaurant_reviews_meta (
            restaurant_id TEXT PRIMARY KEY,
            rating        REAL,
            review_count  INTEGER NOT NULL,
            synced_at     TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE reviews (
            id              TEXT PRIMARY KEY,
            restaurant_id   TEXT NOT NULL REFERENCES restaurant_reviews_meta(restaurant_id) ON DELETE CASCADE,
            author          TEXT NOT NULL,
            created_at      TEXT NOT NULL,
            taste           INTEGER NOT NULL,
            attention       INTEGER NOT NULL,
            price           INTEGER NOT NULL,
            options         INTEGER NOT NULL,
            dietary_options TEXT NOT NULL,
            comment         TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_reviews_restaurant_date ON reviews(restaurant_id, created_at DESC)');
      },
    );
  }

  // One transaction: if the app dies in the middle, the old copy stays whole instead of a half-written list
  static Future<void> save(String restaurantId, RatingSummary summary, List<Review> reviews) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert(
        'restaurant_reviews_meta',
        {
          'restaurant_id': restaurantId,
          'rating': summary.rating,
          'review_count': summary.count,
          'synced_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('reviews', where: 'restaurant_id = ?', whereArgs: [restaurantId]);
      final batch = txn.batch();
      for (final r in reviews) {
        batch.insert('reviews', {
          'id': r.id,
          'restaurant_id': restaurantId,
          'author': r.author,
          'created_at': r.date.toUtc().toIso8601String(),
          'taste': r.ratings.taste,
          'attention': r.ratings.attention,
          'price': r.ratings.price,
          'options': r.ratings.options,
          'dietary_options': jsonEncode(r.dietaryOptions), // SQLite has no array type
          'comment': r.comment,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  // Same shape as the backend's JSON, so RatingSummary.fromJson and Review.fromJson parse it with no extra code
  static Future<Map<String, dynamic>?> read(String restaurantId) async {
    final db = await _database;
    final meta = await db.query('restaurant_reviews_meta', where: 'restaurant_id = ?', whereArgs: [restaurantId]);
    if (meta.isEmpty) return null;
    final rows = await db.query(
      'reviews',
      where: 'restaurant_id = ?',
      whereArgs: [restaurantId],
      orderBy: 'created_at DESC',
    );
    return {
      'restaurant_id': restaurantId,
      'rating': meta.first['rating'],
      'review_count': meta.first['review_count'],
      'synced_at': meta.first['synced_at'],
      'reviews': [
        for (final row in rows) {...row, 'dietary_options': jsonDecode(row['dietary_options'] as String)},
      ],
    };
  }

  static Future<void> clear() async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('reviews');
      await txn.delete('restaurant_reviews_meta');
    });
  }
}
