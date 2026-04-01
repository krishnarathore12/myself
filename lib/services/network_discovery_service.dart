import 'package:bonsoir/bonsoir.dart';

class NetworkDiscoveryService {
  final String serviceType = '_localchat._tcp';
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  Future<void> registerDevice(String deviceName, int port, String myEmoji) async {
    // 1. Define the service
    BonsoirService service = BonsoirService(
      name: deviceName,
      type: serviceType,
      port: port,
      attributes: {'emoji': myEmoji},
    );

    // 2. Broadcast it to the network
    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.initialize(); // Changed from .ready in v6
    await _broadcast!.start();
    print('✅ Device broadcasted as "$deviceName" on port $port');
  }

  // Update this method in lib/services/network_discovery_service.dart
  Future<void> startScanning({
    required Function(BonsoirService) onDeviceFound,
    required Function(BonsoirService) onDeviceLost, // NEW: Handle disconnections
  }) async {
    _discovery = BonsoirDiscovery(type: serviceType);
    await _discovery!.initialize(); 

    _discovery!.eventStream!.listen((event) {
      if (event is BonsoirDiscoveryServiceFoundEvent) {
        event.service.resolve(_discovery!.serviceResolver);
        
      } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
        onDeviceFound(event.service);
            } else if (event is BonsoirDiscoveryServiceLostEvent) {
        // NEW: When a device drops off the Wi-Fi or closes the app
        onDeviceLost(event.service);
            }
    });

    await _discovery!.start();
    print('🔍 Scanning the local network for peers...');
  }

  Future<void> stop() async {
    if (_discovery != null) await _discovery!.stop();
    if (_broadcast != null) await _broadcast!.stop();
  }
}