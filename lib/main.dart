import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the database and assign it to our global variable
  objectBox = await ObjectBoxService.create();

  runApp(const MyselfApp());
}

class MyselfApp extends StatelessWidget {
  const MyselfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'myself',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, // For the Serif logo look
        textTheme: GoogleFonts.geistTextTheme(),
        colorSchemeSeed: Colors.green,
      ),

      home: const HomeScreen(),
    );
  }
}
