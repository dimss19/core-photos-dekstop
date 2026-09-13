import 'package:flutter/material.dart';

class BrowserScreen extends StatelessWidget {
  const BrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Browser')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search)))),
          const SizedBox(width: 8),
          DropdownButton<String>(value: 'All', items: const ['All', 'Valid', 'Invalid'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {}),
        ])),
        Expanded(child: ListView(children: const [
          Text('No photos'),
        ])),
      ]),
    );
  }
}
