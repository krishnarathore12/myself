import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../data/item.dart';
import '../data/db.dart';
import '../data/capture_service.dart';
import 'widgets/item_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Item> _items = [];
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    // ShareHandler.init(_load);  
  }

  Future<void> _load() async {
    final items = await DB.all();
    setState(() => _items = items);
  }

  Future<void> _captureText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    await CaptureService.fromText(text);
    _textController.clear();
    await _load();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    final file = result.files.single;
    if (file.path == null) return;
    await CaptureService.fromFile(file.path!, file.name);
    await _load();
  }

  Future<void> _delete(String id) async {
    await DB.delete(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Myself'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Capture bar at top
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Paste text, URL, or type a note...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _captureText(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: _captureText,
                  tooltip: 'Save',
                ),
                const SizedBox(width: 4),
                IconButton.outlined(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _pickFile,
                  tooltip: 'Pick file',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Feed
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('Nothing saved yet.\nPaste a link or type a note.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) => ItemCard(
                      item: _items[i],
                      onDelete: () => _delete(_items[i].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}