import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../db/daos/settings_dao.dart';
import '../db/database.dart';
import '../strings.dart';
import '../utils/dates.dart';
import '../utils/notification_plan.dart';

/// Bildirim eklentisinin uygulamaya acilan yuzu. Testlerde sahtesiyle degistirilir.
abstract class NotificationScheduler {
  /// Bildirime dokunulunca acilacak rotalar.
  Stream<String> get taps;

  /// Uygulama bir bildirime dokunularak acildiysa o bildirimin rotasi.
  Future<String?> launchPayload();

  Future<bool> permissionGranted();

  /// Android 13+ izin penceresi. Sonuc: izin var mi.
  Future<bool> requestPermission();

  /// Bekleyen tum bildirimleri iptal edip [list]'i planlar.
  /// Gosterilmis (bildirim cubugundaki) bildirimlere dokunmaz.
  Future<void> replaceAll(List<PlannedNotification> list);

  Future<void> showTest();
}

/// flutter_local_notifications ile zamanlanmis yerel bildirimler (PLAN 9).
/// Exact alarm izni istenmez: `inexactAllowWhileIdle` (birkac dakikalik sapma sorun degil).
class LocalNotificationScheduler implements NotificationScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  Future<void>? _init;

  static const _maintenanceChannel = AndroidNotificationDetails(
    'maintenance',
    S.channelMaintenance,
    channelDescription: S.channelMaintenanceDesc,
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _appointmentChannel = AndroidNotificationDetails(
    'appointments',
    S.channelAppointments,
    channelDescription: S.channelAppointmentsDesc,
    importance: Importance.high,
    priority: Priority.high,
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> _ensureInit() => _init ??= _doInit();

  Future<void> _doInit() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_notify')),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _taps.add(payload);
      },
    );
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async {
    await _ensureInit();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final payload = details.notificationResponse?.payload;
    return (payload == null || payload.isEmpty) ? null : payload;
  }

  @override
  Future<bool> permissionGranted() async {
    await _ensureInit();
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureInit();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> replaceAll(List<PlannedNotification> list) async {
    await _ensureInit();
    await _plugin.cancelAllPendingNotifications();
    for (final n in list) {
      final channel = n.kind == NotificationKind.maintenance ? _maintenanceChannel : _appointmentChannel;
      await _plugin.zonedSchedule(
        id: n.id,
        scheduledDate: tz.TZDateTime.from(n.at, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.channelId,
            channel.channelName,
            channelDescription: channel.channelDescription,
            importance: channel.importance,
            priority: channel.priority,
            styleInformation: BigTextStyleInformation(n.body),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: n.title,
        body: n.body,
        payload: n.payload,
      );
    }
  }

  @override
  Future<void> showTest() async {
    await _ensureInit();
    await _plugin.show(
      id: 0,
      title: S.testNotificationTitle,
      body: S.testNotificationBody,
      notificationDetails: const NotificationDetails(android: _maintenanceChannel),
    );
  }
}

/// Bildirimleri veriyle esit tutar: acilista ve ilgili veri / ayar degistikce
/// tum bekleyen bildirimleri iptal edip onumuzdeki 60 gunu yeniden planlar (PLAN 9).
class NotificationSync {
  NotificationSync(this._db, this._scheduler, {this.debounce = const Duration(seconds: 2)}) {
    _sub = _db
        .tableUpdates(TableUpdateQuery.onAllTables([
          _db.devices,
          _db.appointments,
          _db.customers,
          _db.addresses,
          _db.appSettings,
        ]))
        .listen((_) => _schedule());
  }

  final AppDatabase _db;
  final NotificationScheduler _scheduler;
  final Duration debounce;
  StreamSubscription<void>? _sub;
  Timer? _timer;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;

  void _schedule() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, resync);
  }

  /// Hemen yeniden planlar. Ayni anda tek calisma; arada degisiklik olursa bir kez daha calisir.
  Future<void> resync({DateTime? now}) async {
    if (_disposed) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        final list = await buildPlan(_db, now: now ?? DateTime.now());
        if (_disposed) return;
        await _scheduler.replaceAll(list);
      } while (_again && !_disposed);
    } catch (e) {
      // Bildirim planlamasi hicbir zaman uygulamayi bozmamali
      debugPrint('Bildirim planlanamadi: $e');
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _sub?.cancel();
  }

  /// Veritabanindaki kombi ve randevulardan bildirim listesini hesaplar.
  static Future<List<PlannedNotification>> buildPlan(AppDatabase db, {required DateTime now}) async {
    final settings = db.settingsDao;
    final prefs = NotificationPrefs(
      enabled: await settings.getBool(SettingKeys.notificationsEnabled),
      maintenance: await settings.getBool(SettingKeys.maintenanceNotifications),
      appointment: await settings.getBool(SettingKeys.appointmentNotifications),
      hour: (await settings.getInt(SettingKeys.notificationHour)).clamp(0, 23),
      daysBefore: (await settings.getInt(SettingKeys.remindDaysBefore)).clamp(0, 30),
    );
    if (!prefs.enabled) return const [];

    const horizonDays = 60;
    final t = today(now);
    final devices = prefs.maintenance
        ? await db.devicesDao.getDueDevicesInRange(
            from: toDateKey(t),
            to: toDateKey(addDays(t, horizonDays + prefs.daysBefore)),
          )
        : const [];
    final appointments = prefs.appointment
        ? await db.appointmentsDao.getAppointments(
            from: now,
            to: now.add(const Duration(days: horizonDays + 1)),
            status: AppointmentStatus.planned,
          )
        : const [];

    return planNotifications(
      now: now,
      prefs: prefs,
      horizonDays: horizonDays,
      devices: [
        for (final d in devices)
          MaintenanceReminderInput(
            deviceId: d.device.id,
            customerName: d.customer.name,
            brand: d.device.brand,
            dueDate: d.device.nextMaintenanceDate!,
          ),
      ],
      appointments: [
        for (final a in appointments)
          AppointmentReminderInput(
            id: a.id,
            scheduledAt: a.scheduledAt,
            customerName: a.customerName,
            typeLabel: a.type.label,
            place: [a.district, a.neighborhood].whereType<String>().where((s) => s.isNotEmpty).join(', ').ifEmptyNull,
          ),
      ],
    );
  }
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}
