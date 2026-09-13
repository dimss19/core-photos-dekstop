# Core Photo Flutter Foundation Implementation Plan (Plan 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter Windows app foundation (API client, sidecar launcher, workflow state, dashboard + session) yang terbukti via flutter test + pytest.

**Architecture:** Flutter owns UI + workflow state only; all domain logic via localhost ApiClient to Python (Plan 1-2 server); SidecarLauncher resolves/starts core_service.exe + polls /healthz; no DB access from Flutter; Capture/Browser/Validation/Transfer/Settings screens are titled stubs for the next plan.

**Tech Stack:** Flutter 3.44.8, Dart 3.12.2, package:http, flutter_test, Python side (FastAPI existing)

## Global Constraints

- Windows 10/11 64-bit desktop only; single Setup.exe later (installer = later plan, not here).
- Flutter pemilik workflow state (`SESSION_CREATED → CAMERA_READY → TRAY_INPUT → READY_TO_CAPTURE → CAPTURING → REVIEWING → PROCESSING → VALIDATING → TRAY_COMPLETED`), Python pemilik job state.
- Localhost hanya 127.0.0.1, default port contoh 42839 (configurable, bukan business rule); token header optional, server belum auth.
- `To < From` → warning + Capture disabled (UI mirror + server canonical).
- Filename format dipertahankan; parser/validator tetap di Python.
- Semua offline kecuali Transfer. Tanpa fitur di luar PRD. Satu-satunya dep Dart baru: `package:http`.
- Server sessions di plan ini IN-MEMORY (bentuk respons final); persistensi SQLite = plan backend berikutnya.

---

## Scope Check

Sisa roadmap: Plan 3 (ini: Flutter foundation + dashboard + session), Plan 4 (Capture/Review/Browser/Validation/Transfer screens), Plan 5 (SQLite persistence + Inno Setup + Transfer backend), Plan 6 (adapter vendor Canon/Nikon/Sony, fase hardware). Tiap plan menghasilkan software jalan + teruji sendiri.

## File Structure

- `apps/flutter_app/` — `flutter create --platforms=windows --org com.corephoto --project-name core_photo` + `flutter pub add http`.
- `apps/flutter_app/lib/api_client.dart` — `ApiException`, `ApiClient(baseUrl, token?, httpClient?)`: `health/validateInterval/jobStatus/cameraStatus/capture/createSession/listSessions/activateSession/activeSession`.
- `apps/flutter_app/lib/workflow.dart` — `AppStage` enum + `WorkflowState extends ChangeNotifier` dengan guard transisi.
- `apps/flutter_app/lib/sidecar.dart` — `SidecarLauncher(starter?, pollInterval)`: `resolveExe strongest, `waitForHealthy`, `launch`, `stop`, `running`.
- `apps/flutter_app/lib/session.dart` — `SessionInfo{id,date,operator,site}` + `SessionService(api)`.
- `apps/flutter_app/lib/screens/session_screen.dart` — form Date/Operator/Site + Create + list + activate.
- `apps/flutter_app/lib/screens/stubs.dart` — `CaptureScreen/BrowserScreen/ValidationScreen/TransferScreen/SettingsScreen` (titled stubs).
- `apps/flutter_app/lib/screens/dashboard_screen.dart` — judul + status kamera + tombol navigasi.
- `apps/flutter_app/lib/main.dart` — `CorePhotoApp` (nav index state) + `main()` wiring default `http://127.0.0.1:42839`.
- `apps/flutter_app/test/` — `api_client_test.dart`, `workflow_test.dart`, `sidecar_test.dart`, `session_screen_test.dart`, `app_test.dart` (HttpServer stub dart:io, tanpa dep test baru).
- Modify: `services/core_service/app/main.py` — tambah in-memory sessions endpoints (Task 1).
- `services/core_service/tests/test_sessions.py` — kontrak respons sessions.

---

### Task 1: Server in-memory sessions endpoints (kontrak final, persistensi menyusul)

**Files:**
- Modify: `services/core_service/app/main.py` (append before `return app`; add `import time`)
- Test: `services/core_service/tests/test_sessions.py`

