import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'admin_drawer.dart';

class AppealScreen extends StatefulWidget {
  const AppealScreen({super.key});

  @override
  State<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends State<AppealScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<QueryDocumentSnapshot> _appeals = [];
  List<QueryDocumentSnapshot> _filteredAppeals = [];
  Map<String, Map<String, dynamic>> _caseData = {}; // Cache case data (title, studentId)

  @override
  void initState() {
    super.initState();
    _loadAppeals();
    _searchController.addListener(_filterAppeals);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppeals() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('appeals')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _appeals = query.docs;
        _filteredAppeals = _appeals;
        _isLoading = false;
      });

      // Load case data (title and studentId) for appeals
      await _loadCaseData();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Error loading appeals: $e')),
        );
      }
    }
  }

  Future<void> _loadCaseData() async {
    final caseIds = _appeals
        .map((doc) => doc.data() as Map<String, dynamic>)
        .where((data) => data['caseId'] != null)
        .map((data) => data['caseId'].toString())
        .toSet()
        .toList();

    for (var caseId in caseIds) {
      try {
        final caseDoc = await FirebaseFirestore.instance
            .collection('cases')
            .doc(caseId)
            .get();
        if (caseDoc.exists) {
          final caseData = caseDoc.data() as Map<String, dynamic>?;
          _caseData[caseId] = {
            'caseTitle': caseData?['caseTitle'] ?? 'Unknown Case',
            'studentId': caseData?['studentId'] ?? 'N/A',
          };
        }
      } catch (e) {
        debugPrint("Error loading case data for $caseId: $e");
      }
    }
    setState(() {}); // Refresh UI with case data
  }

  void _filterAppeals() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredAppeals = _appeals;
      });
      return;
    }

    setState(() {
      _filteredAppeals = _appeals.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final email = (data['email'] ?? '').toString().toLowerCase();
        final caseId = (data['caseId'] ?? '').toString();
        final caseInfo = _caseData[caseId];
        final caseTitle = caseInfo?['caseTitle']?.toLowerCase() ?? '';
        final studentId = caseInfo?['studentId']?.toLowerCase() ?? '';

        return email.contains(query) ||
            caseTitle.contains(query) ||
            studentId.contains(query);
      }).toList();
    });
  }

  Future<void> _markAsRead(String appealId) async {
    try {
      // Mark as read by Admin (independent from Lecturer)
      await FirebaseFirestore.instance
          .collection('appeals')
          .doc(appealId)
          .update({'readByAdmin': true});
      
      // Reload appeals to reflect the read status change
      await _loadAppeals();
    } catch (e) {
      debugPrint("Error marking appeal as read: $e");
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context, String id, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🗑️ Delete Appeal?'),
        content: const Text(
          'Are you sure to delete this appeal.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteAppeal(id, email);
    }
  }

  Future<void> _deleteAppeal(String id, String email) async {
    try {
      await FirebaseFirestore.instance.collection('appeals').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Appeal deleted successfully'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      _loadAppeals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting appeal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllAppeals() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🗑️ Delete All Appeals?'),
        content: const Text(
          'Are you sure you want to delete all appeals?\nThis action cannot be undone.',
          style: TextStyle(fontSize: 15, color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final appeals = await FirebaseFirestore.instance.collection('appeals').get();
      for (var doc in appeals.docs) {
        await doc.reference.delete();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ All appeals deleted successfully'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      _loadAppeals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting appeals: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openAppealFile(String pathOrUrl, String appealId) async {
    // Mark as read when file is opened
    await _markAsRead(appealId);

    if (pathOrUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No file attached.')),
      );
      return;
    }

    try {
      if (pathOrUrl.startsWith('/') || pathOrUrl.startsWith('file://')) {
        final normalizedPath = pathOrUrl.replaceAll('file://', '');
        final file = File(normalizedPath);
        
        if (await file.exists()) {
          final result = await OpenFilex.open(file.path);
          if (result.type != ResultType.done) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ Unable to open file: ${result.message}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ File not found on this device.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ This file is stored in cloud storage and cannot be opened locally.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error opening file: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Color _getReadStatusColor(bool isRead) {
    return isRead ? Colors.green.shade600 : Colors.orange.shade600;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark 
          ? Theme.of(context).scaffoldBackgroundColor 
          : const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Search Bar with different color
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark 
                  ? Theme.of(context).scaffoldBackgroundColor 
                  : const Color(0xFFF5F7FA),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Search by email, case title, or student ID...',
              hintStyle: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.indigo, size: 22),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      color: Colors.grey.shade600,
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? Colors.grey[800] : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.indigo.shade200,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.indigo.shade200,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.indigo.shade600, 
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            ),
          ),
        ),

        // Appeals List
        Expanded(
          child: _filteredAppeals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'No appeals submitted yet.'
                            : 'No appeals found matching your search.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAppeals,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredAppeals.length,
                    itemBuilder: (_, i) {
                      final doc = _filteredAppeals[i];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      final email = data['email']?.toString() ?? 'Unknown';
                      final caseId = data['caseId']?.toString() ?? '';
                      final createdAt = data['createdAt'];
                      final localFilePath = data['localFilePath']?.toString() ?? '';
                      final fileUrl = data['fileUrl']?.toString() ?? '';
                      final isRead = data['readByAdmin'] == true; // Admin-specific read status

                      String createdText = "Unknown date";
                      if (createdAt != null) {
                        try {
                          createdText = DateFormat('MMM d, yyyy • h:mm a')
                              .format(createdAt.toDate());
                        } catch (_) {}
                      }

                      final caseInfo = _caseData[caseId];
                      final caseTitle = caseInfo?['caseTitle'] ?? 'Unknown Case';
                      final studentId = caseInfo?['studentId'] ?? 'N/A';
                      final hasFile = localFilePath.isNotEmpty || fileUrl.isNotEmpty;
                      final readStatusColor = _getReadStatusColor(isRead);
                      final statusText = isRead ? 'Read' : 'Unread';
                      final isDark = Theme.of(context).brightness == Brightness.dark;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Theme.of(context).cardColor : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: isDark 
                                  ? Colors.black.withOpacity(0.3) 
                                  : Colors.grey.shade200,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with status indicator
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: readStatusColor.withOpacity(0.1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Email icon container
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: readStatusColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isRead ? Icons.mark_email_read : Icons.mark_email_unread,
                                      color: readStatusColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          email,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          createdText,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: readStatusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: readStatusColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: readStatusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Three dots menu button - aligned with AppBar delete icon
                                  Padding(
                                    padding: const EdgeInsets.only(right: 0),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Colors.grey,
                                        size: 22,
                                      ),
                                      tooltip: 'More options',
                                      onPressed: () => _showDeleteConfirmation(context, doc.id, email),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Content Section
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Case Title
                                  _buildInfoRow(
                                    Icons.folder_copy,
                                    'Case Title: $caseTitle',
                                    Colors.indigo.shade700,
                                    16,
                                  ),
                                  const SizedBox(height: 12),
                                  // Student ID
                                  _buildInfoRow(
                                    Icons.badge,
                                    'Student ID: $studentId',
                                    Colors.black87,
                                    16,
                                  ),
                                  // File Attachment
                                  if (hasFile) ...[
                                    const SizedBox(height: 16),
                                    GestureDetector(
                                      onTap: () => _openAppealFile(
                                        localFilePath.isNotEmpty
                                            ? localFilePath
                                            : fileUrl,
                                        doc.id,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark 
                                              ? Colors.indigo.shade900.withOpacity(0.2) 
                                              : Colors.indigo.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDark 
                                                ? Colors.indigo.shade700 
                                                : Colors.indigo.shade200,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isDark 
                                                    ? Colors.indigo.shade800.withOpacity(0.5) 
                                                    : Colors.indigo.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.attach_file,
                                                size: 20,
                                                color: isDark 
                                                    ? Colors.indigo[300] 
                                                    : Colors.indigo.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'View Appeal File',
                                                style: TextStyle(
                                                  color: isDark 
                                                      ? Colors.indigo[300] 
                                                      : Colors.indigo.shade700,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 16,
                                              color: isDark 
                                                  ? Colors.indigo[400] 
                                                  : Colors.indigo.shade400,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color, double fontSize) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
