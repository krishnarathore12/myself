import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const localChatApp());
}

class localChatApp extends StatelessWidget {
  const localChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'myself',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
