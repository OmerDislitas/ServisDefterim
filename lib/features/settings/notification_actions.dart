import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/settings_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/strings.dart';

/// Bildirim izni ilk acilista degil, usta ilk kez bir bakim tarihi ya da randevu
/// kaydettiginde bir kez istenir (PLAN 9). Sonrasinda sadece Ayarlar'dan istenir.
/// Kaydetme akisini bekletmez.
void askNotificationPermissionOnce(WidgetRef ref) {
  final settings = ref.read(databaseProvider).settingsDao;
  final scheduler = ref.read(notificationSchedulerProvider);
  unawaited(() async {
    try {
      if (!await settings.getBool(SettingKeys.notificationsEnabled)) return;
      if (await settings.getBool(SettingKeys.notificationPermissionAsked)) return;
      await settings.setBool(SettingKeys.notificationPermissionAsked, true);
      if (await scheduler.permissionGranted()) return;
      await scheduler.requestPermission();
    } catch (_) {
      // Izin akisi kaydi hicbir zaman bozmamali
    }
  }());
}

/// Ayarlar'dan izin ister; verilmezse nasil acilacagini anlatir. Sonuc: izin var mi.
Future<bool> requestNotificationPermission(BuildContext context, WidgetRef ref) async {
  final scheduler = ref.read(notificationSchedulerProvider);
  final settings = ref.read(databaseProvider).settingsDao;
  final messenger = ScaffoldMessenger.of(context);
  var granted = false;
  try {
    await settings.setBool(SettingKeys.notificationPermissionAsked, true);
    granted = await scheduler.permissionGranted() || await scheduler.requestPermission();
  } catch (_) {
    granted = false;
  }
  if (!granted) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(S.notificationPermissionDenied), duration: Duration(seconds: 6)));
  }
  return granted;
}
