import '../objectbox.g.dart'; // Generated file
import '../models/entities.dart';
import 'package:path_provider/path_provider.dart';

class ObjectBoxService {
  late final Store store;
  late final Box<Message> messageBox;
  late final Box<Peer> peerBox;

  ObjectBoxService._create(this.store) {
    messageBox = store.box<Message>();
    peerBox = store.box<Peer>();
  }

  static Future<ObjectBoxService> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final store = await openStore(directory: '${docsDir.path}/myself_db');
    return ObjectBoxService._create(store);
  }
}

// GLOBAL VARIABLE: This replaces Riverpod.
// You can use 'objectBox.messageBox' anywhere in your app now.
late ObjectBoxService objectBox;
