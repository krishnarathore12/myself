import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:bonsoir/bonsoir.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'db.dart';
import 'paired_device.dart';

class PairingService {
  static int port = 42069 + (DateTime.now().millisecondsSinceEpoch % 100); // Random port for testing
  static const String serviceType = '_myself._tcp';

  late String _deviceId;
  late String _deviceName;
  late String _pairCode;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  Timer? _heartbeatTimer;

  final StreamController<List<PairedDevice>> _pairedDevicesController =
      StreamController.broadcast();
  Stream<List<PairedDevice>> get pairedDevicesStream =>
      _pairedDevicesController.stream;

  final StreamController<List<PairedDevice>> _nearbyDevicesController =
      StreamController.broadcast();
  Stream<List<PairedDevice>> get nearbyDevicesStream =>
      _nearbyDevicesController.stream;

  Future<void> initialize() async {
    await _loadOrGenerateIdentity();
    await _startServer();
    // await _startBroadcast(); // Disabled due to bonsoir Linux issues
    // await _startDiscovery(); // Disabled due to bonsoir Linux issues
    await _startHeartbeat();
  }

  Future<void> _loadOrGenerateIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('deviceId') ?? const Uuid().v4();
    _pairCode = prefs.getString('pairCode') ?? _generateCode();
    _deviceName = prefs.getString('deviceName') ?? 'MyDevice'; // TODO: get from user

    await prefs.setString('deviceId', _deviceId);
    await prefs.setString('pairCode', _pairCode);
    await prefs.setString('deviceName', _deviceName);
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final a = List.generate(3, (_) => chars[rand.nextInt(chars.length)]).join();
    final b = List.generate(3, (_) => chars[rand.nextInt(chars.length)]).join();
    return '$a-$b';
  }

  Future<void> _startServer() async {
    final router = Router()
      ..get('/ping', _handlePing)
      ..post('/pair', _handlePair);

    final handler = Pipeline().addMiddleware(logRequests()).addHandler(router);
    await io.serve(handler, InternetAddress.anyIPv4, port);
  }

  Response _handlePing(Request req) => Response.ok('pong');

  Future<Response> _handlePair(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final theirCode = body['code'] as String;
      final theirId = body['deviceId'] as String;
      final theirName = body['deviceName'] as String;

      if (theirCode != _pairCode) {
        return Response.forbidden('wrong code');
      }

      // Store them as a trusted device
      final device = PairedDevice(
        deviceId: theirId,
        name: theirName,
        lastIp: req.requestedUri.host,
        pairedAt: DateTime.now(),
      );
      await DB.insertPairedDevice(device);

      return Response.ok(jsonEncode({
        'deviceId': _deviceId,
        'deviceName': _deviceName,
      }));
    } catch (e) {
      return Response.internalServerError(body: 'Error: $e');
    }
  }

  Future<void> _startBroadcast() async {
    try {
      final service = BonsoirService(
        name: _deviceName,
        type: serviceType,
        port: port,
        attributes: {'deviceId': _deviceId},
      );
      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.start();
    } catch (e) {
      print('Failed to start broadcast: $e');
      // Continue without broadcasting
    }
  }

  Future<void> _startDiscovery() async {
    try {
      _discovery = BonsoirDiscovery(type: serviceType);
      await _discovery!.start();

      final nearbyDevices = <PairedDevice>[];

      _discovery!.eventStream!.listen((event) {
        if (event.service != null) {
          final found = event.service!;
          final ip = found.host;
          final theirDeviceId = found.attributes!['deviceId']!;

          // Update IP if already paired
          if (ip != null) {
            DB.updatePairedDeviceIp(theirDeviceId, ip);
          }

          // Add to nearby if not paired
          final existing = nearbyDevices.where((d) => d.deviceId == theirDeviceId);
          if (existing.isEmpty && ip != null) {
            nearbyDevices.add(PairedDevice(
              deviceId: theirDeviceId,
              name: found.name,
              lastIp: ip,
              pairedAt: DateTime.now(), // dummy
            ));
          }
          _nearbyDevicesController.add(nearbyDevices);
        }
      });
    } catch (e) {
      print('Failed to start discovery: $e');
      // Continue without discovery
    }
  }

  Future<void> _startHeartbeat() async {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final paired = await DB.getPairedDevices();
      for (final device in paired) {
        try {
          final res = await http
              .get(Uri.parse('http://${device.lastIp}:${device.lastPort}/ping'))
              .timeout(const Duration(seconds: 3));
          device.isOnline = res.statusCode == 200;
        } catch (_) {
          device.isOnline = false;
        }
      }
      _pairedDevicesController.add(paired);
    });
  }

  Future<PairedDevice?> pairWithDevice({
    required String targetIp,
    int? targetPort,
    required String enteredCode,
  }) async {
    final port = targetPort ?? PairingService.port;
    final url = Uri.parse('http://$targetIp:$port/pair');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': enteredCode,
          'deviceId': _deviceId,
          'deviceName': _deviceName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final device = PairedDevice(
          deviceId: data['deviceId'],
          name: data['deviceName'],
          lastIp: targetIp,
          lastPort: port,
          pairedAt: DateTime.now(),
        );
        await DB.insertPairedDevice(device);
        return device;
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }

  String get deviceId => _deviceId;
  String get pairCode => _pairCode;
  String get deviceName => _deviceName;

  Future<void> regenerateCode() async {
    _pairCode = _generateCode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pairCode', _pairCode);
  }

  void dispose() {
    _broadcast?.stop();
    _discovery?.stop();
    _heartbeatTimer?.cancel();
    _pairedDevicesController.close();
    _nearbyDevicesController.close();
  }
}