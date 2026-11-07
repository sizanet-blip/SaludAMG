import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/navigation.dart';
import '../domain/entities/medication.dart';
import '../domain/entities/medication_preferences.dart';
import '../domain/entities/reminder_config.dart';

const _tensionBaseId = 200;
const _maxTensionNotifications = 8;

const _medicationDoseBaseId = 300;
const _maxMedicationDoseNotifications = 64;
const _medicationReorderBaseId = 400;
const _maxMedicationReorderNotifications = 24;
const _medicationDoctorBaseId = 450;
const _maxMedicationDoctorNotifications = 24;
const _snoozeBaseId = 500;
const _maxSnoozeNotifications = 64;
const _reorderMinutesFromMidnight = 10 * 60;
const _snoozeMinutes = 10;

const _actionSnooze = 'snooze_10';
const _medCategory = 'medication_dose';

Future<void> configureLocalTimezone() async {
  tzdata.initializeTimeZones();
  try {
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
  } catch (error) {
    debugPrint('Zona horaria del dispositivo no reconocida: $error');
    tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  if (response.actionId == _actionSnooze) {
    // Fire-and-forget: el isolate de fondo programa el aviso +10 min.
    NotificationService._scheduleSnoozeStandalone(response.payload);
  }
}

/// Programa avisos locales de tensión y medicación.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;
  var _snoozeCursor = 0;

  static final _medicationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'medication_reminders',
      'Recordatorios de medicación',
      channelDescription: 'Aviso para tomar la medicación',
      importance: Importance.high,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _actionSnooze,
          'En 10 min',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    ),
    iOS: DarwinNotificationDetails(
      categoryIdentifier: _medCategory,
    ),
  );

  static const _tensionDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'tension_reminders',
      'Recordatorios de tensión',
      channelDescription: 'Aviso para anotar la tensión arterial',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _reorderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'medication_reorder',
      'Pedir medicación',
      channelDescription: 'Aviso cuando el stock de medicación es bajo',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _doctorDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'medication_doctor',
      'Pedir al médico',
      channelDescription: 'Recordatorio para pedir la medicación al médico',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> initialize() async {
    final ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _medCategory,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(_actionSnooze, 'En 10 min'),
          ],
        ),
      ],
    );
    final settings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: ios,
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _ready = true;

    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null) {
      await _handleResponse(response);
    }
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    await _handleResponse(response);
  }

  Future<void> _handleResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (response.actionId == _actionSnooze) {
      await scheduleSnooze(payload: payload);
      return;
    }
    if (payload == null || payload.isEmpty) return;
    if (payload == 'tension') {
      openMeasurementFromNotification();
      return;
    }
    if (payload.startsWith('med:') ||
        payload.startsWith('reorder:') ||
        payload.startsWith('doctor:') ||
        payload.startsWith('snooze:')) {
      openMedicationsFromNotification();
    }
  }

  /// Reprograma un aviso único dentro de 10 minutos.
  Future<void> scheduleSnooze({String? payload}) async {
    if (!_ready) return;
    await _scheduleSnoozeWithPlugin(_plugin, payload, _snoozeCursor++);
  }

  static Future<void> _scheduleSnoozeStandalone(String? payload) async {
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
      }
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await _scheduleSnoozeWithPlugin(plugin, payload, stamp);
    } catch (error) {
      debugPrint('No se pudo programar snooze en segundo plano: $error');
    }
  }

  static Future<void> _scheduleSnoozeWithPlugin(
    FlutterLocalNotificationsPlugin plugin,
    String? payload,
    int cursor,
  ) async {
    // Slot estable por medicación (evita pisar snoozes distintos).
    var slot = cursor.abs() % _maxSnoozeNotifications;
    var nextPayload = 'snooze';
    var body = 'Recordatorio: toma pendiente.';
    if (payload != null && payload.startsWith('med:')) {
      final parts = payload.split(':');
      if (parts.length >= 2) {
        nextPayload = 'snooze:${parts[1]}';
        body = 'Recordatorio: es hora de tu medicación.';
        slot = parts[1].hashCode.abs() % _maxSnoozeNotifications;
      }
    } else if (payload != null && payload.startsWith('snooze:')) {
      final parts = payload.split(':');
      if (parts.length >= 2) {
        nextPayload = payload;
        slot = parts[1].hashCode.abs() % _maxSnoozeNotifications;
      }
    }
    final id = _snoozeBaseId + slot;

    var mode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (Platform.isAndroid) {
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final exact = await android?.canScheduleExactNotifications() ?? false;
      if (exact) mode = AndroidScheduleMode.exactAllowWhileIdle;
    }

    final when = tz.TZDateTime.now(tz.local).add(
      const Duration(minutes: _snoozeMinutes),
    );
    await plugin.zonedSchedule(
      id,
      'Medicación',
      body,
      when,
      _medicationDetails,
      androidScheduleMode: mode,
      payload: nextPayload,
    );
  }

  Future<String?> syncSchedule(ReminderConfig config) async {
    if (!_ready) return 'Los recordatorios todavía no están listos.';

    if (!config.active) {
      await _cancelTension();
      return null;
    }
    if (config.minutesFromMidnight.isEmpty) {
      return 'Añade al menos un horario.';
    }

    final permissionError = await _ensurePermissions();
    if (permissionError != null) return permissionError;

    await _cancelTension();

    final mode = await _scheduleMode();
    final times = config.minutesFromMidnight.take(_maxTensionNotifications);
    var index = 0;
    for (final minutes in times) {
      await _plugin.zonedSchedule(
        _tensionBaseId + index,
        'SaludAMG',
        'Es hora de registrar la tensión.',
        _nextInstance(minutes),
        _tensionDetails,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'tension',
      );
      index++;
    }

    if (Platform.isAndroid && mode == AndroidScheduleMode.inexactAllowWhileIdle) {
      return 'Recordatorio guardado. Android puede moverlo unos minutos '
          'si no permites alarmas exactas.';
    }
    return null;
  }

  Future<String?> syncMedicationSchedule({
    required List<Medication> medications,
    required MedicationPreferences preferences,
  }) async {
    if (!_ready) return 'Los recordatorios todavía no están listos.';

    final today = DateTime.now();
    final doseJobs = <({Medication med, int minutes, int? weekday})>[];
    final reorderMeds = <Medication>[];
    final doctorDueMeds = <Medication>[];
    final doctorUpcomingMeds = <Medication>[];

    for (final med in medications) {
      if (!med.active) continue;

      if (preferences.doctorRequestReminders &&
          med.doctorNotifyDate != null) {
        if (med.needsDoctorRequestReminder(today)) {
          doctorDueMeds.add(med);
        } else {
          doctorUpcomingMeds.add(med);
        }
      }

      final start =
          DateTime(med.startDate.year, med.startDate.month, med.startDate.day);
      final end = med.endDate == null
          ? null
          : DateTime(med.endDate!.year, med.endDate!.month, med.endDate!.day);
      final todayDay = DateTime(today.year, today.month, today.day);
      if (todayDay.isBefore(start)) continue;
      if (end != null && todayDay.isAfter(end)) continue;

      if (med.isEveryDay) {
        for (final minutes in med.sortedMinutes) {
          doseJobs.add((med: med, minutes: minutes, weekday: null));
        }
      } else {
        for (final weekday in med.effectiveWeekdays) {
          for (final minutes in med.sortedMinutes) {
            doseJobs.add((med: med, minutes: minutes, weekday: weekday));
          }
        }
      }

      if (med.needsReorder(
        trackStock: preferences.trackStock,
        reorderReminders: preferences.reorderReminders,
      )) {
        reorderMeds.add(med);
      }
    }

    // Sin jobs: cancelar avisos previos (p. ej. todo vencido) sin pedir permiso.
    if (doseJobs.isEmpty &&
        reorderMeds.isEmpty &&
        doctorDueMeds.isEmpty &&
        doctorUpcomingMeds.isEmpty) {
      await _cancelMedication();
      return null;
    }

    final permissionError = await _ensurePermissions();
    if (permissionError != null) {
      // No cancelar lo ya programado si no podemos reprogramar.
      return permissionError;
    }

    await _cancelMedication();

    final mode = await _scheduleMode();
    final truncated = doseJobs.length > _maxMedicationDoseNotifications;
    var doseIndex = 0;
    for (final job in doseJobs.take(_maxMedicationDoseNotifications)) {
      final dose = job.med.dose.trim();
      final body = dose.isEmpty
          ? 'Es hora de tomar ${job.med.name}.'
          : 'Es hora de tomar ${job.med.name} ($dose).';
      // Con fecha de fin: aviso único del próximo disparo (vigencia vía sync al resume).
      // Sin fin: repetición diaria/semanal; el sync al volver a primer plano corta tras endDate.
      final hasEnd = job.med.endDate != null;
      final when = job.weekday == null
          ? _nextInstance(job.minutes)
          : _nextInstanceOnWeekday(job.weekday!, job.minutes);
      await _plugin.zonedSchedule(
        _medicationDoseBaseId + doseIndex,
        'Medicación',
        body,
        when,
        _medicationDetails,
        androidScheduleMode: mode,
        matchDateTimeComponents: hasEnd
            ? null
            : (job.weekday == null
                ? DateTimeComponents.time
                : DateTimeComponents.dayOfWeekAndTime),
        payload: 'med:${job.med.id}:${job.minutes}',
      );
      doseIndex++;
    }

    var reorderIndex = 0;
    for (final med in reorderMeds.take(_maxMedicationReorderNotifications)) {
      await _plugin.zonedSchedule(
        _medicationReorderBaseId + reorderIndex,
        'Pedir medicación',
        'Quedan pocas unidades de ${med.name}.',
        _nextInstance(_reorderMinutesFromMidnight),
        _reorderDetails,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'reorder:${med.id}',
      );
      reorderIndex++;
    }

    var doctorIndex = 0;
    for (final med in doctorDueMeds.take(_maxMedicationDoctorNotifications)) {
      await _plugin.zonedSchedule(
        _medicationDoctorBaseId + doctorIndex,
        'Pedir al médico',
        'Recuerda pedir ${med.name} al médico / renovar la receta.',
        _nextInstance(_reorderMinutesFromMidnight),
        _doctorDetails,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'doctor:${med.id}',
      );
      doctorIndex++;
    }
    for (final med in doctorUpcomingMeds) {
      if (doctorIndex >= _maxMedicationDoctorNotifications) break;
      final notify = med.doctorNotifyDate!;
      final when = tz.TZDateTime(
        tz.local,
        notify.year,
        notify.month,
        notify.day,
        _reorderMinutesFromMidnight ~/ 60,
        _reorderMinutesFromMidnight % 60,
      );
      if (!when.isAfter(tz.TZDateTime.now(tz.local))) continue;
      await _plugin.zonedSchedule(
        _medicationDoctorBaseId + doctorIndex,
        'Pedir al médico',
        'Recuerda pedir ${med.name} al médico / renovar la receta.',
        when,
        _doctorDetails,
        androidScheduleMode: mode,
        payload: 'doctor:${med.id}',
      );
      doctorIndex++;
    }

    if (truncated) {
      return 'Hay más de $_maxMedicationDoseNotifications avisos de dosis. '
          'Solo se han programado los primeros; reduce horarios o medicaciones.';
    }
    if (Platform.isAndroid && mode == AndroidScheduleMode.inexactAllowWhileIdle) {
      return 'Avisos de medicación guardados. Android puede moverlos unos minutos '
          'si no permites alarmas exactas.';
    }
    return null;
  }

  Future<void> _cancelTension() async {
    for (var i = 0; i < _maxTensionNotifications; i++) {
      await _plugin.cancel(_tensionBaseId + i);
    }
  }

  Future<void> _cancelMedication() async {
    for (var i = 0; i < _maxMedicationDoseNotifications; i++) {
      await _plugin.cancel(_medicationDoseBaseId + i);
    }
    for (var i = 0; i < _maxMedicationReorderNotifications; i++) {
      await _plugin.cancel(_medicationReorderBaseId + i);
    }
    for (var i = 0; i < _maxMedicationDoctorNotifications; i++) {
      await _plugin.cancel(_medicationDoctorBaseId + i);
    }
  }

  Future<String?> _ensurePermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (Platform.isAndroid) {
      final allowed = await android?.requestNotificationsPermission();
      if (allowed == false) {
        return 'Las notificaciones están desactivadas en el sistema.';
      }
    }
    if (Platform.isIOS) {
      final allowed = await ios?.requestPermissions(
        alert: true,
        badge: false,
        sound: true,
      );
      if (allowed == false) {
        return 'Las notificaciones están desactivadas en el sistema.';
      }
    }
    return null;
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    var mode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (!Platform.isAndroid) return mode;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final alreadyExact =
        await android?.canScheduleExactNotifications() ?? false;
    if (!alreadyExact) {
      await android?.requestExactAlarmsPermission();
    }
    final exact = await android?.canScheduleExactNotifications() ?? false;
    if (exact) mode = AndroidScheduleMode.exactAllowWhileIdle;
    return mode;
  }

  tz.TZDateTime _nextInstance(int minutesFromMidnight) {
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutesFromMidnight ~/ 60,
      minutesFromMidnight % 60,
    );
    if (scheduled.isAfter(now)) return scheduled;
    return scheduled.add(const Duration(days: 1));
  }

  tz.TZDateTime _nextInstanceOnWeekday(int weekday, int minutesFromMidnight) {
    var scheduled = _nextInstance(minutesFromMidnight);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
