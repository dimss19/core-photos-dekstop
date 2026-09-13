import 'package:flutter/material.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: Column(children: [
        Expanded(child: Container(color: Colors.black, child: const Center(child: Text('Preview (placeholder)')))),
        Expanded(
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text('Tray', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Hole ID: Core01'),
                const Text('Tray ID: 1'),
                const Text('Interval: 0.00 – 2.60'),
              ]),
            ),
          ),
        ),
      ]),
      floatingActionButton: Row(mainAxisSize: MainAxisSize.min, children: [
        OutlinedButton(onPressed: () {}, child: const Text('Retake')),
        const SizedBox(width: 16),
        ElevatedButton(onPressed: () {}, child: const Text('Save')),
      ]),
    );
  }
}
