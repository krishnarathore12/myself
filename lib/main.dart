import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

import 'ui/feed_screen.dart';

void main() {
  // Desktop needs FFI for SQLite
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
  }
  runApp(const MyselfApp());
}

class MyselfApp extends StatelessWidget {
  const MyselfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Myself',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const FeedScreen(),
    );
  }
}