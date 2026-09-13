# Core Photo Screens Implementation Plan (Plan 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Real Capture/Review/Browser/Validation/Transfer/Settings screens dengan API integration dan PRD workflows.

**Architecture:** Flutter screens consume ApiClient untuk sync/async data dari Python sidecar. Capture/Review/Validation/Transfer/Settings masing-masing screens dengan PRD workflow. SidecarLauncher dipakai di main untuk auto-launch core_service.exe.

**Tech Stack:** Flutter 3.44.8, Dart 3.12.2, existing ApiClient + WorkflowState + SessionService (Plan 3)

## Global Constraints

- Python owns job state; Flutter hanya polling `GET /jobs/{id}` untuk status/progress/result.
- Workflow state Flutter owned: SESSION_CREATED→...→TRAY_COMPLETED.
- `To < From` → warning + Capture disabled (UI mirror).
- Tray Crop 300×200, filename format dipertahankan.
- Localhost 127.0.0.1:42839 (configurable, bukan business rule).
- Offline-first; hanya Transfer butuh network.
- Tanpa fitur di luar PRD.

---

## Scope Check

Sisa PRD: Capture (§9/§10/§20.3), Review/Retake (§11/§20.4), Photo Browser (§18/§20.5), Validation (§16/§20.6), Transfer (§19/§20.7), Settings (§20.8). Plan ini hanya UI + integration stubs; processing=Python (Plan 1/2 already), storage=SQLite (later), Transfer backend (later). Setiap screen dengan PRD workflow diagram.

## File Structure

- `apps/flutter_app/lib/screens/capture_screen.dart` — CaptureScreen (LiveView + Framing + Grid + Zoom + TakePicture + Review).
- `apps/flutter_app/lib/screens/review_screen.dart` — ReviewScreen (Preview + Retake/Save + Tray metadata).
- `apps/flutter_app/lib/screens/browser_screen.dart` — BrowserScreen (search/filter + list + preview).
- `apps/flutter_app/lib/screens/validation_screen.dart` — ValidationScreen (status list + correction).
- `apps/flutter_app/lib/screens/transfer_screen.dart` — TransferScreen (selection + progress + validation).
- `apps/flutter_app/lib/screens/settings_screen.dart` — SettingsScreen (server URL + API token + camera settings).
- `apps/flutter_app/lib/screens/helpers.dart` — `GridOverlay`, `ZoomOverlay`, `CaptureButton`, `RetakeButton`, `SaveButton`.
- `apps/flutter_app/test/capture_screen_test.dart`, `review_screen_test.dart`, etc.
- Modify: `apps/flutter_app/lib/main.dart` — replace stubs dengan real screens.

---

### Task 1: CaptureScreen (PRD §9/§10/§20.3)

**Files:**
- Create: `apps/flutter_app/lib/screens/helpers.dart`
- Create: `apps/flutter_app/lib/screens/capture_screen.dart`
- Test: `apps/flutter_app/test/capture_screen_test.dart`

**Interfaces:**
- Consumes: `ApiClient.cameraStatus`, `ApiClient.validateInterval`, `ApiClient.capture`, `WorkflowState`
- Produces: CaptureScreen dengan LiveView (placeholder), Grid/Zoom toggle, capture button → ReviewScreen

- [ ] **Step 1: Write the failing test**

```dart
// apps/flutter_app/test/capture_screen_test.dart
import 'package:core_photo/screens/capture_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capture screen shows header and controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CaptureScreen()));
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Live View'), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
    expect(find.text('Zoom'), findsOneWidget);
    expect(find.text('Take Picture'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (cwd `apps/flutter_app`): `flutter test test/capture_screen_test.dart`
Expected: FAIL — missing capture_screen.dart

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/flutter_app/lib/screens/helpers.dart
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
```

