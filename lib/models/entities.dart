import 'package:objectbox/objectbox.dart';

@Entity()
class Peer {
  @Id()
  int id = 0;

  @Unique()
  String name;
  String ip;
  bool isPaired;

  Peer({required this.name, required this.ip, this.isPaired = false});
}

@Entity()
class Message {
  @Id()
  int id = 0;

  String senderName;
  String content;
  String? filePath;
  DateTime timestamp;
  bool isMe;
  bool isFile;

  Message({
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.filePath,
    this.isMe = false,
    this.isFile = false,
  });
}
