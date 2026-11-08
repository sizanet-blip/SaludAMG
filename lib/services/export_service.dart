import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/format.dart';
import '../domain/entities/blood_pressure_model.dart';
import '../domain/entities/export_options.dart';
import '../domain/entities/import_preferences.dart';
import '../domain/entities/medication.dart';
import '../domain/entities/medication_dose_log.dart';
import '../domain/entities/sync_info.dart';
import '../domain/entities/user_profile.dart';
import 'temp_files.dart';

/// Informes con la ficha delante y el desglose de lecturas detrás.
class ExportService {
  Future<void> shareExcel({
    required UserProfile profile,
    required List<BloodPressureModel> readings,
    List<Medication> medications = const [],
    List<MedicationDoseLog> doseLogs = const [],
    ExportOptions options = const ExportOptions(),
  }) async {
    if (!options.hasContent) {
      throw StateError('Elige al menos un bloque para el informe.');
    }

    final excel = Excel.createExcel();
    var created = false;

    if (options.includeProfile) {
      final profileSheet = excel['Perfil'];
      for (final row in _profileRows(profile)) {
        profileSheet.appendRow([
          TextCellValue(row.$1),
          TextCellValue(row.$2),
        ]);
      }
      created = true;
    }

    if (options.includeReadings) {
      final detail = excel['Mediciones'];
      final headers = _readingHeaders(options);
      detail.appendRow([
        for (final header in headers) TextCellValue(header),
      ]);
      for (final reading in _ordered(readings)) {
        detail.appendRow(_excelReadingRow(reading, options));
      }
      created = true;
    }

    if (options.includeMedications && medications.isNotEmpty) {
      final medSheet = excel['Medicaciones'];
      medSheet.appendRow([
        for (final h in _medHeaders) TextCellValue(h),
      ]);
      for (final med in medications) {
        medSheet.appendRow(_excelMedRow(med));
      }
      created = true;
    }

    if (options.includeDoseLogs && doseLogs.isNotEmpty) {
      final logSheet = excel['Tomas'];
      logSheet.appendRow([
        for (final h in _doseHeaders) TextCellValue(h),
      ]);
      final medNames = {
        for (final m in medications) m.id: m.name,
      };
      // Si no exportamos medicaciones, igual resolvemos nombres de la lista filtrada.
      for (final log in _orderedLogs(doseLogs)) {
        logSheet.appendRow(_excelDoseRow(log, medNames[log.medicationId]));
      }
      created = true;
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    if (!created) {
      throw StateError('No hay datos para los bloques elegidos.');
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('No se ha podido generar el Excel.');
    }
    final file = await _writeTemp(
      'saludamg_${_stamp(DateTime.now())}.xlsx',
      bytes,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Informe SaludAMG',
        text: 'Informe personalizado de SaludAMG.',
      ),
    );
  }

