import 'dart:io';
import 'dart:convert';

class SocketService {
  ServerSocket? _serverSocket;
  
  // FIX 1: Moved away from 5555 to a high, unused port to avoid Android Debugging conflicts
  final int port = 45678;

  Future<void> startServer(Function(String, Map<String, dynamic>) onMessageReceived) async {
    // FIX 2: Bind to anyIPv6. On Linux and Android, this natively handles BOTH IPv4 and IPv6 traffic!
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv6, port);
    print('🎧 Server listening on port $port');
    
    _serverSocket!.listen((Socket client) {
      final senderIp = client.remoteAddress.address;
      
      client.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
        (String jsonString) {
          try {
            final Map<String, dynamic> data = jsonDecode(jsonString);
            onMessageReceived(senderIp, data);
          } catch (e) {
            print('Received invalid JSON data: $e');
          }
        },
        onDone: () => client.close(),
        onError: (error) => client.close(),
      );
    });
  }

  Future<void> sendData(String ipAddress, Map<String, dynamic> data) async {
    try {
      // FIX 3: Clean the IP address. 
      // Sometimes Android attaches a network zone ID (like "%wlan0") to the end of IPv6 addresses. 
      // This strips it off so the Dart Socket doesn't get confused.
      String cleanIp = ipAddress.split('%')[0];

      final socket = await Socket.connect(cleanIp, port);
      final jsonString = jsonEncode(data);
      
      socket.write('$jsonString\n');
      await socket.flush();
      await socket.close();
    } catch (e) {
      print('❌ Failed to send data: $e');
    }
  }

  void stopServer() {
    _serverSocket?.close();
  }
}