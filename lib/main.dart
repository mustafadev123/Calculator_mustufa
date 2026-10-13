import 'package:flutter/material.dart';

import 'screens/calculator_screen.dart';
import 'theme.dart';

void main() {
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator State Lab',
      debugShowCheckedModeBanner: false,
      theme: buildLabTheme(Brightness.light),
      darkTheme: buildLabTheme(Brightness.dark),
      home: const CalculatorScreen(),
    );
  }
}
