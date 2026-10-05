class StudentNoteItem {
  final String id;
  final String studentId;
  final String? studentName;
  final String category;
  final String content;
  final String date;

  StudentNoteItem({
    required this.id,
    required this.studentId,
    this.studentName,
    required this.category,
    required this.content,
    required this.date,
  });

  factory StudentNoteItem.fromMap(Map<String, dynamic> map) {
    return StudentNoteItem(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      studentName: map['student_name'] as String?,
      category: map['category'] as String,
      content: map['content'] as String,
      date: map['date'] as String,
    );
  }
}

class TeachingSessionItem {
  final String id;
  final String scheduleId;
  final String? scheduleName;
  final String date;
  final String material;
  final String? objective;
  final String? activity;
  final String? notes;
  final String status;

  TeachingSessionItem({
    required this.id,
    required this.scheduleId,
    this.scheduleName,
    required this.date,
    required this.material,
    this.objective,
    this.activity,
    this.notes,
    required this.status,
  });

  factory TeachingSessionItem.fromMap(Map<String, dynamic> map) {
    return TeachingSessionItem(
      id: map['id'] as String,
      scheduleId: map['schedule_id'] as String,
      scheduleName: map['schedule_name'] as String?,
      date: map['date'] as String,
      material: map['material'] as String,
      objective: map['objective'] as String?,
      activity: map['activity'] as String?,
      notes: map['notes'] as String?,
      status: map['status'] as String? ?? 'Selesai',
    );
  }
}