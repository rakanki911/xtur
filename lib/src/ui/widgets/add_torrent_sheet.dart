// lib/src/ui/widgets/add_torrent_sheet.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../torrent_manager.dart';

class AddTorrentSheet extends StatefulWidget {
  const AddTorrentSheet({super.key});

  @override
  State<AddTorrentSheet> createState() => _AddTorrentSheetState();
}

class _AddTorrentSheetState extends State<AddTorrentSheet> {
  final _magnetCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final mgr = context.watch<TorrentManager>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('إضافة تورنت', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: CupertinoTextField(
                controller: _magnetCtrl,
                placeholder: 'رابط Magnet (غير مدعوم حاليًا)',
                enabled: false, // معطّل الآن لأن المحرك لا يدعم Magnet
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: () async {
                final res = await FilePicker.platform.pickFiles(
                  allowMultiple: false,
                  type: FileType.custom,
                  allowedExtensions: const ['torrent'],
                );
                if (res != null && res.files.single.path != null) {
                  // ignore: use_build_context_synchronously
                  await context.read<TorrentManager>().addFromTorrentFile(res.files.single.path!);
                  if (mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(CupertinoIcons.doc_on_clipboard),
              label: const Text('اختر ملف .torrent'),
            )
          ]),
          const SizedBox(height: 12),
          if (!mgr.magnetSupported)
            const Text(
              'ملاحظة: روابط Magnet غير مدعومة في المحرك الحالي. استخدم ملف .torrent.',
              style: TextStyle(fontSize: 12),
            ),
        ]),
      ),
    );
  }
}
