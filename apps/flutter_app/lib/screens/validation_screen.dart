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
  final _fields = <String, TextEditingController>{};
  String? _status;
  Map<String, dynamic> _errors = {};
  bool _busy = false;
  bool _editing = false;

  static const _fieldDefs = [
    ['hole_id', 'Hole ID'],
    ['tray_id', 'Tray ID'],
    ['interval_from', 'From'],
    ['interval_to', 'To'],
    ['rows', 'Rows'],
    ['length', 'Length'],
    ['width', 'Width'],
    ['comments', 'Comments'],
  ];

  @override
  void dispose() {
    _trayId.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _c(String key, [String initial = '']) =>
      _fields.putIfAbsent(key, () => TextEditingController(text: initial));

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

  Future<void> _openEditor() async {
    setState(() => _busy = true);
    try {
      final tray = (await widget.api.getTray(_trayId.text.trim()))['tray'] as Map;
      if (mounted) {
        setState(() {
          for (final def in _fieldDefs) {
            _c(def[0], '${tray[def[0]] ?? ''}');
          }
          _editing = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'ERROR: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveCorrection() async {
    setState(() => _busy = true);
    try {
      final fields = {for (final def in _fieldDefs) def[0]: _c(def[0]).text.trim()};
      await widget.api.correctTray(_trayId.text.trim(), fields);
      if (mounted) setState(() => _editing = false);
      await _validate();
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
          if (_status != null && _status != 'VALID')
            TextButton(onPressed: _busy ? null : _openEditor, child: const Text('Edit & Re-validate')),
          if (_editing) ...[
            const Divider(),
            const Text('Correction (PRD §16)'),
            for (final def in _fieldDefs)
              TextField(key: Key('edit_${def[0]}'), controller: _c(def[0]), decoration: InputDecoration(labelText: def[1])),
            ElevatedButton(onPressed: _busy ? null : _saveCorrection, child: const Text('Save Correction')),
          ],
        ],
      ),
    );
  }
}
