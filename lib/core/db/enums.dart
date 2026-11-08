import '../strings.dart';

// Enum adlari veritabaninda metin olarak saklanir (Drift textEnum).
// Var olan bir degerin adini degistirmek migration gerektirir.

enum DeviceType {
  condensing,
  hermetic,
  flue,
  other;

  String get label => switch (this) {
        condensing => S.deviceCondensing,
        hermetic => S.deviceHermetic,
        flue => S.deviceFlue,
        other => S.other,
      };
}

enum ServiceType {
  maintenance,
  repair,
  installation,
  inspection,
  other;

  String get label => switch (this) {
        maintenance => S.serviceMaintenance,
        repair => S.serviceRepair,
        installation => S.serviceInstallation,
        inspection => S.serviceInspection,
        other => S.other,
      };
}

enum AppointmentStatus {
  planned,
  done,
  cancelled;

  String get label => switch (this) {
        planned => S.apptPlanned,
        done => S.apptDone,
        cancelled => S.apptCancelled,
      };
}

enum PhotoOwnerType { device, service }
