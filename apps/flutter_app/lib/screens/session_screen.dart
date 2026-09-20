import 'package:flutter/material.dart';

import '../api_client.dart';
import '../session.dart';
import '../workflow.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.api, required this.workflow, this.onActive});

  final ApiClient api;
  final WorkflowState workflow;
  final void Function(String sessionId)? onActive;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _date = TextEditingController(text: '2026-09-13');
  final _operator = TextEditingController();
  final _site = TextEditingController();
  String? _error;
  List<SessionInfo> _sessions = [];
  String? _activeId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _date.dispose();
    _operator.dispose();
    _site.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final sessions = await SessionService(widget.api).list();
      String? activeId;
      try {
        final act = await widget.api.activeSession();
        activeId = act['active']?['id']?.toString();
        if (activeId != null) widget.onActive?.call(activeId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _activeId = activeId;
        });
      }
    } catch (_) {}
  }

  Future<void> _create() async {
    if (_operator.text.trim().isEmpty) {
      setState(() => _error = 'Operator wajib diisi');
      return;
    }
    setState(() => _error = null);
    try {
      final created = await SessionService(widget.api).create(date: _date.text.trim(), operator: _operator.text.trim(), site: _site.text.trim());
      widget.onActive?.call(created.id);
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _activate(String id) async {
    try {
      await SessionService(widget.api).activate(id);
      widget.onActive?.call(id);
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(key: const Key('date'), controller: _date, decoration: const InputDecoration(labelText: 'Date')),
          TextField(key: const Key('operator'), controller: _operator, decoration: const InputDecoration(labelText: 'Operator')),
          TextField(key: const Key('site'), controller: _site, decoration: const InputDecoration(labelText: 'Site')),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          ElevatedButton(onPressed: _create, child: const Text('Create')),
          for (final session in _sessions)
            ListTile(
              title: Row(
                children: [
                  Text('${session.operator} @ ${session.site}'),
                  if (session.id == _activeId) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                      child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              subtitle: Text('${session.date} · ${session.id}'),
              trailing: session.id == _activeId
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : TextButton(onPressed: () => _activate(session.id), child: const Text('Activate')),
            ),
        ],
      ),
    );
  }
}
