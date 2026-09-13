import 'package:flutter/material.dart';

import 'api_client.dart';
import 'screens/dashboard_screen.dart';
import 'screens/session_screen.dart';
import 'screens/stubs.dart';
import 'workflow.dart';

void main() {
  runApp(const CorePhotoApp(apiBaseUrl: 'http://127.0.0.1:42839'));
}

class CorePhotoApp extends StatefulWidget {
  const CorePhotoApp({super.key, required this.apiBaseUrl, this.api});

  final String apiBaseUrl;
  final ApiClient? api;

  @override
  State<CorePhotoApp> createState() => _CorePhotoAppState();
}

class _CorePhotoAppState extends State<CorePhotoApp> {
  int _index = 0;
  late final ApiClient _api = widget.api ?? ApiClient(baseUrl: widget.apiBaseUrl);
  late final WorkflowState _workflow = WorkflowState();

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(api: _api, onOpen: (index) => setState(() => _index = index)),
      SessionScreen(api: _api, workflow: _workflow),
      const CaptureScreen(),
      const BrowserScreen(),
      const ValidationScreen(),
      const TransferScreen(),
      const SettingsScreen(),
    ];
    return MaterialApp(
      title: 'Core Photo',
      home: Scaffold(
        body: pages[_index],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => _index = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.event_note), label: 'Session'),
            BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Capture'),
            BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: 'Browser'),
            BottomNavigationBarItem(icon: Icon(Icons.verified), label: 'Valid'),
            BottomNavigationBarItem(icon: Icon(Icons.cloud_upload), label: 'Transfer'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
          ],
        ),
      ),
    );
  }
}
