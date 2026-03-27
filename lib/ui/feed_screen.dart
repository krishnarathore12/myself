import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../data/item.dart';
import '../data/group.dart';
import '../data/device.dart';
import '../data/db.dart';
import '../data/capture_service.dart';
import '../data/pairing_service.dart';
import '../data/paired_device.dart';
import 'widgets/item_card.dart';
import 'widgets/sidebar.dart';

class FeedScreen extends StatefulWidget {
  final PairingService pairingService;

  const FeedScreen({super.key, required this.pairingService});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _uuid = const Uuid();
  List<Item> _items = [];
  List<PairedDevice> _pairedDevices = [];
  List<PairedDevice> _nearbyDevices = [];
  List<Group> _groups = [];

  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadPairedDevices();
    widget.pairingService.pairedDevicesStream.listen((devices) {
      setState(() => _pairedDevices = devices);
    });
    widget.pairingService.nearbyDevicesStream.listen((devices) {
      setState(() => _nearbyDevices = devices);
    });
  }

  Future<void> _loadPairedDevices() async {
    final devices = await DB.getPairedDevices();
    setState(() => _pairedDevices = devices);
  }

  Future<void> _load() async {
    final items = await DB.all();
    setState(() => _items = items);
  }

  void _createGroup(String name) {
    setState(() {
      _groups.add(Group(id: _uuid.v4(), name: name));
    });
  }

  void _toggleDeviceInGroup(String groupId, String deviceId) {
    setState(() {
      final index = _groups.indexWhere((g) => g.id == groupId);
      if (index < 0) return;
      final group = _groups[index];
      final contains = group.deviceIds.contains(deviceId);
      final copy = group.copyWith(
          deviceIds: contains
              ? group.deviceIds.where((id) => id != deviceId).toList()
              : [...group.deviceIds, deviceId]);
      _groups[index] = copy;
    });
  }

  Future<void> _pairWithDevice(PairedDevice device) async {
    if (device.lastIp.isEmpty) {
      // Manual pairing
      final result = await _showManualPairDialog();
      if (result != null) {
        final paired = await widget.pairingService.pairWithDevice(
          targetIp: result['ip']!,
          targetPort: int.tryParse(result['port']!) ?? 42069,
          enteredCode: result['code']!,
        );
        if (paired != null) {
          await _loadPairedDevices();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pairing failed. Check IP, port and code.')),
            );
          }
        }
      }
    } else {
      // Nearby device
      final code = await _showPairCodeDialog(device);
      if (code != null) {
        final paired = await widget.pairingService.pairWithDevice(
          targetIp: device.lastIp,
          enteredCode: code,
        );
        if (paired != null) {
          await _loadPairedDevices();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pairing failed. Check code.')),
            );
          }
        }
      }
    }
  }

  Future<Map<String, String>?> _showManualPairDialog() async {
    final ipController = TextEditingController(text: '127.0.0.1');
    final portController = TextEditingController(text: '42069');
    final codeController = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pair with device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                hintText: 'IP address (e.g. 127.0.0.1)',
              ),
            ),
            TextField(
              controller: portController,
              decoration: const InputDecoration(
                hintText: 'Port (e.g. 42069)',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                hintText: 'Pair code (e.g. ABC-123)',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop({
              'ip': ipController.text.trim(),
              'port': portController.text.trim(),
              'code': codeController.text.trim(),
            }),
            child: const Text('Pair'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPairCodeDialog(PairedDevice device) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pair with ${device.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter pair code (e.g. ABC-123)',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Pair'),
          ),
        ],
      ),
    );
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

  Widget _buildCapturePanel(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surface.withOpacity(0.14),
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Myself'), centerTitle: false),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final content = Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _items.isEmpty
                    ? const Center(
                        child: Text(
                          'Nothing saved yet.\nPaste a link or type a note.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) => ItemCard(
                          item: _items[i],
                          onDelete: () => _delete(_items[i].id),
                        ),
                      ),
              ),
              _buildCapturePanel(theme),
            ],
          ),
        );

        if (wide) {
          return Row(
            children: [
              Container(
                width: 320,
                decoration: BoxDecoration(
                  color: theme.colorScheme.background.withOpacity(0.08),
                  border: Border(right: BorderSide(color: Colors.white12)),
                ),
                child: Sidebar(
                  groups: _groups,
                  devices: _pairedDevices,
                  nearbyDevices: _nearbyDevices,
                  pairCode: widget.pairingService.pairCode,
                  onCreateGroup: _createGroup,
                  onToggleDevice: _toggleDeviceInGroup,
                  onPairWithDevice: _pairWithDevice,
                ),
              ),
              Expanded(child: content),
            ],
          );
        }

        return content;
      }),
    );
  }
}
