import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'helpers/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  // Initialize database and force schema upgrade
  final dbHelper = DatabaseHelper();
  await dbHelper.forceUpgradeDatabaseSchema();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ServiceYou',
      theme: ThemeData(
        primaryColor: const Color(0xFF06D6A0),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF06D6A0)),
        useMaterial3: true,
        fontFamily: 'Poppins', // Make sure this font is added to your pubspec.yaml
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
