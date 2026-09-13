import 'package:flutter/material.dart';

void main() {
  runApp(const CorePhotoApp(apiBaseUrl: 'http://127.0.0.1:42839'));
}

class CorePhotoApp extends StatelessWidget {
  const CorePhotoApp({super.key, required this.apiBaseUrl});
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Core Photo',
      home: Scaffold(
        appBar: AppBar(title: const Text('Core Photo')),
        body: const Center(child: Text('Core Photo')),
      ),
    );
  }
}
