import 'package:flutter/material.dart';

class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer')),
      body: Column(children: [
        Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          const Text('Select Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          CheckboxListTile(title: const Text('Session 2026-09-13'), value: false, onChanged: (_) {}),
        ])))),
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          const LinearProgressIndicator(value: 0),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton(onPressed: () {}, child: const Text('Start Transfer')),
            const SizedBox(width: 16),
            OutlinedButton(onPressed: () {}, child: const Text('Retry')),
          ]),
        ])),
      ]),
    );
  }
}
