enum ItemType { text, link, image, file }

class Item {
  final String id;
  final ItemType type;
  final String content;
  final String? filePath;
  final String? fileName;
  final DateTime createdAt;

  Item({
    required this.id,
    required this.type,
    required this.content,
    this.filePath,
    this.fileName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'content': content,
    'file_path': filePath,
    'file_name': fileName,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static Item fromMap(Map<String, dynamic> m) => Item(
    id: m['id'],
    type: ItemType.values.byName(m['type']),
    content: m['content'],
    filePath: m['file_path'],
    fileName: m['file_name'],
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']),
  );
}