import 'package:flutter/material.dart';

class ValidationScreen extends StatelessWidget {
  const ValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validation')),
      body: Row(children: [
        Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          const Text('Valid', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Photos validated successfully'),
        ])))),
        Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          const Text('Invalid', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('No invalid photos'),
        ])))),
      ]),
    );
  }
}
