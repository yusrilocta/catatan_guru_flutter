class StudentItem {
  final String id;
  final String classId;
  final String name;
  final String? studentNumber;

  StudentItem({
    required this.id,
    required this.classId,
    required this.name,
    this.studentNumber,
  });

  factory StudentItem.fromMap(Map<String, dynamic> map) {
    return StudentItem(
      id: map['id'] as String,
      classId: map['class_id'] as String,
      name: map['name'] as String,
      studentNumber: map['student_number'] as String?,
    );
  }
}
