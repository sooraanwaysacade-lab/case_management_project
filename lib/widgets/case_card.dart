import 'package:flutter/material.dart';

class CaseCard extends StatelessWidget {
  final String title;
  final String studentName;
  final String date;
  final String status;
  final Color color;

  const CaseCard({
    super.key,
    required this.title,
    required this.studentName,
    required this.date,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.folder_copy, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text("Student: $studentName\nDate: $date"),
        trailing: Chip(
          label: Text(status),
          backgroundColor: color.withOpacity(0.15),
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
