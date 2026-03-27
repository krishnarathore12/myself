import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/item.dart';

class ItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onDelete;

  const ItemCard({super.key, required this.item, required this.onDelete});

  IconData get _icon => switch (item.type) {
    ItemType.text  => Icons.notes,
    ItemType.link  => Icons.link,
    ItemType.image => Icons.image_outlined,
    ItemType.file  => Icons.insert_drive_file_outlined,
  };

  String get _timeAgo {
    final diff = DateTime.now().difference(item.createdAt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inHours < 1)    return '${diff.inMinutes}m ago';
    if (diff.inDays < 1)     return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(_icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          item.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(_timeAgo,
            style: TextStyle(color: Colors.white.withOpacity(0.4),
                fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDelete,
        ),
        // Show image preview if it's an image
        isThreeLine: item.type == ItemType.image && item.filePath != null,
      ),
    );
  }
}