**Interfaces:**
- Consumes: existing `create_app()` (jangan ubah rute lain)
- Produces: `POST /sessions → {session}`, `GET /sessions → {sessions:[]}`, `POST /sessions/{id}/activate → {active}`, `GET /sessions/active → {active|null}` (Task 6 Flutter `SessionService` memakai bentuk ini verbatim)

- [ ] **Step 1: Write the failing test**

```python
# services/core_service/tests/test_sessions.py
from fastapi.testclient import TestClient
from app.main import create_app


def test_create_lists_and_activates():
    c = TestClient(create_app())
    s1 = c.post("/sessions", json={"date": "2026-09-13", "operator": "Dimas", "site": "SiteA"}).json()["session"]
    assert s1["id"] == "s1" and s1["operator"] == "Dimas"
    s2 = c.post("/sessions", json={"date": "2026-09-13", "operator": "Ricky", "site": "SiteA"}).json()["session"]
    assert c.get("/sessions").json()["sessions"][0]["id"] == "s1"
    assert c.get("/sessions/active").json()["active"]["id"] == "s2"
    assert c.post("/sessions/s1/activate").json()["active"]["id"] == "s1"


def test_activate_unknown_is_404():
    c = TestClient(create_app())
    r = c.post("/sessions/nope/activate")
    assert r.status_code == 404
```

- [ ] **Step 2: Run test to verify it fails**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests/test_sessions.py -v`
Expected: FAIL with 404 on `/sessions` (no route yet)

- [ ] **Step 3: Write minimal implementation**

In `services/core_service/app/main.py`: add `import time` to imports; module-level (next to `camera_manager`):

```python
_sessions: dict = {}
_active_session_id: str | None = None
```

Insert before `return app` inside `create_app`:

```python
    @app.post("/sessions", status_code=201)
    def create_session(payload: dict) -> dict:
        global _active_session_id
        sid = f"s{len(_sessions) + 1}"
        session = {"id": sid, "date": str(payload.get("date", "")), "operator": str(payload.get("operator", "")), "site": str(payload.get("site", "")), "created_at": time.time()}
        _sessions[sid] = session
        _active_session_id = sid
        return {"session": session}

    @app.get("/sessions")
    def list_sessions() -> dict:
        return {"sessions": list(_sessions.values())}

    @app.post("/sessions/{sid}/activate")
    def activate_session(sid: str):
        global _active_session_id
        if sid not in _sessions:
            return JSONResponse(status_code=404, content={"error": f"unknown session {sid}"})
        _active_session_id = sid
        return {"active": _sessions[sid]}

    @app.get("/sessions/active")
    def active_session() -> dict:
        return {"active": _sessions.get(_active_session_id)}
```

(`JSONResponse` already imported in main.py. Create auto-activates: session baru = konteks aktif PRD §5.)

- [ ] **Step 4: Run test to verify it passes**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests/test_sessions.py services/core_service/tests/test_api.py -v`
Expected: PASS (2 + 2 passed, no regression)

- [ ] **Step 5: Commit**

```bash
git add services/core_service/app/main.py services/core_service/tests/test_sessions.py
git commit -m "feat: add in-memory sessions endpoints (SQLite later)"
```

---

### Task 2: Flutter project scaffold + smoke test

**Files:**
- Create: `apps/flutter_app/` via flutter create (windows only) + `flutter pub add http`
- Create: `apps/flutter_app/test/app_smoke_test.dart` (ganti default widget_test bila ada)

**Interfaces:**
- Consumes: nothing
- Produces: runnable `apps/flutter_app` with `package:http`, `flutter test` green (Tasks 3-7 add lib/test files)

- [ ] **Step 1: Write the failing test**

```dart
// apps/flutter_app/test/app_smoke_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder replaced by real smoke test in Step 3', () {
    expect(true, isTrue);
  });
}
```

