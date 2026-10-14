import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String kind) => switch (kind) {
        'alert' => Icons.warning_amber_rounded,
        'sos' => Icons.sos,
        'broadcast' => Icons.cell_tower,
        _ => Icons.info_outline,
      };

  Color _color(String kind) => switch (kind) {
        'alert' => kRed,
        'sos' => kRed,
        'broadcast' => kRed,
        _ => kBlue,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        final list = s.myNotifications;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifikasi'),
            actions: [
              TextButton(
                onPressed: s.markAllRead,
                child: const Text('Tandai dibaca',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none,
                  text: 'Belum ada notifikasi.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final n = list[i];
                    return Card(
                      color: n.read ? null : const Color(0xFFFFF3D6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _color(n.kind),
                          child: Icon(_icon(n.kind), color: Colors.white),
                        ),
                        title: Text(n.title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(n.body),
                        trailing: Text(timeAgo(n.createdAt),
                            style: const TextStyle(fontSize: 11, color: kGray)),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
