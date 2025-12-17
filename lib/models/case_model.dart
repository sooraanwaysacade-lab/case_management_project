class CaseModel {
  final String caseId;
  final String studentId;
  final String studentName;
  final String? email;
  final String? phone;
  final String caseTitle;
  final String? description;
  final String incidentDate;
  final String status;
  final String? evidenceUrl;
  final String? investigator;
  final String? meetingLink;
  final DateTime? createdAt;

  CaseModel({
    required this.caseId,
    required this.studentId,
    required this.studentName,
    this.email,
    this.phone,
    required this.caseTitle,
    this.description,
    required this.incidentDate,
    this.status = 'Pending',
    this.evidenceUrl,
    this.investigator,
    this.meetingLink,
    this.createdAt,
  });

  /// ✅ Convert CaseModel to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'caseId': caseId,
      'studentId': studentId,
      'studentName': studentName,
      'email': email,
      'phone': phone,
      'caseTitle': caseTitle,
      'description': description,
      'incidentDate': incidentDate,
      'status': status,
      'evidenceUrl': evidenceUrl,
      'investigator': investigator,
      'meetingLink': meetingLink,
      'createdAt': createdAt != null
          ? createdAt!.toIso8601String()
          : DateTime.now().toIso8601String(),
    };
  }

  /// ✅ Create CaseModel from Firestore Document
  factory CaseModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CaseModel(
      caseId: documentId,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      email: map['email'],
      phone: map['phone'],
      caseTitle: map['caseTitle'] ?? '',
      description: map['caseDescription'] ?? map['description'] ?? '',
      incidentDate: map['incidentDate'] ?? '',
      status: map['status'] ?? 'Pending',
      evidenceUrl: map['evidenceUrl'],
      investigator: map['investigator'],
      meetingLink: map['meetingLink'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }
}
