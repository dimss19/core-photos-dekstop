// apps/flutter_app/lib/workflow.dart
import 'package:flutter/foundation.dart';

enum AppStage { sessionCreated, cameraReady, trayInput, readyToCapture, capturing, reviewing, processing, validating, trayCompleted }

class WorkflowState extends ChangeNotifier {
  AppStage _stage = AppStage.sessionCreated;
  bool _intervalValid = false;

  AppStage get stage => _stage;
  bool get canCapture => _stage == AppStage.readyToCapture && _intervalValid;

  void _set(AppStage s) {
    _stage = s;
    notifyListeners();
  }

  void cameraReady() {
    if (_stage == AppStage.sessionCreated) _set(AppStage.cameraReady);
  }

  void toTrayInput() {
    if (_stage == AppStage.sessionCreated || _stage == AppStage.cameraReady) _set(AppStage.trayInput);
  }

  void setIntervalValid(bool v) {
    _intervalValid = v;
    notifyListeners();
  }

  void toReadyToCapture() {
    if (_stage == AppStage.trayInput && _intervalValid) _set(AppStage.readyToCapture);
  }

  void toCapturing() {
    if (canCapture) _set(AppStage.capturing);
  }

  void toReviewing() {
    if (_stage == AppStage.capturing) _set(AppStage.reviewing);
  }

  void toProcessing() {
    if (_stage == AppStage.reviewing) _set(AppStage.processing);
  }

  void retake() {
    if (_stage == AppStage.reviewing) _set(AppStage.readyToCapture);
  }

  void toValidating() {
    if (_stage == AppStage.processing) _set(AppStage.validating);
  }

  void completeTray({required bool valid}) {
    if (_stage == AppStage.validating && valid) _set(AppStage.trayCompleted);
  }

  void nextTray() {
    if (_stage == AppStage.trayCompleted) {
      _intervalValid = false;
      _set(AppStage.trayInput);
    }
  }
}