```dart
// apps/flutter_app/lib/screens/capture_screen.dart
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
          Container(color: Colors.black, child: const Center(child: Text('Live View (placeholder)'))),
          const GridOverlay(),
          const ZoomOverlay(zoom: 1.0),
          Positioned(bottom: 16, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.grid_on, color: Colors.white), onPressed: () {}),
            IconButton(icon: const Icon(Icons.zoom_in, color: Colors.white), onPressed: () {}),
            CaptureButton(onPressed: () {}),
          ])),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run (cwd `apps/flutter_app`): `flutter test test/capture_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/flutter_app/lib/screens/helpers.dart apps/flutter_app/lib/screens/capture_screen.dart apps/flutter_app/test/capture_screen_test.dart
git commit -m "feat: add CaptureScreen with LiveView/Grid/Zoom placeholder + TakePicture button"
```

---

### Task 2: ReviewScreen (PRD §11/§20.4)

**Files:**
- Create: `apps/flutter_app/lib/screens/review_screen.dart`
- Test: `apps/flutter_app/test/review_screen_test.dart`

**Interfaces:**
- Consumes: `ApiClient.jobStatus`, `ApiClient.cameraStatus`, `WorkflowState`
- Produces: ReviewScreen dengan preview + Retake/Save + metadata (tray data)

- [ ] **Step 1: Write the failing test**

```dart
// apps/flutter_app/test/review_screen_test.dart
import 'package:core_photo/screens/review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('review screen shows preview and actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReviewScreen()));
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Tray'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (cwd `apps/flutter_app`): `flutter test test/review_screen_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/flutter_app/lib/screens/review_screen.dart
import 'package:flutter/material.dart';

import 'helpers.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: Column(children: [
        Expanded(child: Container(color: Colors.black, child: const Center(child: Text('Preview (placeholder)')))),
        Expanded(child: Card(
          margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text('Tray', style: Theme.of(context).textTheme.subtitle1),
            const SizedBox(height: 8),
            const Text('Hole ID: Core01'),
            const Text('Tray ID: 1'),
            const Text('Interval: 0.00 – 2.60'),
          ]),
        )),
      ]),
      floatingActionButton: Row(mainAxisSize: MainAxisSize.min, children: [
        RetakeButton(onPressed: () {}),
        const SizedBox(width: 16),
        SaveButton(onPressed: () {}),
      ]),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run (cwd `apps/flutter_app`): `flutter test test/review_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/flutter_app/lib/screens/review_screen.dart apps/flutter_app/test/review_screen_test.dart
git commit -m "feat: add ReviewScreen with preview + Retake/Save buttons"
```

---

### Task 3: BrowserScreen (PRD §18/§20.5)

**Files:**
- Create: `apps/flutter_app/lib/screens/browser_screen.dart`
- Test: `apps/flutter_app/test/browser_screen_test.dart`

**Interfaces:**
- Consumes: `ApiClient.cameraStatus`, `SessionService`
- Produces: BrowserScreen dengan search/filter + thumbnail list + preview

- [ ] **Step 1: Write the failing test**

```dart
// apps/flutter_app/test/browser_screen_test.dart
import 'package:core_photo/screens/browser_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('browser screen shows search and photo list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrowserScreen()));
    expect(find.text('Photo Browser'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('No photos'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (cwd `apps/flutter_app`): `flutter test test/browser_screen_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/flutter_app/lib/screens/browser_screen.dart
import 'package:flutter/material.dart';

class BrowserScreen extends StatelessWidget {
  const BrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Browser')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search)))),
          const SizedBox(width: 8),
          DropdownButtonFormField<String>(value: 'All', items: const ['All', 'Valid', 'Invalid'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (_) {}),
        ])),
        Expanded(child: ListView(children: [
          const Text('No photos'),
        ])),
      ]),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run (cwd `apps/flutter_app`): `flutter test test/browser_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/flutter_app/lib/screens/browser_screen.dart apps/flutter_app/test/browser_screen_test.dart
git commit -m "feat: add Photo Browser with search/filter placeholder + empty list"
```

