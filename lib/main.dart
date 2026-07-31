import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ToonFrameStudioApp());
}

class ToonFrameStudioApp extends StatelessWidget {
  const ToonFrameStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToonFrame Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orangeAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