(This placeholder exists only to prove `flutter test` runs pre-scaffold; it is REPLACED in Step 3.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test apps/flutter_app` (from repo root; or `flutter test` inside `apps/flutter_app`)
Expected: FAIL — directory does not exist yet (`flutter test` errors "No such file")

- [ ] **Step 3: Write minimal implementation**

```bash
flutter create --platforms=windows --org com.corephoto --project-name core_photo apps/flutter_app
flutter pub add http
```

Then replace `apps/flutter_app/test/widget_test.dart` (delete it) with:

```dart
// apps/flutter_app/test/app_smoke_test.dart
import 'package:core_photo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app pumps with Core Photo title', (tester) async {
    await tester.pumpWidget(const CorePhotoApp(apiBaseUrl: 'http://127.0.0.1:9'));
    expect(find.text('Core Photo'), findsWidgets); // AppBar + body
  });
}
```

And minimal `apps/flutter_app/lib/main.dart` (full file; screens arrive in Tasks 6-7, keep stubs inline here for now — Tasks 6-7 will extract them):

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const CorePhotoApp(apiBaseUrl: 'http://127.0.0.1:42839'));
}

class CorePhotoApp extends StatelessWidget {
  const CorePhotoApp({super.key, required this.apiBaseUrl});
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Core Photo',
      home: Scaffold(
        appBar: AppBar(title: const Text('Core Photo')),
        body: const Center(child: Text('Core Photo')),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test apps/flutter_app`
Expected: PASS (All tests passed)

- [ ] **Step 5: Commit**

```bash
git add apps/flutter_app
git commit -m "feat: scaffold Flutter windows app + smoke test"
```

NOTE: `apps/flutter_app/build/`, `.dart_tool/` are gitignored — verify `git status --short` shows no `build/` or `.dart_tool/` entries before committing; if shown, STOP and fix .gitignore first.

---

### Task 3: ApiClient + stub-server tests

**Files:**
- Create: `apps/flutter_app/lib/api_client.dart`
- Test: `apps/flutter_app/test/api_client_test.dart`

**Interfaces:**
- Consumes: server contract (Plan 1-2 + Task 1 shapes, verbatim paths/keys)
- Produces: `ApiException`, `ApiClient` with `health/validateInterval/jobStatus/cameraStatus/capture/createSession/listSessions/activateSession/activeSession` (Tasks 5-7 consume exact names)

- [ ] **Step 1: Write the failing test**

```dart
// apps/flutter_app/test/api_client_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:core_photo/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

Future<HttpServer> _stub(Map<String, dynamic> Function(String method, String path) route) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final body = await utf8.decoder.bind(req).join();
    final out = route(req.method, req.uri.path);
    req.response
      ..statusCode = out.remove('__status') ?? 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(out));
    await req.response.close();
  });
  return server;
}

void main() {
  test('health returns ok + token header sent when provided', () async {
    String? auth;
    final server = await _stub((m, p) => {'ok': true});
    addTearDown(server.close);
    server.listen((req) async {});
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}', token: 't123');
    final r = await api.health();
    expect(r['ok'], isTrue);
    expect(auth, isNull); // header asserted in Step 3 implementation test below
  });

  test('validateInterval posts from/to and reads captureEnabled', () async {
    late Map<String, dynamic> seen;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      seen = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'valid': false, 'captureEnabled': false, 'warning': 'To < From'}));
      await req.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final r = await api.validateInterval(20, 10);
    expect(r['captureEnabled'], isFalse);
    expect(seen, {'from': 20.0, 'to': 10.0});
  });

  test('non-2xx throws ApiException with status', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      req.response.statusCode = 404;
      await req.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    expect(() => api.activeSession(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
  });
}
```

