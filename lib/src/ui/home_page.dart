// lib/src/ui/home_page.dart
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../torrent_manager.dart';
import 'widgets/add_torrent_sheet.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final mgr = context.watch<TorrentManager>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('التحميلات (تورنت)'),
          actions: [
            IconButton(
              tooltip: 'مجلد الحفظ',
              onPressed: () async {
                final p = await mgr.downloadsPath;
                // ignore: use_build_context_synchronously
                showDialog(context: context, builder: (_) => AlertDialog(
                  title: const Text('مسار الحفظ'),
                  content: Text(p),
                ));
              },
              icon: const Icon(CupertinoIcons.folder),
            )
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(CupertinoIcons.add_circled),
          label: const Text('إضافة'),
          onPressed: () async {
            showModalBottomSheet(
              context: context,
              showDragHandle: true,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: const AddTorrentSheet(),
                ),
              ),
            );
          },
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(12, 90, 12, 90),
          child: mgr.items.isEmpty
              ? _EmptyState(magnetSupported: mgr.magnetSupported)
              : RefreshIndicator.adaptive(
                  onRefresh: () async {},
                  child: ListView.separated(
                    itemCount: mgr.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final it = mgr.items[i];
                      final pct = (it.progress * 100).toStringAsFixed(2);
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(it.displayName, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(value: it.progress, minHeight: 8),
                          ),
                          const SizedBox(height: 8),
                          Wrap(spacing: 12, runSpacing: 4, children: [
                            _Chip('اكتمال: $pct%'),
                            _Chip('سرعة ↓: ${it.dlSpeedKBs.toStringAsFixed(1)} kB/s'),
                            _Chip('سرعة ↑: ${it.ulSpeedKBs.toStringAsFixed(1)} kB/s'),
                            _Chip('Peers: ${it.peersActive}/${it.seeders}/${it.allPeers}'),
                            if (it.completed) const _Chip('تمت ✅'),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            FilledButton.tonal(
                              onPressed: () => context.read<TorrentManager>().pause(it.model.infoHashHex!),
                              child: const Text('إيقاف مؤقت'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: () => context.read<TorrentManager>().resume(it.model.infoHashHex!),
                              child: const Text('استئناف'),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => context.read<TorrentManager>().stop(it.model.infoHashHex!),
                              icon: const Icon(CupertinoIcons.trash),
                              label: const Text('إيقاف وإزالة'),
                            ),
                          ]),
                        ]),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool magnetSupported;
  const _EmptyState({required this.magnetSupported});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(CupertinoIcons.tray, size: 42),
        const SizedBox(height: 8),
        const Text('لا توجد تحميلات بعد'),
        const SizedBox(height: 8),
        Text(
          magnetSupported
              ? 'أضف رابط Magnet أو ملف .torrent للبدء'
              : 'أضف ملف .torrent للبدء (روابط Magnet غير مدعومة حاليًا)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ]),
    );
  }
}
