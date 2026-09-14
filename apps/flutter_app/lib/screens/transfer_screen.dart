import 'dart:async';

import 'package:core_photo/api_client.dart';
import 'package:core_photo/session.dart';
import 'package:flutter/material.dart';

/// Transfer: pilih session → check koneksi → start → progress → retry.
/// File lokal tidak pernah dihapus (server-side guarantee).
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _dest = TextEditingController();
  final _selected = <String>{};
  List<SessionInfo> _sessions = [];
  String _server = 'unknown';
  String? _status;
  double _progress = 0;
  String? _lastJobId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _dest.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final list = await SessionService(widget.api).list();
      if (mounted) setState(() => _sessions = list);
    } catch (_) {}
  }

  Map<String, dynamic> get _destination => {'type': 'folder', 'path': _dest.text.trim()};

  Future<Map<String, dynamic>> _pollJob(String jobId) async {
    for (var i = 0; i < 120; i++) {
      final job = await widget.api.jobStatus(jobId);
      if (mounted && job['status'] == 'running') setState(() => _progress = (job['progress'] as num?)?.toDouble() ?? _progress);
      if (job['status'] == 'done' || job['status'] == 'error') return job;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    return {'status': 'error', 'error': 'timeout'};
  }

  Future<void> _check() async {
    try {
      final res = await widget.api.transferCheck(_destination);
      if (mounted) setState(() => _server = res['reachable'] == true ? 'reachable' : 'unreachable: ${res['detail']}');
    } catch (e) {
      if (mounted) setState(() => _server = 'error: $e');
    }
  }

  Future<void> _start([String? retryJobId]) async {
    if (_selected.isEmpty && retryJobId == null) {
      setState(() => _status = 'Pilih minimal 1 session');
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
      _status = 'Transferring...';
    });
    try {
      final res = retryJobId == null
          ? await widget.api.transferStart(sessionIds: _selected.toList(), destination: _destination)
          : await widget.api.transferRetry(retryJobId);
      final jobId = res['job_id'].toString();
      _lastJobId = jobId;
      final job = await _pollJob(jobId);
      if (mounted) {
        setState(() {
          _progress = 100;
          _status = job['status'] == 'done' ? 'Success: ${(job['result'] as Map)['copied']}' : 'Error: ${job['error']}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Server: $_server', key: const Key('server')),
          TextField(key: const Key('dest'), controller: _dest, decoration: const InputDecoration(labelText: 'Folder tujuan')),
          ElevatedButton(onPressed: _busy ? null : _check, child: const Text('Check Connection')),
          const Divider(),
          for (final s in _sessions)
            CheckboxListTile(
              title: Text('${s.operator} @ ${s.site}'),
              subtitle: Text(s.id),
              value: _selected.contains(s.id),
              onChanged: (v) => setState(() => v == true ? _selected.add(s.id) : _selected.remove(s.id)),
            ),
          LinearProgressIndicator(value: _progress / 100),
          if (_status != null) Text(_status!, key: const Key('status')),
          Row(children: [
            Expanded(child: ElevatedButton(onPressed: _busy ? null : () => _start(), child: const Text('Start Transfer'))),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: (_busy || _lastJobId == null) ? null : () => _start(_lastJobId),
                child: const Text('Retry'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
