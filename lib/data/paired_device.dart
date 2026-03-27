class PairedDevice {
  final String deviceId;
  final String name;
  final String lastIp;
  final int lastPort;
  final DateTime pairedAt;
  final bool isTrusted;
  bool isOnline;

  PairedDevice({
    required this.deviceId,
    required this.name,
    required this.lastIp,
    this.lastPort = 42069,
    required this.pairedAt,
    this.isTrusted = true,
    this.isOnline = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'name': name,
      'last_ip': lastIp,
      'last_port': lastPort,
      'paired_at': pairedAt.millisecondsSinceEpoch,
      'is_trusted': isTrusted ? 1 : 0,
    };
  }

  static PairedDevice fromMap(Map<String, dynamic> map) {
    return PairedDevice(
      deviceId: map['device_id'],
      name: map['name'],
      lastIp: map['last_ip'],
      lastPort: map['last_port'] ?? 42069,
      pairedAt: DateTime.fromMillisecondsSinceEpoch(map['paired_at']),
      isTrusted: map['is_trusted'] == 1,
      isOnline: false, // Will be updated by heartbeat
    );
  }
}