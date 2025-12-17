class AppealModel {
  final String appealId;
  final String caseId;
  final String studentId;
  final String reason;
  final String status;
  final String date;
  final String? reply;          // ✅ Admin reply (optional)
  final DateTime? createdAt;    // ✅ Timestamp when appeal was created
  final DateTime? repliedAt;    // ✅ Timestamp when admin replied

  AppealModel({
    required this.appealId,
    required this.caseId,
    required this.studentId,
    required this.reason,
    required this.status,
    required this.date,
    this.reply,
    this.createdAt,
    this.repliedAt,
  });

  /// ✅ Convert AppealModel to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'appealId': appealId,
      'caseId': caseId,
      'studentId': studentId,
      'reason': reason,
      'status': status,
      'date': date,
      'reply': reply,
      'createdAt': createdAt?.toIso8601String(),
      'repliedAt': repliedAt?.toIso8601String(),
    };
  }

  /// ✅ Create AppealModel from Firestore Document
  factory AppealModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AppealModel(
      appealId: documentId,
      caseId: map['caseId'] ?? '',
      studentId: map['studentId'] ?? '',
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'Pending',
      date: map['date'] ?? '',
      reply: map['reply'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      repliedAt: map['repliedAt'] != null
          ? DateTime.tryParse(map['repliedAt'].toString())
          : null,
    );
  }
}