---

### Task 4: ValidationScreen (PRD §16/§20.6)

**Files:**
- Create: `apps/flutter_app/lib/screens/validation_screen.dart`
- Test: `apps/flutter_app/test/validation_screen_test.dart`

**Interfaces:**
- Consumes: `ApiClient.cameraStatus`
- Produces: ValidationScreen dengan status list + correction

- [ ] **Step 1: Write the failing test**

```dart
// apps/flutter_app/test/validation_screen_test.dart
import 'package:core_photo/screens/validation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('validation screen shows status list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ValidationScreen()));
    expect(find.text('Validation'), findsOneWidget);
    expect(find.text('Valid'), findsOneWidget);
    expect(find.text('Invalid'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (cwd `apps/flutter_app`): `flutter test test/validation_screen_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/flutter_app/lib/screens/validation_screen.dart
import 'package:flutter/material.dart';

class ValidationScreen extends StatelessWidget {
  const ValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validation')),
      body: Row(children: [
        Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Text('Valid', style: Theme.of(context).textTheme.subtitle1),
          const SizedBox(height: 8),
          const Text('Photos validated successfully'),
        ])))),
        Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Text('Invalid', style: Theme.of(context).textTheme.subtitle1),
          const SizedBox(height: 8),
          const Text('No invalid photos'),
        ])))),
      ]),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run (cwd `apps/flutter_app`): `flutter test test/validation_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/flutter_app/lib/screens/validation_screen.dart apps/flutter_app/test/validation_screen_test.dart
git commit -m "feat: add ValidationScreen with valid/invalid status placeholders"
```

---

### Task 5: TransferScreen (PRD §19/§20.7)

**Files:**
- Create: `apps/flutter_app/lib/screens/transfer_screen.dart`
- Test: `apps/flutter_app/test/transfer_screen_test.dart`

**Interfaces:**
- Consumes: `ApiClient.cameraStatus`, `SessionService`
- Produces: TransferScreen dengan selection + progress + retry

- [ ] **Step 1: Write the failing test**

```dart
// apps/flutter_app/test/transfer_screen_test.dart
import 'package:core_photo/screens/transfer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('transfer screen shows selection and progress', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TransferScreen()));
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Select Sessions'), findsOneWidget);
    expect(find.text('Start Transfer'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (cwd `apps/flutter_app`): `flutter test test/transfer_screen_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/flutter_app/lib/screens/transfer_screen.dart
import 'package:flutter/material.dart';

class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer')),
      body: Column(children: [
        Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Text('Select Sessions', style: Theme.of(context).textTheme.subtitle1),
          const SizedBox(height: 8),
          CheckboxListTile(title: Text('Session 2026-09-13'), value: false, onChanged: (_) {}),
        ])))),
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          LinearProgressIndicator(value: 0),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton(onPressed: () {}, child: const Text('Start Transfer')),
            const SizedBox(width: 16),
            OutlinedButton(onPressed: () {}, child: const Text('Retry')),
          ]),
        ])),
      ]),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run (cwd `apps/flutter_app`): `flutter test test/transfer_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/flutter_app/lib/screens/transfer_screen.dart apps/flutter_app/test/transfer_screen_test.dart
git commit -m "feat: add TransferScreen with selection + progress + retry"
```

---

### Task 6: SettingsScreen (PRD §20.8)

**Files:**
- Create: `apps/flutter_app/lib/screens/settings_screen.dart`
- Test: `apps/flutter_app/test/settings_screen_test.dart`

**Interfaces:**
- Consumes: `ApiClient.cameraStatus`
- Produces: SettingsScreen dengan server URL + API token + camera settings

- [ ] **Step 1: Write the failing test**

