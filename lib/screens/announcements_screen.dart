import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  static const _tags = ['Penting', 'Evakuasi', 'Iuran', 'Kegiatan', 'Info'];

  Color _tagColor(String tag) => switch (tag) {
        'Penting' => kRed,
        'Evakuasi' => const Color(0xFFB3261E),
        'Iuran' => kTeal,
        'Kegiatan' => kPurple,
        _ => kBlue,
      };

  void _addDialog(BuildContext context) {
    final title = TextEditingController();
    final body = TextEditingController();
        var tag = _tags.first;
    String? error;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Buat pengumuman'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tujuan: ${Regions.shortName(AppState.instance.myAuthorityArea)}\nTag Penting dan Evakuasi juga dikirim sebagai notifikasi ke warga.',
                  style: const TextStyle(fontSize: 12, color: kGray),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in _tags)
                      ChoiceChip(
                        label: Text(t),
                        selected: tag == t,
                        onSelected: (_) => setLocal(() => tag = t),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: 'Judul',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: body,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Isi'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) {
                  setLocal(() => error = 'Judul wajib diisi');
                  return;
                }
                AppState.instance
                    .addAnnouncement(tag, title.text.trim(), body.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Terbitkan'),
            ),
          ],
        ),
      ),
    ).then((_) {
      title.dispose();
      body.dispose();
    });
  }

  String _target(Announcement a) {
    final r = Regions.byId(a.areaId);
    if (r == null) return '';
    return switch (r.level) {
      RegionLevel.rt || RegionLevel.rw => 'Untuk ${Regions.shortName(a.areaId)}',
      _ => 'Untuk seluruh ${Regions.label(a.areaId)}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        final list = s.myAnnouncements;
        return Scaffold(
          appBar: AppBar(title: const Text('Pengumuman')),
          floatingActionButton: s.canPostAnnouncement
              ? FloatingActionButton.extended(
                  backgroundColor: kRed,
                  foregroundColor: Colors.white,
                  onPressed: () => _addDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Buat'),
                )
              : null,
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.campaign_outlined,
                  text: 'Belum ada pengumuman untuk wilayah Anda.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final a = list[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                StatusChip(label: a.tag, color: _tagColor(a.tag)),
                                if (a.pinned) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.push_pin, size: 16, color: kGray),
                                ],
                                const Spacer(),
                                if (s.canManageAnnouncement(a))
                                  IconButton(
                                    tooltip: a.pinned ? 'Lepas sematan' : 'Sematkan',
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(a.pinned
                                        ? Icons.push_pin
                                        : Icons.push_pin_outlined),
                                    onPressed: () => s.togglePin(a),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(a.title,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(a.body),
                            const SizedBox(height: 8),
                            Text(
                              '${_target(a)} - ${a.author} - ${timeAgo(a.createdAt)}',
                              style: const TextStyle(fontSize: 12, color: kGray),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
