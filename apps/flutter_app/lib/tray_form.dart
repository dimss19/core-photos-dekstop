/// Tray form model murni (tanpa widget): 8 field PRD §7 + aturan §8.
/// `To < From` -> warning + capture disabled. Validasi lengkap milik server.
class TrayForm {
  TrayForm({
    this.holeId = '',
    this.trayId = '',
    this.intervalFrom = '',
    this.intervalTo = '',
    this.rows = '',
    this.length = '',
    this.width = '',
    this.comments = '',
  });

  String holeId;
  String trayId;
  String intervalFrom;
  String intervalTo;
  String rows;
  String length;
  String width;
  String comments;

  double? get fromValue => double.tryParse(intervalFrom.trim());
  double? get toValue => double.tryParse(intervalTo.trim());

  /// null = siap capture; string = warning yang ditampilkan + capture disabled.
  String? get warning {
    if (holeId.trim().isEmpty || trayId.trim().isEmpty) return 'Hole ID dan Tray ID wajib diisi';
    if (fromValue == null || toValue == null) return 'Interval From/To harus angka';
    if (toValue! < fromValue!) return 'To < From';
    return null;
  }

  bool get canCapture => warning == null;

  Map<String, dynamic> toJson(String sessionId) => {
        'session_id': sessionId,
        'hole_id': holeId.trim(),
        'tray_id': trayId.trim(),
        'interval_from': fromValue,
        'interval_to': toValue,
        'rows': int.tryParse(rows.trim()) ?? 0,
        'length': double.tryParse(length.trim()),
        'width': double.tryParse(width.trim()),
        'comments': comments.trim(),
      };

  /// `Core01_1_000.00_2.60.jpg` — From dipad total 6 char warisan
  /// (`000.00`), To tanpa pad (`2.60`), persis contoh PRD §14.
  String filename() {
    final f = fromValue!.toStringAsFixed(2).padLeft(6, '0');
    final t = toValue!.toStringAsFixed(2);
    return '${holeId.trim()}_${trayId.trim()}_${f}_$t.jpg';
  }
}
