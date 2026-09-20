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
          FutureBuilder<Map<String, dynamic>>(
            future: api.activeSession().catchError((_) => {'active': null}),
            builder: (context, snapshot) {
              final active = snapshot.data?['active'];
              final label = active == null ? '-' : '${active['operator']} @ ${active['site']}';
              return Text('Session: $label');
            },
          ),
          for (final entry in const {
            'Session': 1,
            'Capture': 2,
            'Review': 3,
            'Photo Browser': 4,
            'Validation': 5,
            'Transfer': 6,
            'Settings': 7,
          }.entries)
            ListTile(
              title: Text(entry.key),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpen(entry.value),
            ),
        ],
      ),
    );
  }
}