  Future<void> sharePdf({
    required UserProfile profile,
    required List<BloodPressureModel> readings,
    List<Medication> medications = const [],
    List<MedicationDoseLog> doseLogs = const [],
    ExportOptions options = const ExportOptions(),
  }) async {
    if (!options.hasContent) {
      throw StateError('Elige al menos un bloque para el informe.');
    }

    final ordered = options.includeReadings ? _ordered(readings) : const <BloodPressureModel>[];
    final orderedLogs =
        options.includeDoseLogs ? _orderedLogs(doseLogs) : const <MedicationDoseLog>[];
    final meds = options.includeMedications ? medications : const <Medication>[];
    final medNames = {for (final m in medications) m.id: m.name};
    final readingHeaders = _readingHeaders(options);
    final logo = await _loadBrandLogo();

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Image(logo, height: 40, fit: pw.BoxFit.contain)
            else
              pw.Text(
                'SaludAMG',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Informe personalizado. Los umbrales son la referencia personal, '
              'no un diagnóstico.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) {
          final children = <pw.Widget>[];
          if (options.includeProfile) {
            children.addAll([
              pw.Text(
                'Ficha',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: const ['Campo', 'Valor'],
                data: [
                  for (final row in _profileRows(profile)) [row.$1, row.$2],
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 16),
            ]);
          }
          if (options.includeReadings) {
            children.addAll([
              pw.Text(
                'Mediciones (${ordered.length})',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: readingHeaders,
                data: [
                  for (final reading in ordered) _pdfReadingRow(reading, options),
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: PdfColors.white,
                ),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellStyle: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 16),
            ]);
          }
          if (meds.isNotEmpty) {
            children.addAll([
              pw.Text(
                'Medicaciones (${meds.length})',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: _medHeaders,
                data: [
                  for (final med in meds) _pdfMedRow(med),
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: PdfColors.white,
                ),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellStyle: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 16),
            ]);
          }
          if (orderedLogs.isNotEmpty) {
            children.addAll([
              pw.Text(
                'Tomas registradas (${orderedLogs.length})',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: _doseHeaders,
                data: [
                  for (final log in orderedLogs)
                    _pdfDoseRow(log, medNames[log.medicationId]),
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: PdfColors.white,
                ),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellStyle: const pw.TextStyle(fontSize: 8),
              ),
            ]);
          }
          if (children.isEmpty) {
            children.add(
              pw.Text(
                'No hay datos para los bloques elegidos en este periodo.',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
              ),
            );
          }
          return children;
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'saludamg_${_stamp(DateTime.now())}.pdf',
    );
  }

  static const _brandLogoAsset = 'assets/branding/saludamg-wordmark.png';

  Future<pw.ImageProvider?> _loadBrandLogo() async {
    try {
      final data = await rootBundle.load(_brandLogoAsset);
      return pw.MemoryImage(
        data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  List<BloodPressureModel> _ordered(List<BloodPressureModel> readings) {
    return [...readings]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  }

  List<MedicationDoseLog> _orderedLogs(List<MedicationDoseLog> logs) {
    return [...logs]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<(String, String)> _profileRows(UserProfile profile) {
    final birth = profile.birthDate;
    final height = profile.heightCm;
    final weight = profile.referenceWeightKg;
    return [
      ('Nombre / apodo', _orDash(profile.nickname)),
      ('Fecha de nacimiento', birth == null ? '—' : formatDate(birth)),
      ('Tipo de sangre', profile.bloodType.label),
      ('Altura (cm)', height == null ? '—' : formatWeight(height)),
      ('Peso de referencia (kg)', weight == null ? '—' : formatWeight(weight)),
      ('Sistólica de referencia (mmHg)', '${profile.systolicReference}'),
      ('Diastólica de referencia (mmHg)', '${profile.diastolicReference}'),
      ('Pulso de reposo de referencia (lpm)', '${profile.restingPulseReference}'),
      ('Margen de aviso (%)', '${profile.alertMarginPercent}'),
      ('Contacto de emergencia', _orDash(profile.emergencyContactName)),
      ('Teléfono de emergencia', _orDash(profile.emergencyContactPhone)),
      ('Ficha actualizada', formatDateTime(profile.updatedAt)),
    ];
  }

  List<String> _readingHeaders(ExportOptions options) {
    final headers = <String>['Fecha'];
    if (options.hasMetric(ImportMetric.bloodPressure)) {
      headers.addAll(const ['Sistólica', 'Diastólica']);
    }
    if (options.hasMetric(ImportMetric.pulse)) headers.add('Pulso');
    if (options.hasMetric(ImportMetric.restingPulse)) headers.add('Pulso reposo');
    if (options.hasMetric(ImportMetric.oxygen)) headers.add('O₂ %');
    if (options.hasMetric(ImportMetric.temperature)) headers.add('Temp °C');
    if (options.hasMetric(ImportMetric.glucose)) headers.add('Glucosa');
    if (options.hasMetric(ImportMetric.weight)) headers.add('Peso (kg)');
    if (options.hasMetric(ImportMetric.bodyFat)) headers.add('Grasa %');
    if (options.hasMetric(ImportMetric.bmi)) headers.add('IMC');
    if (options.hasMetric(ImportMetric.steps)) headers.add('Pasos');
    if (options.hasMetric(ImportMetric.sleep)) headers.add('Sueño (min)');
    if (options.hasMetric(ImportMetric.hrv)) headers.add('HRV ms');
    if (options.includeContext) {
      headers.addAll(const [
        'Momento',
        'Cómo me siento',
        'Notas',
        'Origen',
        'Fuente',
        'Sincronizado',
      ]);
    }
    return headers;
  }

  List<CellValue> _excelReadingRow(
    BloodPressureModel reading,
    ExportOptions options,
  ) {
    final cells = <CellValue>[
      TextCellValue(formatDateTime(reading.measuredAt)),
    ];
    if (options.hasMetric(ImportMetric.bloodPressure)) {
      cells.addAll([
        _intOrEmpty(reading.systolic),
        _intOrEmpty(reading.diastolic),
      ]);
    }
    if (options.hasMetric(ImportMetric.pulse)) {
      cells.add(_intOrEmpty(reading.pulse));
    }
    if (options.hasMetric(ImportMetric.restingPulse)) {
      cells.add(_intOrEmpty(reading.restingPulse));
    }
    if (options.hasMetric(ImportMetric.oxygen)) {
      cells.add(_doubleOrEmpty(reading.oxygenSaturation));
    }
    if (options.hasMetric(ImportMetric.temperature)) {
      cells.add(_doubleOrEmpty(reading.bodyTemperatureC));
    }
    if (options.hasMetric(ImportMetric.glucose)) {
      cells.add(_doubleOrEmpty(reading.glucoseMgDl));
    }
    if (options.hasMetric(ImportMetric.weight)) {
      cells.add(_doubleOrEmpty(reading.weightKg));
    }
    if (options.hasMetric(ImportMetric.bodyFat)) {
      cells.add(_doubleOrEmpty(reading.bodyFatPercent));
    }
    if (options.hasMetric(ImportMetric.bmi)) {
      cells.add(_doubleOrEmpty(reading.bmi));
    }
    if (options.hasMetric(ImportMetric.steps)) {
      cells.add(_intOrEmpty(reading.steps));
    }
    if (options.hasMetric(ImportMetric.sleep)) {
      cells.add(_intOrEmpty(reading.sleepMinutes));
    }
    if (options.hasMetric(ImportMetric.hrv)) {
      cells.add(_doubleOrEmpty(reading.hrvMs));
    }
    if (options.includeContext) {
      final syncedAt = reading.syncInfo.syncedAt;
      cells.addAll([
        TextCellValue(reading.context.label),
        TextCellValue(reading.feeling),
        TextCellValue(reading.notes),
        TextCellValue(reading.syncInfo.origin.label),
        TextCellValue(_fuenteLabel(reading.syncInfo)),
        TextCellValue(syncedAt == null ? '' : formatDateTime(syncedAt)),
      ]);
    }
    return cells;
  }

  List<String> _pdfReadingRow(
    BloodPressureModel reading,
    ExportOptions options,
  ) {
    final cells = <String>[formatDateTime(reading.measuredAt)];
    if (options.hasMetric(ImportMetric.bloodPressure)) {
      cells.addAll([
        reading.systolic?.toString() ?? '—',
        reading.diastolic?.toString() ?? '—',
      ]);
    }
    if (options.hasMetric(ImportMetric.pulse)) {
      cells.add(reading.pulse?.toString() ?? '—');
    }
    if (options.hasMetric(ImportMetric.restingPulse)) {
      cells.add(reading.restingPulse?.toString() ?? '—');
    }
    if (options.hasMetric(ImportMetric.oxygen)) {
      cells.add(
        reading.oxygenSaturation == null
            ? '—'
            : formatWeight(reading.oxygenSaturation!),
      );
    }
    if (options.hasMetric(ImportMetric.temperature)) {
      cells.add(
        reading.bodyTemperatureC == null
            ? '—'
            : formatWeight(reading.bodyTemperatureC!),
      );
    }
    if (options.hasMetric(ImportMetric.glucose)) {
      cells.add(
        reading.glucoseMgDl == null ? '—' : formatWeight(reading.glucoseMgDl!),
      );
    }
    if (options.hasMetric(ImportMetric.weight)) {
      cells.add(
        reading.weightKg == null ? '—' : formatWeight(reading.weightKg!),
      );
    }
    if (options.hasMetric(ImportMetric.bodyFat)) {
      cells.add(
        reading.bodyFatPercent == null
            ? '—'
            : formatWeight(reading.bodyFatPercent!),
      );
    }
    if (options.hasMetric(ImportMetric.bmi)) {
      cells.add(reading.bmi == null ? '—' : formatWeight(reading.bmi!));
    }
    if (options.hasMetric(ImportMetric.steps)) {
      cells.add(reading.steps?.toString() ?? '—');
    }
    if (options.hasMetric(ImportMetric.sleep)) {
      cells.add(reading.sleepMinutes?.toString() ?? '—');
    }
    if (options.hasMetric(ImportMetric.hrv)) {
      cells.add(reading.hrvMs == null ? '—' : formatWeight(reading.hrvMs!));
    }
    if (options.includeContext) {
      final syncedAt = reading.syncInfo.syncedAt;
      cells.addAll([
        reading.context.label,
        reading.feeling.trim().isEmpty ? '—' : reading.feeling,
        reading.notes.trim().isEmpty ? '—' : reading.notes,
        reading.syncInfo.origin.label,
        _fuenteLabel(reading.syncInfo),
        syncedAt == null ? '—' : formatDateTime(syncedAt),
      ]);
    }
    return cells;
  }

  String _fuenteLabel(SyncInfo info) {
    final label = info.sourceLabel?.trim();
    if (label != null && label.isNotEmpty && label != info.source.label) {
      return '${info.source.label} · $label';
    }
    return info.source.label;
  }

  static const _medHeaders = [
    'Nombre',
    'Dosis',
    'Inicio',
    'Fin',
    'Horarios',
    'Días',
    'Activa',
    'Stock',
    'Umbral',
    'Uds/toma',
    'Pedir al médico',
    'Repetición médico',
    'Aviso anticipado (días)',
    'Notas',
  ];

  static const _doseHeaders = [
    'Medicación',
    'Horario',
    'Estado',
    'Registrado',
  ];

  List<CellValue> _excelMedRow(Medication med) {
    return [
      TextCellValue(med.name),
      TextCellValue(med.dose),
      TextCellValue(formatDate(med.startDate)),
      TextCellValue(med.endDate == null ? 'Indefinido' : formatDate(med.endDate!)),
      TextCellValue(med.sortedMinutes.map(formatClock).join(', ')),
      TextCellValue(med.weekdaysLabel),
      TextCellValue(med.active ? 'Sí' : 'No'),
      _intOrEmpty(med.stockRemaining),
      _intOrEmpty(med.reorderThreshold),
      IntCellValue(med.unitsPerDose),
      TextCellValue(
        med.doctorRequestDate == null
            ? ''
            : formatDate(med.doctorRequestDate!),
      ),
      TextCellValue(
        med.doctorRequestDate == null ? '' : med.doctorRepeatLabel,
      ),
      med.doctorRequestDate == null
          ? TextCellValue('')
          : IntCellValue(med.effectiveDoctorLeadDays),
      TextCellValue(med.notes),
    ];
  }

  List<CellValue> _excelDoseRow(MedicationDoseLog log, String? name) {
    return [
      TextCellValue(name ?? log.medicationId),
      TextCellValue(formatDateTime(log.scheduledAt)),
      TextCellValue(log.status.label),
      TextCellValue(formatDateTime(log.recordedAt)),
    ];
  }

  List<String> _pdfMedRow(Medication med) {
    return [
      med.name,
      med.dose,
      formatDate(med.startDate),
      med.endDate == null ? 'Indefinido' : formatDate(med.endDate!),
      med.sortedMinutes.map(formatClock).join(', '),
      med.weekdaysLabel,
      med.active ? 'Sí' : 'No',
      med.stockRemaining?.toString() ?? '—',
      med.reorderThreshold?.toString() ?? '—',
      '${med.unitsPerDose}',
      med.doctorRequestDate == null ? '—' : formatDate(med.doctorRequestDate!),
      med.doctorRequestDate == null ? '—' : med.doctorRepeatLabel,
      med.doctorRequestDate == null
          ? '—'
          : '${med.effectiveDoctorLeadDays}',
      med.notes,
    ];
  }

  List<String> _pdfDoseRow(MedicationDoseLog log, String? name) {
    return [
      name ?? log.medicationId,
      formatDateTime(log.scheduledAt),
      log.status.label,
      formatDateTime(log.recordedAt),
    ];
  }

  CellValue _intOrEmpty(int? value) =>
      value == null ? TextCellValue('') : IntCellValue(value);

  CellValue _doubleOrEmpty(double? value) =>
      value == null ? TextCellValue('') : DoubleCellValue(value);

  Future<File> _writeTemp(String name, List<int> bytes) async {
    await TempFiles.cleanOld();
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _stamp(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}$month$day';
  }

  String _orDash(String value) => value.trim().isEmpty ? '—' : value.trim();
}
