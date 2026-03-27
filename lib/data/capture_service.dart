import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'item.dart';
import 'db.dart';

class CaptureService {
  static const _uuid = Uuid();

  static Future<Item> fromText(String text) async {
    final trimmed = text.trim();
    final type = _isUrl(trimmed) ? ItemType.link : ItemType.text;
    final item = Item(
      id: _uuid.v4(),
      type: type,
      content: trimmed,
      createdAt: DateTime.now(),
    );
    await DB.insert(item);
    return item;
  }

  static Future<Item> fromFile(String sourcePath, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final blobDir = Directory(p.join(dir.path, 'blobs'));
    await blobDir.create(recursive: true);

    final ext = p.extension(fileName).toLowerCase();
    final destPath = p.join(blobDir.path, '${_uuid.v4()}$ext');
    await File(sourcePath).copy(destPath);

    final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext);
    final item = Item(
      id: _uuid.v4(),
      type: isImage ? ItemType.image : ItemType.file,
      content: fileName,
      filePath: destPath,
      fileName: fileName,
      createdAt: DateTime.now(),
    );
    await DB.insert(item);
    return item;
  }

  static bool _isUrl(String text) =>
      text.startsWith('http://') || text.startsWith('https://');
}