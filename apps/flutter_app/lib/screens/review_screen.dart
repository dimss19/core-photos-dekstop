import 'dart:async';

import 'package:core_photo/api_client.dart';
import 'package:core_photo/workflow.dart';
import 'package:flutter/material.dart';

/// Layar Review: preview RAW + Save (→ /process) / Retake (→ /captures/{job}/retake).
/// [capture] = {job_id, raw_path, tray_id, box} dari CaptureScreen; null = belum ada hasil.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.api, required this.workflow, required this.capture, required this.onProcessed});

  final ApiClient api;
  final WorkflowState workflow;
  final Map<String, dynamic>? capture;
  final void Function(Map<String, dynamic> photo) onProcessed;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String? _status;
  bool _busy = false;

  Future<Map<String, dynamic>> _pollJob(String jobId) async {
    for (var i = 0; i < 60; i++) {
      final job = await widget.api.jobStatus(jobId);
      if (job['status'] == 'done' || job['status'] == 'error') return job;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    return {'status': 'error', 'error': 'timeout menunggu job $jobId'};
  }

  Future<void> _save() async {
    final cap = widget.capture;
    if (cap == null) return;
    setState(() {
      _busy = true;
      _status = 'Processing...';
    });
    try {
      final res = await widget.api.processCapture(
        rawPath: cap['raw_path'].toString(),
        trayId: cap['tray_id'].toString(),
        box: List<int>.from(cap['box'] as List),
      );
      final job = await _pollJob(res['job_id'].toString());
      if (job['status'] != 'done') throw Exception(job['error'] ?? 'processing gagal');
      widget.workflow.toProcessing();
      widget.workflow.toValidating();
      if (mounted) setState(() => _status = 'Saved: ${(job['result'] as Map)['jpg_path']}');
      widget.onProcessed(Map<String, dynamic>.from(job['result'] as Map));
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retake() async {
    final cap = widget.capture;
    if (cap == null) return;
    setState(() {
      _busy = true;
      _status = 'Retaking...';
    });
    try {
      final res = await widget.api.retakeCapture(cap['job_id'].toString(), {
        'tray_id': cap['tray_id'],
        'box': cap['box'],
        'out_dir': 'captures',
        'filename': (cap['raw_path'] as String).split(RegExp(r'[/\\]')).last,
      });
      final job = await _pollJob(res['job_id'].toString());
      if (job['status'] != 'done') throw Exception(job['error'] ?? 'retake gagal');
      widget.workflow.retake();
      if (mounted) setState(() => _status = 'Retake done — kembali ke Capture untuk review ulang');
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cap = widget.capture;
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            key: const Key('preview'),
            height: 200,
            color: Colors.black,
            child: Center(
              child: cap == null
                  ? const Text('Belum ada hasil capture', style: TextStyle(color: Colors.white))
                  : Text(cap['raw_path'].toString(), style: const TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          if (cap != null) Text('Tray: ${cap['tray_id']}'),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: (cap == null || _busy) ? null : _retake, child: const Text('Retake'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(onPressed: (cap == null || _busy) ? null : _save, child: const Text('Save'))),
          ]),
          if (_status != null) Text(_status!),
        ],
      ),
    );
  }
}
