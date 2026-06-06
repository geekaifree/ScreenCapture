import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

void main() => runApp(const ScreenCaptureApp());

class ScreenCaptureApp extends StatelessWidget {
  const ScreenCaptureApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '截图工具', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.pink, useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(colorSchemeSeed: Colors.pink, useMaterial3: true, brightness: Brightness.dark),
    home: const CaptureHomePage(),
  );
}

class CaptureRecord {
  String id, name, mode;
  DateTime time;
  int width, height;
  CaptureRecord({required this.id, required this.name, required this.mode, required this.time, required this.width, required this.height});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'mode': mode, 'time': time.toIso8601String(), 'w': width, 'h': height};
  factory CaptureRecord.fromJson(Map<String, dynamic> j) => CaptureRecord(id: j['id'], name: j['name'], mode: j['mode'], time: DateTime.parse(j['time']), width: j['w'], height: j['h']);
}

class CaptureHomePage extends StatefulWidget {
  const CaptureHomePage({super.key});
  @override
  State<CaptureHomePage> createState() => _CaptureHomePageState();
}

class _CaptureHomePageState extends State<CaptureHomePage> {
  List<CaptureRecord> _records = [];
  String _mode = '全屏';
  final _modes = ['全屏', '窗口', '区域', '滚动'];
  int _delay = 0;
  bool _showCursor = true;
  String _format = 'PNG';
  final _formats = ['PNG', 'JPG', 'WebP', 'BMP'];
  Color _drawColor = Colors.red;
  double _drawWidth = 3;
  List<Offset> _drawPoints = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final d = p.getString('capture_records');
    if (d != null) setState(() => _records = (json.decode(d) as List).map((e) => CaptureRecord.fromJson(e)).toList());
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('capture_records', json.encode(_records.map((e) => e.toJson()).toList()));
  }

  void _capture() {
    final rng = Random();
    final w = _mode == '区域' ? 800 + rng.nextInt(400) : 1920;
    final h = _mode == '区域' ? 600 + rng.nextInt(300) : 1080;
    final record = CaptureRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '截图_${DateTime.now().hour}${DateTime.now().minute}${DateTime.now().second}',
      mode: _mode, time: DateTime.now(), width: w, height: h,
    );
    setState(() => _records.insert(0, record));
    _save();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('截图完成: ${record.name} (${w}x$h)'), behavior: SnackBarBehavior.floating));
  }

  void _deleteRecord(CaptureRecord r) { setState(() => _records.removeWhere((i) => i.id == r.id)); _save(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📷 截图工具'), centerTitle: true, actions: [
        PopupMenuButton<String>(icon: const Icon(Icons.more_vert), itemBuilder: (ctx) => [
          PopupMenuItem(value: 'clear', child: const Text('清空历史')),
        ], onSelected: (v) { if (v == 'clear') { setState(() => _records.clear()); _save(); } }),
      ]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 截图模式选择
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('截图模式', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: _modes.map((m) {
            final icons = {'全屏': Icons.fullscreen, '窗口': Icons.window, '区域': Icons.crop, '滚动': Icons.swap_vert};
            return ChoiceChip(label: Text(m), selected: _mode == m, onSelected: (_) => setState(() => _mode = m), avatar: Icon(icons[m], size: 18));
          }).toList()),
        ]))),
        const SizedBox(height: 12),
        // 截图设置
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('截图设置', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            const Text('延迟: '), const SizedBox(width: 8),
            DropdownButton<int>(value: _delay, items: [0, 3, 5, 10].map((v) => DropdownMenuItem(value: v, child: Text('${v}秒'))).toList(), onChanged: (v) => setState(() => _delay = v!)),
            const Spacer(),
            const Text('格式: '), const SizedBox(width: 8),
            DropdownButton<String>(value: _format, items: _formats.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _format = v!)),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(title: const Text('显示鼠标指针'), value: _showCursor, onChanged: (v) => setState(() => _showCursor = v), dense: true, contentPadding: EdgeInsets.zero),
        ]))),
        const SizedBox(height: 12),
        // 标注工具
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('标注工具', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            const Text('画笔颜色: '), const SizedBox(width: 8),
            ...([Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.black].map((c) => GestureDetector(
              onTap: () => setState(() => _drawColor = c),
              child: Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: _drawColor == c ? Colors.white : Colors.transparent, width: 2), boxShadow: _drawColor == c ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 4)] : null)),
            ))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Text('画笔粗细: '), const SizedBox(width: 8),
            Expanded(child: Slider(value: _drawWidth, min: 1, max: 10, divisions: 9, label: '${_drawWidth.toInt()}px', onChanged: (v) => setState(() => _drawWidth = v))),
          ]),
        ]))),
        const SizedBox(height: 16),
        // 截图按钮
        SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(onPressed: _capture, icon: const Icon(Icons.camera_alt, size: 28), label: Text(_delay > 0 ? '截图 (${_delay}秒延迟)' : '立即截图', style: const TextStyle(fontSize: 18)), style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
        const SizedBox(height: 20),
        // 历史记录
        if (_records.isNotEmpty) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('截图历史 (${_records.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 8),
          ...(_records.take(20).map((r) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
            leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(8)), child: const Center(child: Icon(Icons.image, color: Colors.pink))),
            title: Text(r.name),
            subtitle: Text('${r.mode} • ${r.width}x${r.height} • ${_formatTime(r.time)}'),
            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteRecord(r)),
          )))),
        ],
      ])),
    );
  }

  String _formatTime(DateTime t) => '${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
}
