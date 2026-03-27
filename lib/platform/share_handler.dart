import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../data/capture_service.dart';

class ShareHandler {
  static void init(void Function() onNewItem) {
    // When app is already open
    ReceiveSharingIntent.instance.getMediaStream().listen((files) async {
      for (final f in files) {
        if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
          await CaptureService.fromText(f.path);
        } else {
          await CaptureService.fromFile(f.path, f.path.split('/').last);
        }
      }
      onNewItem();
    });

    // When app is launched via share
    ReceiveSharingIntent.instance.getInitialMedia().then((files) async {
      for (final f in files) {
        if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
          await CaptureService.fromText(f.path);
        } else {
          await CaptureService.fromFile(f.path, f.path.split('/').last);
        }
      }
      ReceiveSharingIntent.instance.reset();
      onNewItem();
    });
  }
}