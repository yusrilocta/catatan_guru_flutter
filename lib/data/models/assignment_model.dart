class AssignmentItem {
  final String id;
  final String schoolId;
  final String? schoolName;
  final String classId;
  final String? className;
  final String subjectId;
  final String? subjectName;
  final String title;
  final String? description;
  final String assignedDate;
  final String deadline;
  final String status;

  AssignmentItem({
    required this.id,
    required this.schoolId,
    this.schoolName,
    required this.classId,
    this.className,
    required this.subjectId,
    this.subjectName,
    required this.title,
    this.description,
    required this.assignedDate,
    required this.deadline,
    required this.status,
  });

  factory AssignmentItem.fromMap(Map<String, dynamic> map) {
    return AssignmentItem(
      id: map['id'] as String,
      schoolId: map['school_id'] as String,
      schoolName: map['school_name'] as String?,
      classId: map['class_id'] as String,
      className: map['class_name'] as String?,
      subjectId: map['subject_id'] as String,
      subjectName: map['subject_name'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      assignedDate: map['assigned_date'] as String,
      deadline: map['deadline'] as String,
      status: map['status'] as String? ?? 'Aktif',
    );
  }
}
