import 'dart:async';

import 'package:core_photo/api_client.dart';
import 'package:core_photo/tray_form.dart';
import 'package:core_photo/workflow.dart';
import 'package:flutter/material.dart';

import 'helpers.dart';

/// Layar Capture: form tray (PRD §7) + validasi §8 + Live View + Take Picture.
/// [onCaptured] dipanggil dengan {job_id, raw_path, tray_id, box} setelah job done.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.api, required this.workflow, required this.sessionId, required this.onCaptured});

  final ApiClient api;
  final WorkflowState workflow;
  final String sessionId;
  final void Function(Map<String, dynamic> capture) onCaptured;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _form = TrayForm();
  final _controllers = <String, TextEditingController>{};
  String? _warning;
  String? _status;
  String? _trayId;
  bool _busy = false;
  int _frameBuster = 0;
  double _fx = 0.0;
  double _fy = 0.0;
  String _cameraStatus = 'Connecting...';

  TextEditingController _c(String key, [String initial = '']) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: initial));

  @override
  void initState() {
    super.initState();
    _connectCamera();
  }

  Future<void> _connectCamera() async {
    try {
      final res = await widget.api.cameraConnect();
      await widget.api.cameraLiveViewStart();
      if (mounted) {
        setState(() {
          _cameraStatus = res['status']?.toString() ?? 'Connected/Ready';
          _frameBuster++;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cameraStatus = 'Not Connected');
      }
    }
  }

  @override
  void dispose() {
    widget.api.cameraLiveViewStop().catchError((_) => {});
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncForm() {
    _form
      ..holeId = _c('hole').text
      ..trayId = _c('tray').text
      ..intervalFrom = _c('from').text
      ..intervalTo = _c('to').text
      ..rows = _c('rows').text
      ..length = _c('length').text
      ..width = _c('width').text
      ..comments = _c('comments').text;
  }

  Future<Map<String, dynamic>> _pollJob(String jobId) async {
    for (var i = 0; i < 60; i++) {
      final job = await widget.api.jobStatus(jobId);
      if (job['status'] == 'done' || job['status'] == 'error') return job;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    return {'status': 'error', 'error': 'timeout menunggu job $jobId'};
  }

  Future<void> _validateAndCreate() async {
    _syncForm();
    final warning = _form.warning;
    setState(() {
      _warning = warning;
      _trayId = null;
    });
    widget.workflow.setIntervalValid(warning == null);
    if (warning != null) return;
    setState(() => _busy = true);
    try {
      final res = await widget.api.createTray(_form.toJson(widget.sessionId));
      if (mounted) setState(() => _trayId = (res['tray'] as Map)['id'] as String);
      widget.workflow.toReadyToCapture();
    } catch (e) {
      if (mounted) setState(() => _warning = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _takePicture() async {
    if (_trayId == null || !_form.canCapture) return;
    setState(() {
      _busy = true;
      _status = 'Capturing...';
    });
    try {
      widget.workflow.toCapturing();
      final cap = await widget.api.capture(filename: _form.filename(), box: [_fx, _fy], outDir: 'captures', trayId: _trayId);
      final job = await _pollJob((cap['job_id'] ?? cap['jobId'] ?? '').toString());
      if (job['status'] != 'done') throw Exception(job['error'] ?? 'capture gagal');
      widget.workflow.toReviewing();
      widget.onCaptured({
        'job_id': (cap['job_id'] ?? cap['jobId']).toString(),
        'raw_path': (job['result'] as Map)['raw_path'],
        'tray_id': _trayId!,
        'box': [_fx, _fy],
      });
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncForm();
    final warning = _warning ?? _form.warning;
    final canCapture = _form.canCapture && _trayId != null && !_busy;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _cameraStatus == 'Connected/Ready' ? Icons.videocam : Icons.videocam_off,
                    size: 18,
                    color: _cameraStatus == 'Connected/Ready' ? Colors.greenAccent : Colors.amberAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _cameraStatus,
                    key: const Key('camera_status_label'),
                    style: TextStyle(
                      fontSize: 12,
                      color: _cameraStatus == 'Connected/Ready' ? Colors.greenAccent : Colors.amberAccent,
                    ),
                  ),
                  if (_cameraStatus != 'Connected/Ready') ...[
                    const SizedBox(width: 8),
                    TextButton(
                      key: const Key('connect_camera_btn'),
                      onPressed: _busy ? null : _connectCamera,
                      child: const Text('Connect', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      // Column, bukan ListView: semua field harus ada di tree (validasi live + testing).
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
          _field('hole', 'Hole ID'),
          _field('tray', 'Tray ID'),
          Row(children: [Expanded(child: _field('from', 'From')), const SizedBox(width: 8), Expanded(child: _field('to', 'To'))]),
          Row(children: [Expanded(child: _field('rows', 'Rows')), const SizedBox(width: 8), Expanded(child: _field('length', 'Length')), const SizedBox(width: 8), Expanded(child: _field('width', 'Width'))]),
          _field('comments', 'Comments'),
          if (warning != null) Text(warning, key: const Key('warning'), style: const TextStyle(color: Colors.red)),
          ElevatedButton(onPressed: _busy ? null : _validateAndCreate, child: const Text('Validate Tray')),
          const SizedBox(height: 8),
          Container(
            key: const Key('liveview'),
            height: 180,
            color: Colors.black,
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => setState(() {
                  _fx = (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                  _fy = (d.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0);
                }),
                child: Stack(
                  children: [
                    Center(
                      child: Image.network(
                        '${widget.api.baseUrl}/camera/frame?b=$_frameBuster',
                        errorBuilder: (_, _, _) => const Text('Live View (offline)', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const GridOverlay(),
                    Positioned(
                      left: _fx * constraints.maxWidth - 12,
                      top: _fy * constraints.maxHeight - 12,
                      child: Container(
                        key: const Key('boxmarker'),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(border: Border.all(color: Colors.yellow, width: 2)),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: TextButton(
                        onPressed: _connectCamera,
                        child: const Text('Refresh', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Text('Box: ${(_fx * 100).toInt()}%, ${(_fy * 100).toInt()}% (tap Live View untuk framing)',
              key: const Key('boxlabel')),
          const SizedBox(height: 8),
          ElevatedButton(
            key: const Key('capture'),
            onPressed: canCapture ? _takePicture : null,
            child: const Text('Take Picture'),
          ),
          if (_status != null) Text(_status!),
        ],
      ),
      ),
    );
  }

  Widget _field(String key, String label) => TextField(
        key: Key('tray_$key'),
        controller: _c(key),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label),
      );
}
