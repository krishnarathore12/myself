import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'item.dart';

class DB {
  static Database? _db;

  static Future<Database> get() async {
    if (_db != null) return _db!;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'myself.db');

    final factory = Platform.isAndroid || Platform.isIOS
        ? databaseFactory
        : databaseFactoryFfi;

    _db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE items (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              content TEXT NOT NULL,
              file_path TEXT,
              file_name TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    return _db!;
  }

  static Future<void> insert(Item item) async {
    final db = await get();
    await db.insert('items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Item>> all() async {
    final db = await get();
    final rows = await db.query('items', orderBy: 'created_at DESC');
    return rows.map(Item.fromMap).toList();
  }

  static Future<void> delete(String id) async {
    final db = await get();
    await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }
}