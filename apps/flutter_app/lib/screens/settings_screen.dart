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
  String _cameraStatus = 'Memeriksa...';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final st = await widget.api.cameraStatus();
      final c = await widget.api.cameraCapabilities();
      if (mounted) {
        setState(() {
          _cameraStatus = st['status']?.toString() ?? 'Unknown';
          _caps = c;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cameraStatus = 'Not Connected');
    }
  }

  Future<void> _connect() async {
    try {
      await widget.api.cameraConnect();
      await _refresh();
    } catch (_) {}
  }

  String _mark(bool? v) => v == true ? 'Ya' : 'Tidak';

  @override
  Widget build(BuildContext context) {
    final supportsIso = _caps?['supports_iso'] == true;
    final supportsFocus = _caps?['supports_focus'] == true;
    final supportsZoom = _caps?['supports_zoom'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            ListTile(title: const Text('Server URL'), trailing: Text(widget.api.baseUrl)),
            ListTile(title: const Text('API Token'), trailing: Text(widget.api.token?.isNotEmpty == true ? '***' : '')),
            ListTile(
              title: const Text('Status Kamera'),
              subtitle: Text('Adapter: ${_caps?['adapter'] ?? 'None'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_cameraStatus),
                  const SizedBox(width: 8),
                  TextButton(onPressed: _connect, child: const Text('Connect')),
                ],
              ),
            ),
            const Divider(),
            const ListTile(title: Text('Kontrol Kamera')),
            ListTile(
              title: const Text('Camera ISO'),
              trailing: Text(supportsIso ? '+1200' : 'Tidak didukung'),
            ),
            ListTile(
              title: const Text('Camera Focus'),
              trailing: Text(supportsFocus ? 'Manual' : 'Tidak didukung'),
            ),
            ListTile(
              title: const Text('Camera Zoom'),
              trailing: Text(supportsZoom ? '1.0x' : 'Tidak didukung'),
            ),
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
