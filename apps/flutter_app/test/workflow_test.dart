// apps/flutter_app/test/workflow_test.dart
import 'package:core_photo/workflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capture gated by stage + interval validity', () {
    final w = WorkflowState();
    expect(w.stage, AppStage.sessionCreated);
    w.toTrayInput();
    w.toReadyToCapture();
    expect(w.stage, AppStage.trayInput); // invalid interval blocks
    expect(w.canCapture, isFalse);
    w.setIntervalValid(true);
    w.toReadyToCapture();
    w.toCapturing();
    expect(w.stage, AppStage.capturing);
    expect(w.canCapture, isFalse); // capturing is not readyToCapture
  });

  test('review retake save chain to trayCompleted and nextTray reset', () {
    final w = WorkflowState();
    w.cameraReady();
    w.toTrayInput();
    w.setIntervalValid(true);
    w.toReadyToCapture();
    w.toCapturing();
    w.toReviewing();
    w.retake();
    expect(w.stage, AppStage.readyToCapture);
    w.toCapturing();
    w.toReviewing();
    w.toProcessing();
    w.toValidating();
    w.completeTray(valid: false);
    expect(w.stage, AppStage.validating); // invalid stays for correction
    w.completeTray(valid: true);
    expect(w.stage, AppStage.trayCompleted);
    w.nextTray();
    expect(w.stage, AppStage.trayInput);
    expect(w.canCapture, isFalse);
  });
}
