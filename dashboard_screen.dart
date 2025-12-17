import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'cases_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Color _adaptiveTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87;

  @override
  Widget build(BuildContext context) {
    // ✅ Removed Scaffold + AppBar to avoid double titles and duplicate drawers
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('cases').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final cases = snapshot.data!.docs;
        int total = cases.length;
        int resolved = cases.where((d) => d['status'] == 'Resolved').length;
        int pending = cases.where((d) => d['status'] == 'Pending').length;
        int suspension =
            cases.where((d) => d['status'] == 'Suspension').length;
        int expulsion =
            cases.where((d) => d['status'] == 'Expulsion').length;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('appeals').snapshots(),
          builder: (context, appealSnap) {
            int appeals = appealSnap.data?.docs.length ?? 0;

            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              color: isDark 
                  ? Theme.of(context).scaffoldBackgroundColor 
                  : const Color(0xFFF5F7FA),
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _card(
                    context,
                    title: 'Total Cases',
                    count: total,
                    color: Colors.indigo,
                    icon: Icons.folder_copy,
                  ),
                  _card(
                    context,
                    title: 'Resolved',
                    count: resolved,
                    color: Colors.green,
                    icon: Icons.verified,
                  ),
                  _card(
                    context,
                    title: 'Pending',
                    count: pending,
                    color: Colors.orange,
                    icon: Icons.pending_actions,
                  ),
                  _card(
                    context,
                    title: 'Appeals',
                    count: appeals,
                    color: Colors.teal,
                    icon: Icons.campaign,
                  ),
                  _card(
                    context,
                    title: 'Suspension',
                    count: suspension,
                    color: Colors.purple,
                    icon: Icons.pause_circle,
                  ),
                  _card(
                    context,
                    title: 'Expulsion',
                    count: expulsion,
                    color: Colors.red,
                    icon: Icons.block,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// ✅ Dashboard Card Widget (Non-clickable, Display Only)
  Widget _card(
      BuildContext context, {
        required String title,
        required int count,
        required Color color,
        required IconData icon,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? Theme.of(context).cardColor : Colors.white,
            color.withOpacity(isDark ? 0.1 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          // Count Number
          Text(
            '$count',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: 0.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// ✅ Filtered version of CasesScreen used for dashboard navigation
class CasesScreenWithFilter extends StatelessWidget {
  final String filter;
  final String title;

  const CasesScreenWithFilter({
    super.key,
    required this.filter,
    required this.title,
  });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.indigo,
        centerTitle: true,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('cases').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allCases = snap.data!.docs;
          final filteredCases = filter == 'All'
              ? allCases
              : allCases.where((d) => (d['status'] ?? '') == filter).toList();

          if (filteredCases.isEmpty) {
            return Center(
              child: Text(
                "No $filter cases found.",
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.7),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: filteredCases.length,
            itemBuilder: (_, i) {
              final data = filteredCases[i].data() as Map<String, dynamic>;
              final status = (data['status'] ?? 'Pending').toString();
              final statusColor = _getStatusColor(status);

              return ListTile(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.folder_copy,
                    color: Colors.indigo, size: 28),
                title: Text(
                  data['caseTitle'] ?? 'Untitled Case',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Name: ${data['studentName'] ?? 'Unknown'}",
                          style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                      Text("ID: ${data['studentId'] ?? 'N/A'}",
                          style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                      Row(
                        children: [
                          Text("Status: ",
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color)),
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
              );
            },
          );
        },
      ),
    );
  }
}
