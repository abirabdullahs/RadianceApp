class AttendanceSettingsModel {
  const AttendanceSettingsModel({
    this.warningThresholdPct = 75,
    this.autoSmsEnabled = false,
    this.sortOrder = 'roll',
    this.autoAdvanceDelayMs = 300,
    this.defaultStatus = 'absent',
  });

  final int warningThresholdPct;
  final bool autoSmsEnabled;
  final String sortOrder;
  final int autoAdvanceDelayMs;
  final String defaultStatus;

  factory AttendanceSettingsModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSettingsModel(
      warningThresholdPct: (json['warning_threshold_pct'] as num?)?.toInt() ?? 75,
      autoSmsEnabled: json['auto_sms_enabled'] as bool? ?? false,
      sortOrder: json['sort_order'] as String? ?? 'roll',
      autoAdvanceDelayMs: (json['auto_advance_delay_ms'] as num?)?.toInt() ?? 300,
      defaultStatus: json['default_status'] as String? ?? 'absent',
    );
  }

  Map<String, dynamic> toUpsertJson({String? updatedBy}) {
    return <String, dynamic>{
      'singleton_key': 1,
      'warning_threshold_pct': warningThresholdPct,
      'auto_sms_enabled': autoSmsEnabled,
      'sort_order': sortOrder,
      'auto_advance_delay_ms': autoAdvanceDelayMs,
      'default_status': defaultStatus,
      'updated_by': updatedBy,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
