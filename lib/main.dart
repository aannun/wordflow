import 'package:flutter/material.dart';

import 'screens/library_screen.dart';

void main() {
  runApp(const WordFlowApp());
}

class WordFlowApp extends StatelessWidget {
  const WordFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WordFlow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          secondary: Colors.amber,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
    );
  }
}
