import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

class SocketService {
  ServerSocket? _serverSocket;
  final int port = 45678;

  Future<void> startServer(
    Function(String, Map<String, dynamic>) onMessageReceived,
    Function(String) onFileReceived,
  ) async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv6, port);
    print('🎧 Server listening on port $port');

    _serverSocket!.listen((Socket client) {
      final senderIp = client.remoteAddress.address;
      List<int> headerBytes = [];
      bool headerFound = false;
      IOSink? fileSink;
      String? savedPath;

      // Capture the subscription here!
      late StreamSubscription<Uint8List> subscription;

      subscription = client.listen(
        (Uint8List data) async {
          if (!headerFound) {
            int newlineIndex = data.indexOf(10); // Look for \n

            if (newlineIndex != -1) {
              headerFound = true;

              // 1. PAUSE the subscription so no bytes are missed
              subscription.pause();

              headerBytes.addAll(data.sublist(0, newlineIndex));

              try {
                String headerString = utf8.decode(headerBytes);
                Map<String, dynamic> header = jsonDecode(headerString);

                if (header['type'] == 'file') {
                  final result = await _prepareFileSink(header);
                  fileSink = result['sink'];
                  savedPath = result['path'];

                  if (newlineIndex + 1 < data.length) {
                    fileSink!.add(data.sublist(newlineIndex + 1));
                  }
                } else {
                  onMessageReceived(senderIp, header);
                }
              } catch (e) {
                print("Error parsing header: $e");
              } finally {
                // 2. RESUME once the fileSink is definitely ready
                subscription.resume();
              }
            } else {
              headerBytes.addAll(data);
            }
          } else {
            fileSink?.add(data);
          }
        },
        onDone: () async {
          if (fileSink != null) {
            await fileSink!.flush();
            await fileSink!.close();
            if (savedPath != null) onFileReceived(savedPath!);
          }
          await client.close();
        },
        onError: (e) => print("Socket Error: $e"),
        cancelOnError: true,
      );
    });
  }

  Future<Map<String, dynamic>> _prepareFileSink(
    Map<String, dynamic> header,
  ) async {
    Directory directory = Platform.isAndroid
        ? (await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory())
        : await getApplicationDocumentsDirectory();

    final filePath = '${directory.path}/${header['fileName']}';
    final file = File(filePath);

    return {'sink': file.openWrite(), 'path': filePath};
  }

  // sendData and sendFile remain the same as they were working fine
  Future<void> sendData(String ipAddress, Map<String, dynamic> data) async {
    try {
      final socket = await Socket.connect(ipAddress, port);
      socket.write('${jsonEncode(data)}\n');
      await socket.flush();
      await socket.close();
    } catch (e) {
      print(e);
    }
  }

  Future<void> sendFile(
    String ipAddress,
    File file,
    Map<String, dynamic> metadata,
  ) async {
    try {
      final socket = await Socket.connect(ipAddress, port);
      final header = {
        'type': 'file',
        'fileName': metadata['fileName'],
        'senderName': metadata['senderName'],
      };
      socket.write('${jsonEncode(header)}\n');
      await socket.flush();
      await socket.addStream(file.openRead());
      await socket.flush();
      await socket.close();
    } catch (e) {
      print(e);
    }
  }

  void stopServer() => _serverSocket?.close();
}
