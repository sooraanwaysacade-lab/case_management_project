import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'case_details_screen.dart';

class CasesScreen extends StatefulWidget {
  final DateTime? semesterStartDate;
  final String? initialStatusFilter;
  final String? semesterLabel;
  
  const CasesScreen({
    super.key,
    this.semesterStartDate,
    this.initialStatusFilter,
    this.semesterLabel,
  });

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  final searchCtrl = TextEditingController();
  late String filter;

  @override
  void initState() {
    super.initState();
    filter = widget.initialStatusFilter ?? 'All';
  }

  // Helper to get semester end date (4 months after start)
  DateTime _getSemesterEnd(DateTime startDate) {
    int endMonth = startDate.month + 3; // 4 months total (start month + 3 more)
    int endYear = startDate.year;
    
    if (endMonth > 12) {
      endMonth -= 12;
      endYear++;
    }
    
    // Get the last day of the end month
    return DateTime(endYear, endMonth + 1, 0); // Day 0 of next month = last day of current month
  }

  Stream<QuerySnapshot> _stream() =>
      FirebaseFirestore.instance.collection('cases').orderBy('caseTitle').snapshots();

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

  /// 🗑️ Confirm and delete all cases
  Future<void> _deleteAllCases() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        titleTextStyle: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
        title: const Text('🗑️ Delete All Cases?'),
        content: const Text(
          'Are you sure you want to permanently delete ALL cases? This action cannot be undone.',
          style: TextStyle(fontSize: 15),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark 
          ? Theme.of(context).scaffoldBackgroundColor 
          : const Color(0xFFF5F7FA),
      appBar: widget.semesterLabel != null && widget.initialStatusFilter != null
          ? AppBar(
              backgroundColor: Colors.indigo,
              title: Row(
                children: [
                  Icon(Icons.filter_alt, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.semesterLabel} - ${widget.initialStatusFilter} Cases',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: Column(
        children: [
          // Enhanced search/filter bar
          _filters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.indigo),
                  );
                }

                if (!snap.hasData) {
                  return Center(
                    child: Text(
                      'No cases available.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                }

                var docs = snap.data!.docs;

                // 🔍 Search filter
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final title = (data['caseTitle'] ?? '').toString().toLowerCase();
                  final name = (data['studentName'] ?? '').toString().toLowerCase();
                  final id = (data['studentId'] ?? '').toString().toLowerCase();
                  final query = searchCtrl.text.toLowerCase();
                  return title.contains(query) || name.contains(query) || id.contains(query);
                }).toList();

                // 🔽 Status filter
                if (filter != 'All') {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return (data['status'] ?? '') == filter;
                  }).toList();
                }

                // 📅 Semester date filter (if provided)
                if (widget.semesterStartDate != null) {
                  final endDate = _getSemesterEnd(widget.semesterStartDate!);
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final createdAt = data['createdAt'] as Timestamp?;
                    if (createdAt == null) return false;
                    final caseDate = createdAt.toDate();
                    // Include cases created on or after startDate and on or before endDate
                    return !caseDate.isBefore(widget.semesterStartDate!) && !caseDate.isAfter(endDate);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No matching cases found.",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
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

  /// 🎯 Enhanced Filter + Search Bar
  Widget _filters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.3) 
                : Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 🔍 Enhanced Search Bar
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.grey[800] 
                      : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark 
                        ? Colors.grey[700]! 
                        : Colors.indigo.shade200,
                  ),
                ),
                child: TextField(
                  controller: searchCtrl,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.indigo, size: 22),
                    hintText: 'Search by Student ID, Name, or Case Title...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey.shade500,
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ⚙️ Enhanced Filter Button
          Container(
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.indigo.shade900.withOpacity(0.3) 
                  : Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark 
                    ? Colors.indigo.shade700 
                    : Colors.indigo.shade200,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showFilterDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_list, color: Colors.indigo, size: 22),
                      if (filter != 'All') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            filter,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🪄 Enhanced BottomSheet Filter Dialog
  void _showFilterDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.filter_list, color: Colors.indigo, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Filter by Status",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 21,
                      color: isDark ? Colors.indigo[300] : Colors.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (var option in [
                'All',
                'Pending',
                'Resolved',
                'Under Investigation',
                'Suspension',
                'Expulsion'
              ])
                InkWell(
                  onTap: () {
                    setState(() {
                      filter = option;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: filter == option
                          ? (isDark 
                              ? Colors.indigo.shade900.withOpacity(0.3) 
                              : Colors.indigo.shade50)
                          : (isDark 
                              ? Colors.grey[800] 
                              : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: filter == option
                            ? (isDark 
                                ? Colors.indigo.shade600 
                                : Colors.indigo.shade300)
                            : (isDark 
                                ? Colors.grey[700]! 
                                : Colors.grey.shade300),
                        width: filter == option ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          filter == option
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: filter == option
                              ? Colors.indigo
                              : (isDark ? Colors.grey[400] : Colors.grey.shade600),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: filter == option
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: filter == option
                                  ? (isDark 
                                      ? Colors.indigo[300] 
                                      : Colors.indigo.shade900)
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ),
                        if (filter == option)
                          Icon(
                            Icons.check_circle,
                            color: Colors.indigo,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}
