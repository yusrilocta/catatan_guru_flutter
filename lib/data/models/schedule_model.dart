class ScheduleItem {
  final String id;
  final String schoolId;
  final String schoolName;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final int day;
  final String startTime;
  final String endTime;
  final String? room;
  final String? notes;

  ScheduleItem({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.room,
    this.notes,
  });

  factory ScheduleItem.fromMap(Map<String, dynamic> map) {
    return ScheduleItem(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      schoolName: map['school_name'] as String? ?? '',
      classId: map['class_id'] as String,
      className: map['class_name'] as String? ?? '',
      subjectId: map['subject_id'] as String,
      subjectName: map['subject_name'] as String? ?? '',
      day: map['day'] as int,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      room: map['room'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
