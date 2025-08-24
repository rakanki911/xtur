// lib/src/torrent_manager.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dtorrent_parser/dtorrent_parser.dart';
import 'package:dtorrent_task/src/task.dart';
import 'package:dtorrent_task/src/task_events.dart';
import 'package:dtorrent_common/dtorrent_common.dart';

final _log = Logger('TorrentManager');

class TorrentItem {
  final Torrent model;
  final TorrentTask task;
  final String saveDir;
  String displayName;
  double progress; // 0..1
  double dlSpeedKBs; // kB/s
  double ulSpeedKBs; // kB/s
  int peersActive;
  int seeders;
  int allPeers;
  bool completed;
  DateTime createdAt;

  TorrentItem({
    required this.model,
    required this.task,
    required this.saveDir,
    required this.displayName,
    this.progress = 0,
    this.dlSpeedKBs = 0,
    this.ulSpeedKBs = 0,
    this.peersActive = 0,
    this.seeders = 0,
    this.allPeers = 0,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class TorrentManager extends ChangeNotifier {
  final Map<String, TorrentItem> _itemsByHash = {};
  Timer? _pollTimer;
  late Directory _downloadsDir;

  List<TorrentItem> get items => _itemsByHash.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> init() async {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((rec) {
      // تجاهل: اطبع للديبج فقط
      if (kDebugMode) {
        // ignore: avoid_print
        print('${rec.level.name} ${rec.loggerName}: ${rec.message}');
      }
    });

    final appDoc = await getApplicationDocumentsDirectory();
    _downloadsDir = Directory('${appDoc.path}/Downloads');
    if (!await _downloadsDir.exists()) await _downloadsDir.create(recursive: true);

    // Poll للتحديثات كل 1.5 ثانية
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _tick());
  }

  Future<String> get downloadsPath async => _downloadsDir.path;

  Future<void> disposeAll() async {
    _pollTimer?.cancel();
    for (final it in _itemsByHash.values) {
      try { it.task.stop(); } catch (_) {}
    }
    _itemsByHash.clear();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // إضافة تورنت من ملف .torrent
  Future<void> addFromTorrentFile(String torrentFilePath) async {
    final model = await Torrent.parse(torrentFilePath); // من dtorrent_parser
    final name = _guessName(model) ?? 'Torrent';
    final saveDir = '${_downloadsDir.path}/$name';
    await Directory(saveDir).create(recursive: true);

    final task = TorrentTask.newTask(model, saveDir);

    // Listeners للأحداث
    final listener = task.createListener();
    listener
      ..on<TaskCompleted>((_) {
        final key = _hashKey(model);
        final it = _itemsByHash[key];
        if (it != null) {
          it.completed = true;
          notifyListeners();
        }
        _log.info('Task complete: $name');
        task.stop(); // يحرّر الموارد
      })
      ..on<TaskStopped>((_) => _log.info('Task stopped: $name'));

    // تشغيل
    await task.start();

    // إضافة Trackers عامة + DHT nodes لتحسين الإتصال
    findPublicTrackers().listen((urls) {
      for (final u in urls) {
        try { task.startAnnounceUrl(u, model.infoHashBuffer); } catch (_) {}
      }
    });
    for (final n in model.nodes) {
      try { task.addDHTNode(n); } catch (_) {}
    }

    final item = TorrentItem(
      model: model,
      task: task,
      saveDir: saveDir,
      displayName: name,
    );

    _itemsByHash[_hashKey(model)] = item;
    notifyListeners();
  }

  // NOTE: روابط Magnet غير مدعومة حالياً في dtorrent_task
  bool get magnetSupported => false;

  Future<void> pause(String infoHashHex) async {
    final it = _itemsByHash[infoHashHex];
    if (it == null) return;
    it.task.pause();
    notifyListeners();
  }

  Future<void> resume(String infoHashHex) async {
    final it = _itemsByHash[infoHashHex];
    if (it == null) return;
    it.task.resume();
    notifyListeners();
  }

  Future<void> stop(String infoHashHex) async {
    final it = _itemsByHash.remove(infoHashHex);
    if (it == null) return;
    try { it.task.stop(); } catch (_) {}
    notifyListeners();
  }

  String _hashKey(Torrent model) {
    // infoHash في dtorrent_parser متوفر بصيغة buffer/hex
    return model.infoHashHex ?? model.infoHashBuffer.toString();
  }

  String? _guessName(Torrent model) {
    if (model.name != null && model.name!.trim().isNotEmpty) return model.name!;
    try {
      if (model.files.isNotEmpty) return model.files.first.path.split(Platform.pathSeparator).first;
    } catch (_) {}
    return null;
  }

  void _tick() {
    bool changed = false;
    for (final it in _itemsByHash.values) {
      final t = it.task;
      // نفس طريقة المثال الرسمي للحساب: *1000/1024 => kB/s
      final dl = ((t.currentDownloadSpeed) * 1000 / 1024).toStringAsFixed(2);
      final ul = ((t.uploadSpeed) * 1000 / 1024).toStringAsFixed(2);
      final prog = t.progress.clamp(0, 1);

      final peersActive = t.connectedPeersNumber;
      final seeders = t.seederNumber;
      final allPeers = t.allPeersNumber;

      final newDl = double.tryParse(dl) ?? 0;
      final newUl = double.tryParse(ul) ?? 0;

      if (it.progress != prog ||
          it.dlSpeedKBs != newDl ||
          it.ulSpeedKBs != newUl ||
          it.peersActive != peersActive ||
          it.seeders != seeders ||
          it.allPeers != allPeers) {
        it.progress = prog;
        it.dlSpeedKBs = newDl;
        it.ulSpeedKBs = newUl;
        it.peersActive = peersActive;
        it.seeders = seeders;
        it.allPeers = allPeers;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }
}
