import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const PrivacyLookupApp());
}

class PrivacyLookupApp extends StatelessWidget {
  const PrivacyLookupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '信息工具',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}