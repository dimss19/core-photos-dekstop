import 'package:core_photo/api_client.dart';
import 'package:flutter/material.dart';

/// Settings: konfigurasi aplikasi + capability kamera nyata (PRD §20.8, §6.4).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _caps;

  @override
  void initState() {
    super.initState();
    widget.api.cameraCapabilities().then((c) {
      if (mounted) setState(() => _caps = c);
    }).catchError((_) {});
  }

  String _mark(bool? v) => v == true ? 'Ya' : 'Tidak';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            ListTile(title: const Text('Server URL'), trailing: Text(widget.api.baseUrl)),
            ListTile(title: const Text('API Token'), trailing: Text(widget.api.token?.isNotEmpty == true ? '***' : '')),
            ListTile(title: const Text('Camera ISO'), trailing: const Text('+1200')),
            ListTile(title: const Text('Camera Focus'), trailing: const Text('Manual')),
            ListTile(title: const Text('Camera Zoom'), trailing: const Text('1.0x')),
            const Divider(),
            const ListTile(title: Text('Kemampuan kamera')),
            ListTile(title: const Text('Live View'), trailing: Text(_mark(_caps?['supports_liveview'] as bool?))),
            ListTile(title: const Text('ISO'), trailing: Text(_mark(_caps?['supports_iso'] as bool?))),
            ListTile(title: const Text('Focus'), trailing: Text(_mark(_caps?['supports_focus'] as bool?))),
            ListTile(title: const Text('Zoom'), trailing: Text(_mark(_caps?['supports_zoom'] as bool?))),
            ListTile(title: const Text('Capture'), trailing: Text(_mark(_caps?['supports_capture'] as bool?))),
          ]),
        ),
      ]),
    );
  }
}
