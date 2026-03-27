import 'package:flutter/material.dart';
import '../../data/group.dart';
import '../../data/paired_device.dart';
import '../../data/pairing_service.dart';

class Sidebar extends StatelessWidget {
  final List<Group> groups;
  final List<PairedDevice> devices;
  final List<PairedDevice> nearbyDevices;
  final String pairCode;
  final ValueChanged<String> onCreateGroup;
  final void Function(String groupId, String deviceId) onToggleDevice;
  final void Function(PairedDevice device) onPairWithDevice;

  const Sidebar({
    super.key,
    required this.groups,
    required this.devices,
    required this.nearbyDevices,
    required this.pairCode,
    required this.onCreateGroup,
    required this.onToggleDevice,
    required this.onPairWithDevice,
  });

  void _showGroupEditor(BuildContext context, Group group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit group: ${group.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...devices.map((d) {
                final selected = group.deviceIds.contains(d.deviceId);
                return CheckboxListTile(
                  title: Text(d.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(d.isOnline ? 'Online' : 'Offline', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  value: selected,
                  onChanged: (_) => onToggleDevice(group.id, d.deviceId),
                  activeColor: Colors.blueAccent,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _sidebarItem(String name, String subtitle, bool active,
      {void Function()? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              active ? Icons.circle : Icons.circle_outlined,
              size: 18,
              color: active ? Colors.greenAccent : Colors.white54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: const TextStyle(fontSize: 12, color: Colors.white60)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final _groupController = TextEditingController();
    final _deviceController = TextEditingController();

    return Container(
      color: theme.colorScheme.background.withOpacity(0.14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            const Text('Groups', style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 8),
            ...groups.map((g) {
              final hasDevices = g.deviceIds.isNotEmpty;
              return _sidebarItem(
                g.name,
                '${g.deviceIds.length} devices',
                hasDevices,
                onTap: () => _showGroupEditor(context, g),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _groupController,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'New group',
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      final trimmed = value.trim();
                      if (trimmed.isNotEmpty) {
                        onCreateGroup(trimmed);
                        _groupController.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () {
                    final trimmed = _groupController.text.trim();
                    if (trimmed.isNotEmpty) {
                      onCreateGroup(trimmed);
                      _groupController.clear();
                    }
                  },
                ),
              ],
            ),
            const Spacer(),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            const Text('Devices', style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 8),
            ...devices.map((d) => _sidebarItem(d.name, d.isOnline ? 'Online' : 'Offline', d.isOnline)),
            const SizedBox(height: 16),
            const Text('Pair Code', style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Code: $pairCode', style: const TextStyle(fontFamily: 'monospace')),
                  Text('Port: ${PairingService.port}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            ),
            if (nearbyDevices.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Nearby Devices', style: TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 8),
              ...nearbyDevices.map((d) => _sidebarItem(
                d.name,
                'Tap to pair',
                false,
                onTap: () => onPairWithDevice(d),
              )),
            ] else ...[
              const SizedBox(height: 16),
              const Text('Manual Pairing', style: TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 8),
              _sidebarItem(
                'Pair by IP',
                'Enter IP address',
                false,
                onTap: () => onPairWithDevice(PairedDevice(
                  deviceId: '',
                  name: '',
                  lastIp: '',
                  pairedAt: DateTime.now(),
                )),
              ),
            ],
            const Spacer(),
            Row(
              children: [
                const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
                const SizedBox(width: 8),
                Text('Krishna', style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

