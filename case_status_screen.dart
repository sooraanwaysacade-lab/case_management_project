import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CaseStatusScreen extends StatelessWidget {
  const CaseStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Case Status"), backgroundColor: Colors.indigo),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('case_reports').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No cases found."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              return ListTile(
                leading: const Icon(Icons.flag, color: Colors.indigo),
                title: Text(data['caseTitle']),
                subtitle: Text("Status: ${data['status']}"),
                trailing: Icon(Icons.circle, color: _getStatusColor(data['status'])),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Resolved':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Suspension':
        return Colors.purple;
      case 'Expulsion':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
