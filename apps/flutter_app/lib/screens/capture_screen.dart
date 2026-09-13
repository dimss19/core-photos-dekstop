import 'package:flutter/material.dart';

import 'helpers.dart';

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture')),
      body: Stack(
        children: [
          Container(color: Colors.black, child: const Center(child: Text('Live View'))),
          const GridOverlay(),
          const ZoomOverlay(zoom: 1.0),
          Positioned(bottom: 16, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: () {}, child: const Text('Grid', style: TextStyle(color: Colors.white))),
            TextButton(onPressed: () {}, child: const Text('Zoom', style: TextStyle(color: Colors.white))),
            TextButton(onPressed: () {}, child: const Text('Take Picture', style: TextStyle(color: Colors.white))),
          ])),
        ],
      ),
    );
  }
}
