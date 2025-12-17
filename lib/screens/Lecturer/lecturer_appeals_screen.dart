import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

class LecturerAppealsScreen extends StatefulWidget {
  const LecturerAppealsScreen({super.key});

  @override
  State<LecturerAppealsScreen> createState() => _LecturerAppealsScreenState();
}

class _LecturerAppealsScreenState extends State<LecturerAppealsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? lecturerEmail;
  bool _isLoading = true;
  List<QueryDocumentSnapshot> _appeals = [];
  List<QueryDocumentSnapshot> _filteredAppeals = [];
  Map<String, Map<String, dynamic>> _caseData = {}; // Cache case data (title, studentId)

  @override
  void initState() {
    super.initState();
    lecturerEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    _loadAppeals();
    _searchController.addListener(_filterAppeals);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppeals() async {
    if (lecturerEmail == null || lecturerEmail!.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // First, get all cases assigned to this lecturer
      final casesQuery = await FirebaseFirestore.instance
          .collection('cases')
          .where('assignedInvestigators', arrayContains: lecturerEmail)
          .get();

      if (casesQuery.docs.isEmpty) {
        setState(() {
          _appeals = [];
          _filteredAppeals = [];
          _isLoading = false;
        });
        return;
      }

      final assignedCaseIds = casesQuery.docs.map((doc) => doc.id).toList();

      // Store case data for later use
      for (var doc in casesQuery.docs) {
        final caseData = doc.data();
        _caseData[doc.id] = {
          'caseTitle': caseData['caseTitle'] ?? 'Unknown Case',
          'studentId': caseData['studentId'] ?? 'N/A',
        };
      }

      // Query appeals for these case IDs (handle limit of 10 for whereIn)
      // Note: We don't use orderBy here to avoid composite index requirement
      // Instead, we'll sort in memory after fetching
      List<QueryDocumentSnapshot> allAppeals = [];
      if (assignedCaseIds.length <= 10) {
        final appealsQuery = await FirebaseFirestore.instance
            .collection('appeals')
            .where('caseId', whereIn: assignedCaseIds)
            .get();
        allAppeals = appealsQuery.docs;
      } else {
        // If more than 10 cases, query in batches
        for (var i = 0; i < assignedCaseIds.length; i += 10) {
          final batch = assignedCaseIds.skip(i).take(10).toList();
          final appealsQuery = await FirebaseFirestore.instance
              .collection('appeals')
              .where('caseId', whereIn: batch)
              .get();
          allAppeals.addAll(appealsQuery.docs);
        }
      }
      
      // Sort by createdAt descending in memory (avoids composite index requirement)
      allAppeals.sort((a, b) {
        final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // Descending order (newest first)
      });

      setState(() {
        _appeals = allAppeals;
        _filteredAppeals = allAppeals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Error loading appeals: $e')),
        );
      }
    }
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
    if (lecturerEmail == null || lecturerEmail!.isEmpty) return;
    
    try {
      // Get current readByLecturers array or create new one
      final appealDoc = await FirebaseFirestore.instance
          .collection('appeals')
          .doc(appealId)
          .get();
      
      final currentData = appealDoc.data() as Map<String, dynamic>?;
      final readByLecturers = List<String>.from(
        currentData?['readByLecturers'] ?? []
      );
      
      // Add this lecturer's email if not already in the list
      if (!readByLecturers.contains(lecturerEmail)) {
        readByLecturers.add(lecturerEmail!);
        
        // Update the appeal with the lecturer's read status (independent from Admin)
        await FirebaseFirestore.instance
            .collection('appeals')
            .doc(appealId)
            .update({'readByLecturers': readByLecturers});
      }
      
      // Reload appeals to reflect the read status change
      await _loadAppeals();
    } catch (e) {
      debugPrint("Error marking appeal as read: $e");
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
    if (lecturerEmail == null || lecturerEmail!.isEmpty) {
      return const Center(
        child: Text('Unable to load lecturer information.'),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark 
          ? Theme.of(context).scaffoldBackgroundColor 
          : const Color(0xFFF5F7FA),
      child: Column(
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
                            ? 'No appeals submitted for your assigned cases yet.'
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
                      // Check if this specific lecturer has read it (independent from Admin)
                      final readByLecturers = List<String>.from(
                        data['readByLecturers'] ?? []
                      );
                      final isRead = lecturerEmail != null && 
                                    readByLecturers.contains(lecturerEmail);

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
