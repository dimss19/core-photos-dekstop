import 'package:core_photo/api_client.dart';
import 'package:flutter/material.dart';

/// Photo Browser: daftar foto lokal + search/filter Drillhole + thumbnail + info.
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _photos = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await widget.api.listPhotos();
      if (mounted) setState(() => _photos = List<Map<String, dynamic>>.from(res['photos'] as List));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.toLowerCase();
    final shown = _photos.where((p) =>
        q.isEmpty ||
        '${p['filename']}'.toLowerCase().contains(q) ||
        '${p['hole_id'] ?? ''}'.toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Browser')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            key: const Key('search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Search Drillhole', prefixIcon: Icon(Icons.search)),
          ),
        ),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('No photos'))
              : ListView(
                  children: [
                    for (final p in shown)
                      ListTile(
                        leading: Image.network(
                          widget.api.photoFileUrl(p['id'].toString(), 'thumb'),
                          width: 56,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.image),
                        ),
                        title: Text('${p['filename']}'),
                        subtitle: Text('${p['hole_id']} · ${p['interval_from']}–${p['interval_to']}'),
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('${p['filename']}'),
                            content: Image.network(
                              widget.api.photoFileUrl(p['id'].toString(), 'jpg'),
                              errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 64),
                            ),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ]),
    );
  }
}
