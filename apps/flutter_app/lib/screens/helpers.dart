import 'package:flutter/material.dart';

class GridOverlay extends StatelessWidget {
  const GridOverlay({super.key});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Column(
                children: List.generate(3, (_) => Expanded(child: Container(color: Colors.transparent))),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: List.generate(3, (_) => Expanded(child: Container(color: Colors.transparent))),
              ),
            ),
          ],
        ),
      );
}

class ZoomOverlay extends StatelessWidget {
  const ZoomOverlay({super.key, required this.zoom});
  final double zoom;
  @override
  Widget build(BuildContext context) => Positioned(
        bottom: 16, right: 16,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.zoom_in, color: Colors.white),
            Text('${(zoom * 100).toInt()}%'),
          ]),
        ),
      );
}

class CaptureButton extends StatelessWidget {
  const CaptureButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onPressed, style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(24)),
        child: Container(width: 64, height: 64, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
      );
}

class RetakeButton extends StatelessWidget {
  const RetakeButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton(onPressed: onPressed, child: const Text('Retake'));
}

class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => ElevatedButton(onPressed: onPressed, child: const Text('Save'));
}
