import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          ListTile(title: const Text('Server URL'), trailing: const Text('http://127.0.0.1:42839')),
          ListTile(title: const Text('API Token'), trailing: const Text('')),
          ListTile(title: const Text('Camera ISO'), trailing: const Text('+1200')),
          ListTile(title: const Text('Camera Focus'), trailing: const Text('Manual')),
          ListTile(title: const Text('Camera Zoom'), trailing: const Text('1.0x')),
        ])),
        ListTile(title: const Text('About'), trailing: const Icon(Icons.chevron_right)),
      ]),
    );
  }
}
