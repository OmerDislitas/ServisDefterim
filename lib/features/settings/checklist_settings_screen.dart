import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../core/strings.dart';

final _checklistProvider = StreamProvider.autoDispose<List<ChecklistTemplate>>(
  (ref) => ref.watch(databaseProvider).checklistDao.watchItems(),
);

/// Bakim checklist maddeleri: ekle, yeniden adlandir, sil, surukleyerek sirala, ac/kapa.
class ChecklistSettingsScreen extends ConsumerWidget {
  const ChecklistSettingsScreen({super.key});

  Future<String?> _askLabel(BuildContext context, {String initial = '', required String title}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: S.checklistItemLabel),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text(S.save)),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.watch(databaseProvider).checklistDao;
    final items = ref.watch(_checklistProvider).value ?? const <ChecklistTemplate>[];

    return Scaffold(
      appBar: AppBar(title: const Text(S.checklistItems)),
      body: Column(
        children: [
          const ListTile(dense: true, leading: Icon(Icons.info_outline), title: Text(S.checklistInactiveHint)),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: items.length,
              onReorderItem: (oldIndex, newIndex) {
                // newIndex, cikarilan oge hesaba katilarak verilir
                final ids = items.map((e) => e.id).toList();
                ids.insert(newIndex, ids.removeAt(oldIndex));
                dao.reorder(ids);
              },
              itemBuilder: (context, i) {
                final item = items[i];
                return ListTile(
                  key: ValueKey(item.id),
                  leading: Switch(
                    value: item.isActive,
                    onChanged: (v) => dao.updateItem(item.id, isActive: v),
                  ),
                  title: Text(
                    item.label,
                    style: item.isActive ? null : TextStyle(color: Theme.of(context).disabledColor),
                  ),
                  onTap: () async {
                    final label = await _askLabel(context, initial: item.label, title: S.editChecklistItem);
                    if (label != null && label.trim().isNotEmpty) await dao.updateItem(item.id, label: label);
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: S.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => dao.deleteItem(item.id),
                      ),
                      ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final label = await _askLabel(context, title: S.addChecklistItem);
          if (label != null && label.trim().isNotEmpty) await dao.addItem(label);
        },
        icon: const Icon(Icons.add),
        label: const Text(S.addChecklistItem),
      ),
    );
  }
}
