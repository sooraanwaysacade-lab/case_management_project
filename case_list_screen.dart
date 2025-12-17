import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'case_details_screen.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  final searchCtrl = TextEditingController();
  String filter = 'All';

  Stream<QuerySnapshot> _stream() =>
      FirebaseFirestore.instance.collection('cases').orderBy('caseTitle').snapshots();

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green.shade600;
      case 'pending':
        return Colors.orange.shade600;
      case 'suspension':
        return Colors.purple.shade400;
      case 'expulsion':
        return Colors.red.shade700;
      case 'under investigation':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Future<void> _deleteAllCases() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🗑️ Delete All Cases?'),
        content: const Text(
          'Are you sure you want to permanently delete ALL cases?\nThis action cannot be undone.',
          style: TextStyle(fontSize: 15, color: Colors.red),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final cases = await FirebaseFirestore.instance.collection('cases').get();
    for (var doc in cases.docs) {
      await doc.reference.delete();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ All cases deleted successfully.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Reported Cases',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Delete All Cases',
            onPressed: _deleteAllCases,
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snap.hasData) {
                  return const Center(child: Text('No cases available.'));
                }

                var docs = snap.data!.docs;

                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final title = (data['caseTitle'] ?? '').toString().toLowerCase();
                  final name = (data['studentName'] ?? '').toString().toLowerCase();
                  final id = (data['studentId'] ?? '').toString().toLowerCase();
                  final query = searchCtrl.text.toLowerCase();
                  return title.contains(query) || name.contains(query) || id.contains(query);
                }).toList();

                if (filter != 'All') {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return (data['status'] ?? '') == filter;
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No matching cases found.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final status = (data['status'] ?? 'Pending').toString();
                    final statusColor = _getStatusColor(status);

                    return ListTile(
                      leading: Icon(
                        Icons.folder_copy,
                        color: statusColor, // ✅ Icon color matches status
                        size: 28,
                      ),
                      title: Text(
                        data['caseTitle'] ?? 'Untitled Case',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Name: ${data['studentName'] ?? 'Unknown'}",
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              "ID: ${data['studentId'] ?? 'N/A'}",
                              style: const TextStyle(fontSize: 16),
                            ),
                            Row(
                              children: [
                                const Text(
                                  "Status: ",
                                  style: TextStyle(fontSize: 16),
                                ),
                                Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CaseDetailsScreen(caseDoc: docs[i]),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 🎯 Filter UI + Search
  Widget _filters() => Padding(
    padding: const EdgeInsets.all(8.0),
    child: Row(children: [
      Expanded(
        child: TextField(
          controller: searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Search by name, ID, or case title...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      const SizedBox(width: 8),
      DropdownButton<String>(
        value: filter,
        items: const [
          DropdownMenuItem(value: 'All', child: Text('All')),
          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
          DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
          DropdownMenuItem(
              value: 'Under Investigation', child: Text('Investigation')),
          DropdownMenuItem(value: 'Suspension', child: Text('Suspension')),
          DropdownMenuItem(value: 'Expulsion', child: Text('Expulsion')),
        ],
        onChanged: (v) => setState(() => filter = v!),
      ),
    ]),
  );
}