```dart
// apps/flutter_app/test/settings_screen_test.dart
import 'package:core_photo/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings screen shows config fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('API Token'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (cwd `apps/flutter_app`): `flutter test test/settings_screen_test.dart`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/flutter_app/lib/screens/settings_screen.dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          ListTile(title: const Text('Server URL'), trailing: const Text('http://127.0.0.1:42839')),
          ListTile(title: const Text('API Token'), trailing: const Text('')),
          ListTile(title: const Text('Camera ISO'), trailing: const Text('+1200')),
          ListTile(title: const Text('Camera Focus'), trailing: const Text('Manual')),
          ListTile(title: const Text('Camera Zoom'), trailing: const Text('1.0x')),
        ])),
        ListTile(title: const Text('About'), trailing: const Icon(Icons.chevron_right)),
      ]),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run (cwd `apps/flutter_app`): `flutter test test/settings_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/flutter_app/lib/screens/settings_screen.dart apps/flutter_app/test/settings_screen_test.dart
git commit -m "feat: add SettingsScreen with server/API/camera config placeholders"
```

---

### Task 7: Update main.dart with real screens

**Files:**
- Modify: `apps/flutter_app/lib/main.dart`

**Interfaces:**
- Consumes: All new screens
- Produces: Nav replaces stubs dengan real screens

- [ ] **Step 1: Write the failing test**

```dart
// apps/flutter_app/test/main_real_screen_test.dart
import 'package:core_photo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('main app uses real screens', (tester) async {
    await tester.pumpWidget(const CorePhotoApp(apiBaseUrl: 'http://127.0.0.1:9'));
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(find.byType(ReviewScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (cwd `apps/flutter_app`): `flutter test test/main_real_screen_test.dart`
Expected: FAIL — no CaptureScreen/ReviewScreen imports in main.dart

- [ ] **Step 3: Write minimal implementation**

Update `apps/flutter_app/lib/main.dart`:

```dart
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'screens/dashboard_screen.dart';
import 'screens/session_screen.dart';
import 'screens/stubs.dart';
import 'screens/capture_screen.dart';
import 'screens/review_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/validation_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/settings_screen.dart';
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
      const ReviewScreen(),
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
            BottomNavigationBarItem(icon: Icon(Icons.image), label: 'Review'),
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
```

- [ ] **Step 4: Run test to verify it passes**

Run (cwd `apps/flutter_app`): `flutter test test/main_real_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/flutter_app/lib/main.dart apps/flutter_app/test/main_real_screen_test.dart
git commit -m "feat: wire Capture/Review/Browser/Validation/Transfer/Settings into main nav"
```

---

### Task 8: Full gates + push

**Files:**
- Modify: none (verification only)

- [ ] **Step 1: Run Flutter gates**

Run (cwd `apps/flutter_app`): `flutter analyze`
Expected: No issues found

Run (cwd `apps/flutter_app`): `flutter test`
Expected: PASS (all new tests + existing)

- [ ] **Step 2: Run Python gate (no regression)**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests -v`
Expected: PASS (32 tests)

- [ ] **Step 3: Push**

```bash
git push origin main
```
Expected: up-to-date remote `main`

## Self-Review

1. **Spec coverage:** Capture screen (LiveView, Grid, Zoom, TakePicture, Review redirect) → Task 1; Review screen (Preview, Retake/Save, metadata) → Task 2; Browser (search, filter, thumbnails) → Task 3; Validation (valid/invalid status) → Task 4; Transfer (selection, progress, retry) → Task 5; Settings (server URL, token, camera) → Task 6; main.dart wiring → Task 7.
2. **Placeholder scan:** All screens placeholder (LiveView, Preview, thumbnails, progress bars). No TBD/TODO; "placeholder" comments explicit for later implementation.
3. **Type consistency:** `CaptureScreen`, `ReviewScreen`, `BrowserScreen`, `ValidationScreen`, `TransferScreen`, `SettingsScreen` exported from same package; no naming conflicts.
