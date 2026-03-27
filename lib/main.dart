import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

import 'ui/feed_screen.dart';
import 'data/pairing_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop needs FFI for SQLite
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
  }

  // Initialize pairing service
  final pairingService = PairingService();
  await pairingService.initialize();

  runApp(MyselfApp(pairingService: pairingService));
}

class MyselfApp extends StatelessWidget {
  final PairingService pairingService;

  const MyselfApp({super.key, required this.pairingService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Myself',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: FeedScreen(pairingService: pairingService),
    );
  }
}