import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/db/database.dart';
import '../core/db/db_providers.dart';
import '../core/strings.dart';
import '../core/utils/phone.dart';

Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

void _snack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Telefon uygulamasini numarayla acar.
Future<void> callPhone(BuildContext context, String phone) async {
  if (!await _launch(telUri(phone)) && context.mounted) _snack(context, S.callFailed);
}

/// WhatsApp sohbetini (istege bagli mesajla) acar. Basarili olursa true.
Future<bool> openWhatsapp(BuildContext context, String phone, {String? message}) async {
  final ok = await _launch(whatsappUri(phone, message: message));
  if (!ok && context.mounted) _snack(context, S.whatsappFailed);
  return ok;
}

/// Onay ister; evetse kaydi (ve bagli kayitlari) soft delete eder ve "Geri al" gosterir.
/// [popAfter] verilirse silmeden once mevcut sayfa kapatilir (detay ekranlari icin).
Future<void> confirmAndDelete({
  required BuildContext context,
  required WidgetRef ref,
  required EntityKind kind,
  required String id,
  required String title,
  required String body,
  required String doneMessage,
  bool popAfter = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text(S.delete),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  // Sayfa kapanmadan once gerekenleri al
  final db = ref.read(databaseProvider);
  final messenger = ScaffoldMessenger.of(context);
  if (popAfter) context.pop();

  final deletedAt = await db.softDelete(kind, id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(doneMessage),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(label: S.undo, onPressed: () => db.restore(kind, id, deletedAt)),
    ));
}
