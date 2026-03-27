import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/item.dart';

class ItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onDelete;

  const ItemCard({super.key, required this.item, required this.onDelete});

  IconData get _icon => switch (item.type) {
        ItemType.text => Icons.notes,
        ItemType.link => Icons.link,
        ItemType.image => Icons.image_outlined,
        ItemType.file => Icons.insert_drive_file_outlined,
      };

  String get _timeAgo {
    final diff = DateTime.now().difference(item.createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      color: theme.colorScheme.surface.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(_timeAgo,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          )),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
            if (item.type == ItemType.image && item.filePath != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(item.filePath!), fit: BoxFit.cover),
                ),
              ),
            if (item.type == ItemType.file && item.fileName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('File: ${item.fileName!}',
                    style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