NOTE: first test's `_stub` helper double-listens (bug on purpose? NO — fix now): the `_stub` helper as written is WRONG (route ignores body/auth, second listen crashes). Use EXACTLY the corrected Step 3 test file instead — Step 1 file above is only to produce FAIL (missing `api_client.dart` import fails at compile). Keep Step 1 file as-is for red; Step 3 replaces the whole file with the corrected version below.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test apps/flutter_app/test/api_client_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:core_photo/api_client.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/flutter_app/lib/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({required this.baseUrl, this.token, http.Client? httpClient}) : _http = httpClient ?? http.Client();
  final String baseUrl;
  final String? token;
  final http.Client _http;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> getJson(String path) async => _decode(await _http.get(Uri.parse('$baseUrl$path'), headers: _headers));

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async =>
      _decode(await _http.post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body)));

  Map<String, dynamic> _decode(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) throw ApiException(r.body, r.statusCode);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> health() => getJson('/healthz');
  Future<Map<String, dynamic>> validateInterval(double from, double to) => postJson('/trays/validate-interval', {'from': from, 'to': to});
  Future<Map<String, dynamic>> jobStatus(String id) => getJson('/jobs/$id');
  Future<Map<String, dynamic>> cameraStatus() => getJson('/camera/status');
  Future<Map<String, dynamic>> capture({required String filename, required List<int> box, required String outDir}) =>
      postJson('/captures', {'filename': filename, 'box': box, 'out_dir': outDir});
  Future<Map<String, dynamic>> createSession({required String date, required String operator, required String site}) =>
      postJson('/sessions', {'date': date, 'operator': operator, 'site': site});
  Future<Map<String, dynamic>> listSessions() => getJson('/sessions');
  Future<Map<String, dynamic>> activateSession(String id) => postJson('/sessions/$id/activate', {});
  Future<Map<String, dynamic>> activeSession() => getJson('/sessions/active');
}
```

Replace the test file with the CORRECTED version (single listen per server, asserts auth header + body):

```dart
// apps/flutter_app/test/api_client_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:core_photo/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('health returns ok + sends bearer token', () async {
    String? auth;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      auth = req.headers.value('authorization');
      await utf8.decoder.bind(req).join();
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'ok': true}));
      await req.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}', token: 't123');
    expect((await api.health())['ok'], isTrue);
    expect(auth, 'Bearer t123');
  });

  test('validateInterval posts from/to and reads captureEnabled', () async {
    late Map<String, dynamic> seen;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      seen = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'valid': false, 'captureEnabled': false, 'warning': 'To < From'}));
      await req.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final r = await api.validateInterval(20, 10);
    expect(r['captureEnabled'], isFalse);
    expect(seen, {'from': 20.0, 'to': 10.0});
  });

  test('non-2xx throws ApiException with status', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      req.response.statusCode = 404;
      await req.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    expect(() => api.activeSession(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test apps/flutter_app/test/api_client_test.dart`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add apps/flutter_app/lib/api_client.dart apps/flutter_app/test/api_client_test.dart
git commit -m "feat: add ApiClient localhost + stub-server tests"
```

---

### Task 4: WorkflowState machine (Flutter-owned per spec)

**Files:**
- Create: `apps/flutter_app/lib/workflow.dart`
- Test: `apps/flutter_app/test/workflow_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `AppStage` (9 values), `WorkflowState extends ChangeNotifier` with `stage/canCapture/setIntervalValid/toTrayInput/toReadyToCapture/toCapturing/toReviewing/toProcessing/retake/toValidating/completeTray/nextTray/cameraReady` (Tasks 6-7 + Plan 4 consume exact names)

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test apps/flutter_app/test/workflow_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:core_photo/workflow.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test apps/flutter_app/test/workflow_test.dart`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add apps/flutter_app/lib/workflow.dart apps/flutter_app/test/workflow_test.dart
git commit -m "feat: add Flutter-owned workflow state machine with capture guards"
```

---

### Task 5: SidecarLauncher (resolve + waitForHealthy + launch/stop)

**Files:**
- Create: `apps/flutter_app/lib/sidecar.dart`
- Test: `apps/flutter_app/test/sidecar_test.dart`

**Interfaces:**
- Consumes: server `GET /healthz` shape `{ok:true}` (Plan 1)
- Produces: `SidecarLauncher(starter?, pollInterval?)` with `resolveExe/flutterExeDir/overridePath`, `waitForHealthy(healthUrl, timeout?, poll?)`, `launch/stop/running` (Plan 5 installer consumes; `launch` body thin, tested for throw-path + no-op stop only)

- [ ] **Step 1: Write the failing test**

```dart
// apps/flutter_app/test/sidecar_test.dart
import 'dart:io';
import 'package:core_photo/sidecar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveExe prefers override, else joins dir', () {
    final l = SidecarLauncher();
    expect(l.resolveExe('C:\\app', overridePath: 'D:\\svc.exe'), 'D:\\svc.exe');
    expect(l.resolveExe('C:\\app'), 'C:\\app${Platform.pathSeparator}core_service.exe');
  });

  test('waitForHealthy true against stub, false on closed port', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      req.response
        ..headers.contentType = ContentType.json
        ..write('{"ok":true,"version":"0.1.0"}');
      await req.response.close();
    });
    expect(await SidecarLauncher.waitForHealthy(Uri.parse('http://127.0.0.1:${server.port}/healthz')), isTrue);
    expect(
      await SidecarLauncher.waitForHealthy(Uri.parse('http://127.0.0.1:9/healthz'), timeout: const Duration(milliseconds: 300)),
      isFalse,
    );
  });

  test('stop without process is no-op; failed starter leaves not-running', () async {
    final l = SidecarLauncher(starter: (_, __) => throw const SocketException('no exe'));
    l.stop();
    expect(l.running, isFalse);
    await expectLater(() => l.launch('missing.exe', Uri.parse('http://127.0.0.1:9/healthz')), throwsA(isA<SocketException>()));
    expect(l.running, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test apps/flutter_app/test/sidecar_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:core_photo/sidecar.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/flutter_app/lib/sidecar.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef ProcessStarter = Future<Process> Function(String exe, List<String> args);

class SidecarLauncher {
  SidecarLauncher({ProcessStarter? starter, this.pollInterval = const Duration(milliseconds: 200)})
      : _starter = starter ?? Process.start;
  final ProcessStarter _starter;
  final Duration pollInterval;
  Process? _proc;

  bool get running => _proc != null;

  String resolveExe(String flutterExeDir, {String? overridePath}) {
    if (overridePath != null && overridePath.isNotEmpty) return overridePath;
    return '$flutterExeDir${Platform.pathSeparator}core_service.exe';
  }

  static Future<bool> waitForHealthy(Uri healthUrl, {Duration timeout = const Duration(seconds: 15), Duration poll = const Duration(milliseconds: 200)}) async {
    final deadline = DateTime.now().add(timeout);
    final client = HttpClient();
    try {
      while (DateTime.now().isBefore(deadline)) {
        try {
          final req = await client.getUrl(healthUrl);
          final resp = await req.close().timeout(const Duration(seconds: 2));
          final body = await resp.transform(utf8.decoder).join();
          if (resp.statusCode == 200 && body.contains('"ok":true')) return true;
        } catch (_) {}
        await Future.delayed(poll);
      }
      return false;
    } finally {
      client.close();
    }
  }

  Future<bool> launch(String exePath, Uri healthUrl) async {
    if (running) return true;
    _proc = await _starter(exePath, const []);
    return waitForHealthy(healthUrl, poll: pollInterval);
  }

  void stop() {
    _proc?.kill();
    _proc = null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test apps/flutter_app/test/sidecar_test.dart`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add apps/flutter_app/lib/sidecar.dart apps/flutter_app/test/sidecar_test.dart
git commit -m "feat: add sidecar launcher resolve + health-wait + stop"
```

---

### Task 6: Session model/service/screen (PRD §5/§20.2)

**Files:**
- Create: `apps/flutter_app/lib/session.dart`
- Create: `apps/flutter_app/lib/screens/session_screen.dart`
- Test: `apps/flutter_app/test/session_screen_test.dart`

**Interfaces:**
- Consumes: `ApiClient.createSession/listSessions/activateSession` (Task 3 exact shapes: `{session}`, `{sessions:[]}`, `{active}`)
- Produces: `SessionInfo`, `SessionService`, `SessionScreen({api, workflow})` (Task 7 wires it; Plan 4 reuses `SessionService`)

- [ ] **Step 1: Write the failing test**

```dart
// apps/flutter_app/test/session_screen_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:core_photo/api_client.dart';
import 'package:core_photo/screens/session_screen.dart';
import 'package:core_photo/workflow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<HttpServer> _server(List<Map<String, dynamic>> sessions) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final body = await utf8.decoder.bind(req).join();
    Object out;
    if (req.method == 'GET') {
      out = {'sessions': sessions};
    } else {
      final b = jsonDecode(body) as Map<String, dynamic>;
      final s = {'id': 's${sessions.length + 1}', 'date': b['date'], 'operator': b['operator'], 'site': b['site']};
      sessions.add(s);
      out = {'session': s};
    }
    req.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(out));
    await req.response.close();
  });
  return server;
}

void main() {
  testWidgets('create session appears in list', (tester) async {
    final sessions = <Map<String, dynamic>>[];
    final server = await _server(sessions);
    addTearDown(server.close);
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    await tester.pumpWidget(MaterialApp(home: SessionScreen(api: api, workflow: WorkflowState())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('date')), '2026-09-13');
    await tester.enterText(find.byKey(const Key('operator')), 'Dimas');
    await tester.enterText(find.byKey(const Key('site')), 'SiteA');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dimas'), findsOneWidget);
  });

  testWidgets('empty operator shows error and sends nothing', (tester) async {
    var calls = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      if (req.method == 'POST') calls++;
      req.response.statusCode = 500;
      await req.response.close();
    });
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    await tester.pumpWidget(MaterialApp(home: SessionScreen(api: api, workflow: WorkflowState())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('date')), '2026-09-13');
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(find.text('Operator wajib diisi'), findsOneWidget);
    expect(calls, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test apps/flutter_app/test/session_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:core_photo/session.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/flutter_app/lib/session.dart
import 'api_client.dart';

class SessionInfo {
  SessionInfo({required this.id, required this.date, required this.operator, required this.site});
  final String id;
  final String date;
  final String operator;
  final String site;

  factory SessionInfo.fromJson(Map<String, dynamic> j) =>
      SessionInfo(id: '${j['id']}', date: '${j['date']}', operator: '${j['operator']}', site: '${j['site']}');
}

class SessionService {
  SessionService(this.api);
  final ApiClient api;

  Future<SessionInfo> create({required String date, required String operator, required String site}) async {
    final r = await api.createSession(date: date, operator: operator, site: site);
    return SessionInfo.fromJson(r['session'] as Map<String, dynamic>);
  }

  Future<List<SessionInfo>> list() async {
    final r = await api.listSessions();
    return (r['sessions'] as List).map((e) => SessionInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SessionInfo> activate(String id) async {
    final r = await api.activateSession(id);
    return SessionInfo.fromJson(r['active'] as Map<String, dynamic>);
  }
}
```

```dart
// apps/flutter_app/lib/screens/session_screen.dart
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../session.dart';
import '../workflow.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.api, required this.workflow});
  final ApiClient api;
  final WorkflowState workflow;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _date = TextEditingController(text: '2026-09-13');
  final _operator = TextEditingController();
  final _site = TextEditingController();
  String? _error;
  List<SessionInfo> _sessions = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final list = await SessionService(widget.api).list();
      if (mounted) setState(() => _sessions = list);
    } catch (_) {}
  }

  Future<void> _create() async {
    if (_operator.text.trim().isEmpty) {
      setState(() => _error = 'Operator wajib diisi');
      return;
    }
    setState(() => _error = null);
    try {
      await SessionService(widget.api).create(date: _date.text.trim(), operator: _operator.text.trim(), site: _site.text.trim());
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
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
          for (final s in _sessions) ListTile(title: Text('${s.operator} @ ${s.site}'), subtitle: Text('${s.date} · ${s.id}')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test apps/flutter_app/test/session_screen_test.dart`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add apps/flutter_app/lib/session.dart apps/flutter_app/lib/screens/session_screen.dart apps/flutter_app/test/session_screen_test.dart
git commit -m "feat: add session model service screen per PRD-5"
```

---

### Task 7: Dashboard shell + navigation + main wiring

**Files:**
- Create: `apps/flutter_app/lib/screens/stubs.dart`
- Create: `apps/flutter_app/lib/screens/dashboard_screen.dart`
- Modify: `apps/flutter_app/lib/main.dart` (full replacement below)
- Test: `apps/flutter_app/test/app_test.dart` (replaces `app_smoke_test.dart` — delete it)

**Interfaces:**
- Consumes: `ApiClient.cameraStatus` (Task 3), `WorkflowState` (Task 4), `SessionScreen` (Task 6)
- Produces: `CorePhotoApp(apiBaseUrl:, api?)` wiring titik tunggal (Plan 4 menambah Capture/dst; Plan 5 wiring sidecar launch)

- [ ] **Step 1: Write the failing test**

```dart
// apps/flutter_app/test/app_test.dart
import 'package:core_photo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard shows title and navigates to session', (tester) async {
    await tester.pumpWidget(const CorePhotoApp(apiBaseUrl: 'http://127.0.0.1:9'));
    await tester.pumpAndSettle();
    expect(find.text('Core Photo'), findsWidgets);
    await tester.tap(find.widgetWithText(ListTile, 'Session'));
    await tester.pumpAndSettle();
    expect(find.text('Operator'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test apps/flutter_app/test/app_test.dart`
Expected: FAIL — `Target of URI doesn't exist` (no stubs/dashboard yet; main.dart has no 'Session' button)

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/flutter_app/lib/screens/stubs.dart
import 'package:flutter/material.dart';

class _Stub extends StatelessWidget {
  const _Stub(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(title)), body: Center(child: Text('$title (Plan 4)')));
  }
}

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub('Capture');
}

class BrowserScreen extends StatelessWidget {
  const BrowserScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub('Photo Browser');
}

class ValidationScreen extends StatelessWidget {
  const ValidationScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub('Validation');
}

class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub('Transfer');
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub('Settings');
}
```

```dart
// apps/flutter_app/lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import '../api_client.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.api, required this.onOpen});
  final ApiClient api;
  final void Function(int index) onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Core Photo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: api.cameraStatus().catchError((_) => {'status': 'Unknown'}),
            builder: (context, snap) => Text('Camera: ${snap.data?['status'] ?? '...'}'),
          ),
          for (final entry in const {'Session': 1, 'Capture': 2, 'Photo Browser': 3, 'Validation': 4, 'Transfer': 5, 'Settings': 6}.entries)
            ListTile(title: Text(entry.key), onTap: () => onOpen(entry.value)),
        ],
      ),
    );
  }
}
```

Replace `apps/flutter_app/lib/main.dart` fully:

```dart
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
      DashboardScreen(api: _api, onOpen: (i) => setState(() => _index = i)),
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
          onTap: (i) => setState(() => _index = i),
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
```

Delete `apps/flutter_app/test/app_smoke_test.dart` (superseded by app_test.dart).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test apps/flutter_app`
Expected: PASS (all Task 2-7 tests; smoke file gone)

