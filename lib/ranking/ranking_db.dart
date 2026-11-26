import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'ranking_models.dart';

// LOCAL STORAGE: relational database (SQLite, sqflite) with the last rankings computed on this phone.
// Same idea as the Kotlin LocalStore ranking snapshots.
//
// Why a relational table and not SharedPreferences: a ranking is a list of rows (restaurant, position,
// score, number of reviews) for each criterion and window, and two versions are kept (current and
// previous) to show how many places each restaurant moved. A table with a key per row lets the app
// read exactly one ranking with a WHERE, replace one ranking in a transaction, and keep both versions,
// instead of rewriting a big JSON string every time.
//
// Tables:
//   ranking_rows(criterion, time_window, slot, position, restaurant_id, score, review_count, computed_at)
//     slot 0 = current ranking, 1 = previous one (for the ▲/▼ movement)
//   ranking_meta(key, value): "last_refresh" = when the data was last downloaded from the backend
class RankingDb {
  static const current = 0;
  static const previous = 1;

  static Future<Database>? _opening;
  static Future<Database> get _db => _opening ??= _open();

  static Future<Database> _open() async => openDatabase(
        join(await getDatabasesPath(), 'ranking.db'),
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE ranking_rows(
              criterion TEXT NOT NULL,
              time_window TEXT NOT NULL,
              slot INTEGER NOT NULL,
              position INTEGER NOT NULL,
              restaurant_id TEXT NOT NULL,
              score REAL NOT NULL,
              review_count INTEGER NOT NULL,
              computed_at INTEGER NOT NULL,
              PRIMARY KEY (criterion, time_window, slot, position)
            )''');
          await db.execute('CREATE TABLE ranking_meta(key TEXT PRIMARY KEY, value INTEGER NOT NULL)');
        },
      );

  static Future<StoredRanking?> load(RankingCriterion c, RankingWindow w, int slot) async {
    final rows = await (await _db).query(
      'ranking_rows',
      where: 'criterion = ? AND time_window = ? AND slot = ?',
      whereArgs: [c.name, w.name, slot],
      orderBy: 'position',
    );
    if (rows.isEmpty) return null;
    return StoredRanking(
      rows: [
        for (final r in rows)
          SnapshotRow(
            restaurantId: r['restaurant_id'] as String,
            score: (r['score'] as num).toDouble(),
            reviewCount: r['review_count'] as int,
          ),
      ],
      computedAt: DateTime.fromMillisecondsSinceEpoch(rows.first['computed_at'] as int),
    );
  }

  // Saves a new current ranking. The old current one becomes the previous one (baseline for movement).
  // One transaction: if the app is closed in the middle, the database never has half a ranking
  static Future<void> save(RankingCriterion c, RankingWindow w, List<SnapshotRow> rows, DateTime computedAt) async {
    final db = await _db;
    await db.transaction((txn) async {
      final args = [c.name, w.name];
      await txn.delete('ranking_rows', where: 'criterion = ? AND time_window = ? AND slot = $previous', whereArgs: args);
      await txn.update('ranking_rows', {'slot': previous},
          where: 'criterion = ? AND time_window = ? AND slot = $current', whereArgs: args);
      final batch = txn.batch();
      for (var i = 0; i < rows.length; i++) {
        batch.insert('ranking_rows', {
          'criterion': c.name,
          'time_window': w.name,
          'slot': current,
          'position': i + 1,
          'restaurant_id': rows[i].restaurantId,
          'score': rows[i].score,
          'review_count': rows[i].reviewCount,
          'computed_at': computedAt.millisecondsSinceEpoch,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  static Future<DateTime?> lastRefresh() async {
    final rows = await (await _db).query('ranking_meta', where: 'key = ?', whereArgs: ['last_refresh']);
    return rows.isEmpty ? null : DateTime.fromMillisecondsSinceEpoch(rows.first['value'] as int);
  }

  static Future<void> setLastRefresh(DateTime time) async => (await _db).insert(
        'ranking_meta',
        {'key': 'last_refresh', 'value': time.millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
