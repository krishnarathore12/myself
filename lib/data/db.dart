import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'item.dart';
import 'paired_device.dart';

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
        version: 3,
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
          await db.execute('''
            CREATE TABLE paired_devices (
              device_id   TEXT PRIMARY KEY,
              name        TEXT NOT NULL,
              last_ip     TEXT NOT NULL,
              last_port   INTEGER DEFAULT 42069,
              paired_at   INTEGER NOT NULL,
              is_trusted  INTEGER DEFAULT 1
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE paired_devices (
                device_id   TEXT PRIMARY KEY,
                name        TEXT NOT NULL,
                last_ip     TEXT NOT NULL,
                last_port   INTEGER DEFAULT 42069,
                paired_at   INTEGER NOT NULL,
                is_trusted  INTEGER DEFAULT 1
              )
            ''');
          }
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE paired_devices ADD COLUMN last_port INTEGER DEFAULT 42069');
          }
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

  static Future<void> insertPairedDevice(PairedDevice device) async {
    final db = await get();
    await db.insert('paired_devices', device.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<PairedDevice>> getPairedDevices() async {
    final db = await get();
    final rows = await db.query('paired_devices', orderBy: 'paired_at DESC');
    return rows.map(PairedDevice.fromMap).toList();
  }

  static Future<void> updatePairedDeviceIp(String deviceId, String newIp) async {
    final db = await get();
    await db.update(
      'paired_devices',
      {'last_ip': newIp},
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }
}