- [ ] **Step 5: Commit**

```bash
git add apps/flutter_app/lib apps/flutter_app/test
git commit -m "feat: add dashboard shell nav stubs + main wiring"
```

---

### Task 8: Full gates + push

**Files:**
- Modify: none (verification only)

- [ ] **Step 1: Run Flutter gates**

Run: `flutter analyze apps/flutter_app`
Expected: `No issues found!`

Run: `flutter test apps/flutter_app`
Expected: PASS all (2 + 3 + 2 + 3 + 2 + 1 = 13 tests: api_client 3, workflow 2, sidecar 3, session_screen 2, app 1... recount at runtime, all must pass)

- [ ] **Step 2: Run Python gate (no regression)**

Run: `$env:PYTHONPATH='services/core_service'; python -m pytest services/core_service/tests -v`
Expected: PASS (30 + 2 sessions = 32 passed)

- [ ] **Step 3: Push**

```bash
git push origin main
```
Expected: up-to-date remote `main`

## Self-Review

1. **Spec coverage:** kontrak localhost §2 → Task 3 ApiClient (paths/keys verbatim) + Task 1 sessions; workflow §21 → Task 4 (9 stages, guards, retake/nextTray); sidecar lifecycle §1 → Task 5 (resolve/wait/stop; launch covered throw-path; full launch integration = Plan 5 installer test); Session §5/§20.2 → Task 6; Dashboard §20.1 → Task 7 (status + 6 akses). Capture §20.3/Review §20.4/Browser §20.5/Validation §20.6/Transfer §20.7 = Plan 4 stubs bertitel eksplisit.
2. **Placeholder scan:** no TBD/TODO; Task 3 Step 1 NOTE is explicit replace-instruction (red-only scaffold, replaced Step 3 same task) — acceptable, not a placeholder. `(Plan 4)` stub labels are intentional scope markers, not placeholders.
3. **Type consistency:** `ApiClient` method names identical Tasks 3/6/7; `SessionInfo{id,date,operator,site}` server↔Dart keys match Task 1 (`id/date/operator/site`); `WorkflowState` member names identical Tasks 4/6/7; `CorePhotoApp(apiBaseUrl:, api?)` Task 2 smoke vs Task 7 (apiBaseUrl kept, api optional added — backward compatible); default port 42839 in main() + smoke uses dead :9 intentionally.
