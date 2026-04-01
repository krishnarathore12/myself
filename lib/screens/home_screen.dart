import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:bonsoir/bonsoir.dart';
// Needed for the Order enum
import 'dart:math' as dart_math;
import '../models/entities.dart';
import '../objectbox.g.dart'; // Needed for Message_.timestamp
import '../services/database_service.dart'; // Access to the global 'objectBox'
import '../services/network_discovery_service.dart';
import '../services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NetworkDiscoveryService _discovery = NetworkDiscoveryService();
  final SocketService _socket = SocketService();
  final TextEditingController _msgController = TextEditingController();

  final List<BonsoirService> _discoveredPeers = [];
  BonsoirService? _selectedPeer;

  // Classic State List for UI
  List<Message> _chatHistory = [];

  final Set<String> _pairedNames = {};
  String? _myName;
  String? _myEmoji;
  String _searchQuery = '';

  // --- RANDOM NAME GENERATOR ---
  final List<String> _adjectives = [
    'Ulterior',
    'Non',
    'Hello',
    'Cosmic',
    'Quantum',
    'Neon',
    'Cyber',
    'Ghost',
    'Silent',
    'Solar',
  ];

  final List<String> _nouns = [
    'Sigma',
    'Rider',
    'Jaime',
    'Ninja',
    'Phantom',
    'Dragon',
    'Wolf',
    'Specter',
    'Viper',
    'Nomad',
  ];

  final List<String> _emojis = ['🤖', '👻', '👽', '👾', '🤖', '👻', '👽', '👾'];

  String _generateRandomName() {
    final random = dart_math.Random();
    final adj = _adjectives[random.nextInt(_adjectives.length)];
    final noun = _nouns[random.nextInt(_nouns.length)];
    return '$adj $noun';
  }

  String _generateRandomEmoji() {
    final random = dart_math.Random();
    final emoji = _emojis[random.nextInt(_emojis.length)];
    return emoji;
  }

  final String _myPin = (1000 + dart_math.Random().nextInt(9000)).toString();

  @override
  void initState() {
    super.initState();

    _loadOrCreateIdentity();
    _loadChatHistory();
  }

  Future<void> _loadOrCreateIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    _myName = prefs.getString('myName');
    _myEmoji = prefs.getString('myEmoji');

    if (_myName == null || _myEmoji == null) {
      _myName = _generateRandomName();
      _myEmoji = _generateRandomEmoji();

      prefs.setString('myName', _myName!);
      prefs.setString('myEmoji', _myEmoji!);
    }

    _initializeNetwork();
  }

  // --- DATABASE LOGIC ---
  void _loadChatHistory() {
    // Read from local database and update UI
    final messages = objectBox.messageBox
        .query()
        .order(Message_.timestamp, flags: Order.descending)
        .build()
        .find();

    setState(() {
      _chatHistory = messages;
    });
  }

  void _saveAndDisplayMessage(Message msg) {
    // 1. Save to disk
    objectBox.messageBox.put(msg);
    // 2. Update UI (insert at top of list since we reverse the ListView)
    setState(() {
      _chatHistory.insert(0, msg);
    });
  }

  // --- NETWORK LOGIC ---
  Future<void> _initializeNetwork() async {
    await _socket.startServer(
      (ip, data) => _handleData(data),
      (path) => _handleFile(path),
    );

    // --- CHANGE THIS LINE ---
    await _discovery.registerDevice(
      _myName ?? 'Loading...',
      _socket.port,
      _myEmoji ?? '👤',
    );
    // -----------------------

    await _discovery.startScanning(
      onDeviceFound: (s) {
        if (s.name != _myName) {
          setState(() => _discoveredPeers.add(s));
        }
      },
      onDeviceLost: (s) =>
          setState(() => _discoveredPeers.removeWhere((p) => p.name == s.name)),
    );
  }

  void _handleData(Map<String, dynamic> data) {
    final type = data['type'];
    final senderName = data['senderName'] ?? "Unknown";

    if (type == 'pair_request') {
      if (data['pin'] == _myPin) {
        setState(() => _pairedNames.add(senderName));
        final peer = _discoveredPeers.firstWhere((p) => p.name == senderName);
        _socket.sendData(peer.host?.split('%')[0] ?? '', {
          'type': 'pair_success',
          'senderName': _myName,
        });
        setState(() => _selectedPeer = peer);
      } else {
        final peer = _discoveredPeers.firstWhere((p) => p.name == senderName);
        _socket.sendData(peer.host?.split('%')[0] ?? '', {
          'type': 'pair_fail',
          'senderName': _myName,
        });
      }
    } else if (type == 'pair_success') {
      setState(() {
        _pairedNames.add(senderName);
        _selectedPeer = _discoveredPeers.firstWhere(
          (p) => p.name == senderName,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paired with $senderName!'),
          backgroundColor: Colors.green,
        ),
      );

      // --- ADD THIS BLOCK ---
    } else if (type == 'pair_fail') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pairing rejected by $senderName (Wrong PIN)'),
          backgroundColor: Colors.red,
        ),
      );
      // ----------------------
    } else if (type == 'chat') {
      if (_pairedNames.contains(senderName) || senderName == 'Me') {
        _saveAndDisplayMessage(
          Message(
            senderName: senderName,
            content: data['message'],
            timestamp: DateTime.now(),
          ),
        );
      }
    }
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
          decoration: const InputDecoration(hintText: 'Enter PIN'),
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
              final hostIp = peer.host?.split('%')[0] ?? '';
              _socket.sendData(hostIp, {
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

  void _handleFile(String path) {
    _saveAndDisplayMessage(
      Message(
        senderName: "System",
        content: "📁 Received: ${path.split('/').last}",
        timestamp: DateTime.now(),
        isFile: true,
        filePath: path,
      ),
    );
  }

  // Class-level method (not inside _sendMsg)
  Future<void> _sendFile() async {
    if (_selectedPeer == null) return;

    final result = await FilePicker.platform.pickFiles(); // await!
    if (result == null) return; // user cancelled

    final path = result.files.single.path!;
    final file = File(path);
    final fileName = path.split('/').last;
    final hostIp = _selectedPeer!.host?.split('%')[0] ?? '';

    // 1. Show the message instantly in the UI
    _saveAndDisplayMessage(
      Message(
        senderName: 'Me',
        content: '📁 Sent: $fileName',
        timestamp: DateTime.now(),
        isMe: true,
        isFile: true,
        filePath: path,
      ),
    );

    // 2. Perform the potentially slow network send
    await _socket.sendFile(hostIp, file, {
      'fileName': fileName,
      'senderName': _myName ?? 'Me',
    });
  }

  void _sendMsg() {
    if (_selectedPeer == null || _msgController.text.isEmpty) return;

    final content = _msgController.text;
    final hostIp = _selectedPeer?.host?.split('%')[0] ?? '';

    // Send over network
    _socket.sendData(hostIp, {
      'type': 'chat',
      'message': content,
      'senderName': 'Me',
    });

    // Save locally and show on screen
    _saveAndDisplayMessage(
      Message(
        senderName: 'Me',
        content: content,
        timestamp: DateTime.now(),
        isMe: true,
      ),
    );

    _msgController.clear();
  }

  @override
  void dispose() {
    _discovery.stop();
    _socket.stopServer();
    _msgController.dispose();
    super.dispose();
  }

  // --- UI LAYOUTS (Same as before, just using _chatHistory) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121417),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) return _buildDesktopLayout();
          return _buildMobileLayout();
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    // IF WE SELECTED A PEER, SHOW THE CHAT!
    if (_selectedPeer != null) {
      return SafeArea(
        // Wrap in Container to force the white background from your design
        child: Container(color: Colors.white, child: _buildChatArea()),
      );
    }

    // OTHERWISE, SHOW THE DEVICE LIST
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 40, left: 24, right: 24),
          child: Text(
            'myself',
            style: GoogleFonts.castoro(color: Colors.white, fontSize: 32),
          ),
        ),
        _buildSearchBar(),
        Expanded(child: _buildDeviceList(isDark: true)),
        _buildProfileFooter(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Container(
          width: 320,
          color: const Color(0xFF121417),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'myself',
                  style: GoogleFonts.castoro(fontSize: 32, color: Colors.white),
                ),
              ),
              _buildSearchBar(),
              Expanded(child: _buildDeviceList(isDark: true)),
              _buildProfileFooter(),
            ],
          ),
        ),
        Expanded(
          child: Container(color: Colors.white, child: _buildChatArea()),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search ...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildDeviceList({required bool isDark}) {
    List<BonsoirService> filteredPeers;
    if (_searchQuery.isEmpty) {
      filteredPeers = _discoveredPeers;
    } else {
      filteredPeers = _discoveredPeers.where((peer) {
        return peer.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return ListView.builder(
      itemCount: filteredPeers.length,
      itemBuilder: (context, index) {
        final peer = filteredPeers[index];
        final isPaired = _pairedNames.contains(
          peer.name,
        ); // Check pairing status

        return ListTile(
          // --- THE FIX IS HERE ---
          onTap: () => isPaired
              ? setState(() => _selectedPeer = peer)
              : _showPairingDialog(peer),

          leading: Text(
            peer.attributes['emoji'] ?? '👤',
            style: const TextStyle(
              fontSize: 24,
            ), // You can adjust the size here
          ),
          title: Text(
            peer.name,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Show Connected if paired, Offline if not
          subtitle: Text(
            isPaired ? ' Connected' : 'Not Connected',
            style: TextStyle(
              color: isPaired ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatArea() {
    if (_selectedPeer == null) {
      return const Center(child: Text("Select a device to chat"));
    }

    // Check if we are on a mobile screen
    final isMobile = MediaQuery.of(context).size.width <= 900;

    return Column(
      children: [
        // Chat Header
        Container(
          color:
              Colors.grey[50], // Slight tint to separate header from messages
          child: ListTile(
            // Show a back button ONLY on mobile screens
            leading: isMobile
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () {
                      // Set selected peer to null to go back to the list
                      setState(() => _selectedPeer = null);
                    },
                  )
                : null,
            title: Text(
              _selectedPeer!.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: const Text(
              'Online',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Chat Messages
        Expanded(
          child: ListView.builder(
            reverse: true, // Shows latest messages at the bottom
            itemCount: _chatHistory.length,
            itemBuilder: (context, index) =>
                _buildChatBubble(_chatHistory[index]),
          ),
        ),

        // Text Input
        _buildInputArea(),
      ],
    );
  }

  Widget _buildChatBubble(Message msg) {
    // Check if the file is an image by extension
    final path = msg.filePath?.toLowerCase() ?? '';
    final isImage =
        msg.isFile &&
        (path.endsWith('.png') ||
            path.endsWith('.jpg') ||
            path.endsWith('.jpeg') ||
            path.endsWith('.gif'));

    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: MouseRegion(
        cursor: msg.isFile && msg.filePath != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: msg.isFile && msg.filePath != null
              ? () async {
                  print("Opening file: ${msg.filePath}");
                  final result = await OpenFilex.open(msg.filePath!);
                  print("OpenResult: ${result.type} - ${result.message}");
                }
              : null,
          child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: EdgeInsets.all(isImage ? 4 : 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
            maxHeight: isImage ? 300 : double.infinity,
          ),
          decoration: BoxDecoration(
            color: msg.isMe ? const Color(0xFF43A047) : const Color(0xFF2D2F36),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              if (msg.isFile)
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: msg.isFile
              ? (isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(msg.filePath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.insert_drive_file,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  msg.content
                                      .replaceAll('📁 Received: ', '')
                                      .replaceAll('📁 Sent: ', ''),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Tap to open",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ))
              : Text(msg.content, style: const TextStyle(color: Colors.white)),
        ),
      ),
    ),
  );
}

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.file_upload, color: Colors.green),
            onPressed: _sendFile,
          ),
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: "Message...",
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMsg(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.green),
            onPressed: _sendMsg,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF9FBE7),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFF9FBE7),
            // Gets the first letter of the device name dynamically
            child: Text(
              _myEmoji!,
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          const SizedBox(width: 12),
          // Use the real device name
          Expanded(
            child: Text(
              _myName!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          // Use the real PIN!
          Text(
            'PIN: $_myPin',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
