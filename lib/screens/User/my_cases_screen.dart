import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_case_details_screen.dart';

class MyCasesScreen extends StatefulWidget {
  const MyCasesScreen({super.key});

  @override
  State<MyCasesScreen> createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends State<MyCasesScreen> {
  String? userEmail;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email?.trim().toLowerCase();
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  /// 🎨 Color helper for case status
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.indigo));
    }

    if (userEmail == null || userEmail!.isEmpty) {
      return Center(
        child: Text(
          'Unable to load your profile.',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      );
    }

    // We fetch both:
    // 1) cases where lecturer/admin stored student's email in 'email'
    // 2) cases where system stored student's email in 'targetEmail'
    final casesCollection = FirebaseFirestore.instance.collection('cases');

    final streamEmail = casesCollection
        .where('email', isEqualTo: userEmail)
        .snapshots();

    final streamTargetEmail = casesCollection
        .where('targetEmail', isEqualTo: userEmail)
        .snapshots();

    return Container(
      color: isDark 
          ? Theme.of(context).scaffoldBackgroundColor 
          : const Color(0xFFF5F7FA),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: streamEmail,
              builder: (context, snapA) {
                if (snapA.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.indigo),
                  );
                }
                if (snapA.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading cases',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapA.error}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: streamTargetEmail,
                  builder: (context, snapB) {
                    if (snapB.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.indigo),
                      );
                    }
                    if (snapB.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading cases',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${snapB.error}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    // Merge both result sets and remove duplicates by doc id
                    final listA = snapA.data?.docs ?? [];
                    final listB = snapB.data?.docs ?? [];
                    final mergedMap = <String, DocumentSnapshot>{};

                    for (final d in listA) {
                      mergedMap[d.id] = d;
                    }
                    for (final d in listB) {
                      mergedMap[d.id] = d;
                    }

                    var docs = mergedMap.values.toList();

                    // Sort by createdAt desc (client-side to avoid composite index requirement)
                    docs.sort((a, b) {
                      final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                      final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                      return bDate.compareTo(aDate);
                    });

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: isDark ? Colors.grey[600] : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No cases found.",
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final status = (data['status'] ?? 'Pending').toString();
                        final statusColor = _getStatusColor(status);
                        final caseTitle = data['caseTitle'] ?? 'Untitled Case';
                        final studentName = data['studentName'] ?? 'Unknown';
                        final studentId = data['studentId'] ?? 'N/A';

                        return _buildCaseCard(
                          context: context,
                          caseTitle: caseTitle,
                          studentName: studentName,
                          studentId: studentId,
                          status: status,
                          statusColor: statusColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserCaseDetailsScreen(caseDoc: docs[i]),
                              ),
                            );
                          },
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

  Widget _buildCaseCard({
    required BuildContext context,
    required String caseTitle,
    required String studentName,
    required String studentId,
    required String status,
    required Color statusColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark ? Theme.of(context).cardColor : Colors.white,
                statusColor.withOpacity(isDark ? 0.1 : 0.05),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Folder Icon with Status Color
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.folder_copy,
                  color: statusColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              // Case Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Case Title
                    Text(
                      caseTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // 1. Name
                    Row(
                      children: [
                        Icon(
                          Icons.person, 
                          size: 18, 
                          color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Name: ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            studentName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 2. ID
                    Row(
                      children: [
                        Icon(
                          Icons.badge, 
                          size: 18, 
                          color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ID: ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            studentId,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 3. Status
                    Row(
                      children: [
                        Icon(
                          Icons.flag,
                          size: 18,
                          color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Status: ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor, width: 1.5),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow Icon
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

}
