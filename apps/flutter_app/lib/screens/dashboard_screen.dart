import 'package:flutter/material.dart';

import '../api_client.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.api, required this.onOpen});

  final ApiClient api;
  final void Function(int index) onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Core Photo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: api.cameraStatus().catchError((_) => {'status': 'Unknown'}),
            builder: (context, snapshot) => Text('Camera: ${snapshot.data?['status'] ?? '...'}'),
          ),
          for (final entry in const {'Session': 1, 'Capture': 2, 'Photo Browser': 3, 'Validation': 4, 'Transfer': 5, 'Settings': 6}.entries)
            ListTile(title: Text(entry.key), onTap: () => onOpen(entry.value)),
        ],
      ),
    );
  }
}
