import 'package:flutter/material.dart';
import 'package:bonsoir/bonsoir.dart';
import 'dart:math';
import 'dart:io';
import '../services/network_discovery_service.dart';
import '../services/socket_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NetworkDiscoveryService _discoveryService = NetworkDiscoveryService();
  final SocketService _socketService = SocketService();
  final TextEditingController _messageController = TextEditingController();

  late final String _myPin;
  late final String _myName; // We now store our own name globally

  // FIX: We now store paired NAMES instead of paired IPs
  final Set<String> _pairedNames = {};

  List<BonsoirService> _discoveredPeers = [];
  BonsoirService? _selectedPeer;
  List<String> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _myPin = (1000 + Random().nextInt(9000)).toString();

    // Set our name right when the app starts
    if (Platform.isLinux) {
      _myName = "Krishna's Linux PC";
    } else if (Platform.isAndroid) {
      _myName = "Krishna's Android Phone";
    } else {
      _myName = "Unknown Device";
    }

    _initializeNetwork();
  }

  String _cleanIp(String? ip) {
    if (ip == null) return '';
    return ip.split('%')[0]; // Still keep this to prevent socket routing errors
  }

  Future<void> _initializeNetwork() async {
    await _socketService.startServer(_handleIncomingData);
    await _discoveryService.registerDevice(_myName, _socketService.port);

    await _discoveryService.startScanning(
      onDeviceFound: (service) {
        setState(() {
          final index = _discoveredPeers.indexWhere(
            (p) => p.name == service.name,
          );
          if (index != -1) {
            _discoveredPeers[index] = service;
          } else {
            _discoveredPeers.add(service);
          }
        });
      },
      onDeviceLost: (service) {
        setState(() {
          _discoveredPeers.removeWhere((p) => p.name == service.name);
          if (_selectedPeer?.name == service.name) {
            _selectedPeer = null;
          }
        });
      },
    );
  }

  // Auto-select based on the device NAME now
  void _autoSelectPeer(String peerName) {
    try {
      _selectedPeer = _discoveredPeers.firstWhere((p) => p.name == peerName);
    } catch (e) {
      // Peer not found in UI list yet
    }
  }

  void _handleIncomingData(String senderIp, Map<String, dynamic> data) {
    final type = data['type'];

    // FIX: Extract the sender's name from the JSON payload
    final senderName = data['senderName'];
    if (senderName == null) return; // Ignore malformed messages

    setState(() {
      if (type == 'pair_request') {
        if (data['pin'] == _myPin) {
          _pairedNames.add(senderName); // Save the NAME

          // Reply back using the IP, but include our Name so they know it's us
          _socketService.sendData(_cleanIp(senderIp), {
            'type': 'pair_success',
            'senderName': _myName,
          });

          _autoSelectPeer(senderName);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Paired with $senderName!')));
        } else {
          _socketService.sendData(_cleanIp(senderIp), {
            'type': 'pair_fail',
            'senderName': _myName,
          });
        }
      } else if (type == 'pair_success') {
        _pairedNames.add(senderName); // Save the NAME
        _autoSelectPeer(senderName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully paired with $senderName!')),
        );
      } else if (type == 'pair_fail') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect PIN!')));
      } else if (type == 'chat') {
        if (_pairedNames.contains(senderName)) {
          _chatHistory.add("$senderName: ${data['message']}");
        }
      }
    });
  }

  void _showPairingDialog(BonsoirService peer) {
    final TextEditingController pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pair with ${peer.name}'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter 4-digit PIN'),
          maxLength: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Include our NAME in the request!
              _socketService.sendData(_cleanIp(peer.host), {
                'type': 'pair_request',
                'pin': pinController.text,
                'senderName': _myName,
              });
            },
            child: const Text('Pair'),
          ),
        ],
      ),
    );
  }

  void _onPeerSelected(BonsoirService peer) {
    if (peer.host == null) return;

    // Check pairing status using the NAME
    if (_pairedNames.contains(peer.name)) {
      setState(() => _selectedPeer = peer);
    } else {
      _showPairingDialog(peer);
    }
  }

  void _sendMessage() {
    if (_selectedPeer == null || _selectedPeer!.host == null) return;
    if (_messageController.text.isEmpty) return;

    final message = _messageController.text;

    _socketService.sendData(_cleanIp(_selectedPeer!.host), {
      'type': 'chat',
      'message': message,
      'senderName': _myName, // Always send our name
    });

    setState(() {
      _chatHistory.add("Me: $message");
      _messageController.clear();
    });
  }

  @override
  void dispose() {
    _discoveryService.stop();
    _socketService.stopServer();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Local Chat (My PIN: $_myPin)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Container(
            height: 150,
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Available Devices on Wi-Fi:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: _discoveredPeers.isEmpty
                      ? const Center(child: Text('Scanning for devices...'))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _discoveredPeers.length,
                          itemBuilder: (context, index) {
                            final peer = _discoveredPeers[index];
                            final isSelected = _selectedPeer == peer;

                            // UI checks the NAME now
                            final isPaired = _pairedNames.contains(peer.name);

                            return GestureDetector(
                              onTap: () => _onPeerSelected(peer),
                              child: Card(
                                color: isSelected
                                    ? Colors.teal[100]
                                    : Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 8.0,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isPaired ? Icons.lock_open : Icons.lock,
                                        color: isPaired
                                            ? Colors.teal
                                            : Colors.grey,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        peer.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        peer.host ?? 'Resolving IP...',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(_chatHistory[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _selectedPeer == null
                          ? 'Select & Pair with a device...'
                          : 'Message ${_selectedPeer!.name}...',
                      border: const OutlineInputBorder(),
                    ),
                    enabled: _selectedPeer != null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.teal,
                  onPressed: _selectedPeer != null ? _sendMessage : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
