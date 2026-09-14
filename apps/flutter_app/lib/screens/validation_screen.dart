import 'package:core_photo/api_client.dart';
import 'package:flutter/material.dart';

/// Validation: POST /trays/validate → VALID/INVALID + daftar masalah + aksi perbaiki (kembali ke Capture).
class ValidationScreen extends StatefulWidget {
  const ValidationScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen> {
  final _trayId = TextEditingController();
  String? _status;
  Map<String, dynamic> _errors = {};
  bool _busy = false;

  @override
  void dispose() {
    _trayId.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    if (_trayId.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await widget.api.validateTray(_trayId.text.trim());
      if (mounted) {
        setState(() {
          _status = res['status']?.toString();
          _errors = Map<String, dynamic>.from(res['errors'] as Map? ?? {});
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'ERROR: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(key: const Key('tray_id'), controller: _trayId, decoration: const InputDecoration(labelText: 'Tray ID (mis. t1)')),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _busy ? null : _validate, child: const Text('Validate')),
          const SizedBox(height: 8),
          if (_status != null)
            Text(
              _status!,
              key: const Key('status'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _status == 'VALID' ? Colors.green : Colors.red,
              ),
            ),
          for (final e in _errors.entries) Text('${e.key}: ${e.value}'),
        ],
      ),
    );
  }
}
