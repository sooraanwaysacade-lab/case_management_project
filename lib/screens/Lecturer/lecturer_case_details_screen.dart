import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:open_filex/open_filex.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LecturerCaseDetailsScreen extends StatefulWidget {
  final DocumentSnapshot caseDoc;

  const LecturerCaseDetailsScreen({super.key, required this.caseDoc});

  @override
  State<LecturerCaseDetailsScreen> createState() =>
      _LecturerCaseDetailsScreenState();
}

class _LecturerCaseDetailsScreenState extends State<LecturerCaseDetailsScreen> {
  final TextEditingController studentIdCtrl = TextEditingController();
  final TextEditingController studentNameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController caseTitleCtrl = TextEditingController();
  final TextEditingController descriptionCtrl = TextEditingController();

  String status = 'Pending';
  bool isEditing = false;
  Map<String, dynamic> originalData = {};

  @override
  void dispose() {
    studentIdCtrl.dispose();
    studentNameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    caseTitleCtrl.dispose();
    descriptionCtrl.dispose();
    super.dispose();
  }

  /// Sync controllers only when not editing (so ongoing edits are not overwritten)
  void _syncControllers(Map<String, dynamic> data) {
    if (isEditing) return;

    void set(TextEditingController c, String? v) {
      final newText = (v ?? '');
      if (c.text != newText) c.text = newText;
    }

    set(studentIdCtrl, data['studentId']);
    set(studentNameCtrl, data['studentName']);
    // Prefer the primary student email, but fall back to targetEmail if needed.
    set(emailCtrl, (data['email'] ?? data['targetEmail']) as String?);
    set(phoneCtrl, data['phone']);
    set(caseTitleCtrl, data['caseTitle']);
    set(descriptionCtrl, data['caseDescription']);

    status = (data['status'] ?? 'Pending') as String;
    originalData = Map<String, dynamic>.from(data);
  }

  Future<void> _openEvidence(String filePathOrUrl, bool isLocal) async {
    try {
      if (isLocal) {
        final f = File(filePathOrUrl);
        if (await f.exists()) {
          await OpenFilex.open(filePathOrUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Local file not found: $filePathOrUrl")),
          );
        }
      } else {
        if (filePathOrUrl.trim().isEmpty) return;
        if (await canLaunchUrlString(filePathOrUrl)) {
          await launchUrlString(filePathOrUrl, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Could not open cloud link.")),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening evidence: $e")),
      );
    }
  }

  Future<void> _openSuspensionExpulsionFile(String path) async {
    if (path.trim().isEmpty) return;

    try {
      if (path.startsWith('/') || path.startsWith('file://')) {
        final normalizedPath = path.replaceAll('file://', '');
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
              content: Text("⚠️ File not found on device."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error opening file: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _openEmail(String email) async {
    if (email.trim().isEmpty) return;

    try {
      final encodedEmail = Uri.encodeComponent(email);
      final uri = Uri.parse('mailto:$encodedEmail');

      // Try multiple launch modes for better compatibility
      LaunchMode launchMode = LaunchMode.externalNonBrowserApplication;
      if (!await launchUrl(uri, mode: launchMode)) {
        launchMode = LaunchMode.platformDefault;
        if (!await launchUrl(uri, mode: launchMode)) {
          launchMode = LaunchMode.externalApplication;
          await launchUrl(uri, mode: launchMode);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Couldn't open email app: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _generateChangeSummary(
      Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    final buffer = StringBuffer();
    final fields = [
      'studentId',
      'studentName',
      'email',
      'phone',
      'caseTitle',
      'caseDescription',
      'status',
    ];

    for (var field in fields) {
      final oldVal = (oldData[field] ?? '').toString().trim();
      final newVal = (newData[field] ?? '').toString().trim();
      if (oldVal != newVal) {
        // Make the status change extra clear in the summary
        if (field == 'status') {
          buffer.writeln(
              '- Case Status changed from "$oldVal" to "$newVal"');
        } else {
          buffer.writeln(
              '- ${_labelForKey(field)} changed from "$oldVal" to "$newVal"');
        }
      }
    }

    return buffer.isEmpty
        ? 'No visible field changes.'
        : buffer.toString().trim();
  }

  /// Builds a short, human‑friendly sentence for the most important change
  /// (currently the case status). This will be shown at the top of the
  /// notification body so that updates like "Pending to Suspension" are
  /// immediately visible.
  String? _buildStatusChangeSentence(
      Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    final oldStatus = (oldData['status'] ?? '').toString().trim();
    final newStatus = (newData['status'] ?? '').toString().trim();

    if (oldStatus.isEmpty ||
        newStatus.isEmpty ||
        oldStatus.toLowerCase() == newStatus.toLowerCase()) {
      return null;
    }

    return 'Case status changed from "$oldStatus" to "$newStatus".';
  }

  String _labelForKey(String key) {
    switch (key) {
      case 'studentId':
        return 'Student ID';
      case 'studentName':
        return 'Student Name';
      case 'email':
        return 'Student Email';
      case 'phone':
        return 'Phone';
      case 'caseTitle':
        return 'Case Title';
      case 'caseDescription':
        return 'Case Description';
      case 'status':
        return 'Case Status';
      default:
        return key;
    }
  }

  Future<void> _updateCase(DocumentReference ref) async {
    final newCaseTitle = caseTitleCtrl.text.trim();
    // Ensure we always have a valid student email; fall back to existing values
    // from Firestore if the text field is empty.
    String newStudentEmail = emailCtrl.text.trim();
    if (newStudentEmail.isEmpty) {
      newStudentEmail = (originalData['email'] ??
              originalData['targetEmail'] ??
              '')
          .toString()
          .trim();
    }
    final studentId = studentIdCtrl.text.trim();

    final currentLecturerEmail =
        FirebaseAuth.instance.currentUser?.email ?? 'Unknown investigator';

    final newData = {
      'studentId': studentId,
      'studentName': studentNameCtrl.text.trim(),
      'email': newStudentEmail,
      // Keep targetEmail in sync so other parts of the app that rely on it
      // (for example when creating new notifications) always have the same value.
      'targetEmail': newStudentEmail,
      'phone': phoneCtrl.text.trim(),
      'caseTitle': newCaseTitle,
      'caseDescription': descriptionCtrl.text.trim(),
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final previous = Map<String, dynamic>.from(originalData);
    final changeSummary = _generateChangeSummary(previous, newData);
    final statusSentence = _buildStatusChangeSentence(previous, newData);

    await ref.update(newData);
    originalData = Map<String, dynamic>.from(newData);

    final notifications = FirebaseFirestore.instance.collection('notifications');

    // Notification for Admin
    await notifications.add({
      'targetEmail': 'admin@system',
      'title': 'Case Updated By Investigator',
      'body':
          '$currentLecturerEmail has updated the case titled "$newCaseTitle" with Student ID $studentId.\n'
          '${statusSentence != null ? '$statusSentence\n\n' : '\n'}'
          'Changes made:\n$changeSummary',
      'caseId': ref.id,
      'type': 'case_updated_by_investigator',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notification for Student
    if (newStudentEmail.isNotEmpty) {
      await notifications.add({
        'targetEmail': newStudentEmail,
        'title': 'Your Case Was Updated',
        'body':
            'Your case "$newCaseTitle" has been updated by investigator $currentLecturerEmail.\n'
            '${statusSentence != null ? '$statusSentence\n\n' : '\n'}'
            'Changes made:\n$changeSummary',
        'caseId': ref.id,
        // Use the same type that the user notifications screen expects
        // so that it is treated like other case update alerts.
        'type': 'case_updated',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Notification for other assigned investigators (if any)
    // Fetch the latest case data to get the most up-to-date list of assigned investigators
    try {
      final caseSnapshot = await ref.get();
      if (caseSnapshot.exists) {
        final caseData = caseSnapshot.data() as Map<String, dynamic>?;
        final assignedInvestigators = List<String>.from(caseData?['assignedInvestigators'] ?? []);
        final currentLecturerNormalized = currentLecturerEmail.trim().toLowerCase();
        
        debugPrint('🔔 Notification check: Found ${assignedInvestigators.length} assigned investigators');
        debugPrint('🔔 Current lecturer: $currentLecturerEmail');
        
        // Find all other investigators (excluding the current lecturer)
        final otherInvestigators = <String>[];
        for (var email in assignedInvestigators) {
          final trimmedEmail = email.toString().trim();
          final normalizedEmail = trimmedEmail.toLowerCase();
          
          debugPrint('🔔 Checking investigator: $trimmedEmail (normalized: $normalizedEmail)');
          
          // Skip if empty or if it's the current lecturer
          if (trimmedEmail.isNotEmpty && normalizedEmail != currentLecturerNormalized) {
            // Check if we've already added this email (case-insensitive check)
            final alreadyAdded = otherInvestigators.any(
              (e) => e.trim().toLowerCase() == normalizedEmail
            );
            
            if (!alreadyAdded) {
              otherInvestigators.add(trimmedEmail);
              debugPrint('🔔 Added to notification list: $trimmedEmail');
            }
          } else {
            debugPrint('🔔 Skipped: ${trimmedEmail.isEmpty ? "empty email" : "current lecturer"}');
          }
        }

        debugPrint('🔔 Sending notifications to ${otherInvestigators.length} other investigators');

        // Send notifications to all other assigned investigators
        for (final invEmail in otherInvestigators) {
          await notifications.add({
            'targetEmail': invEmail,
            'title': 'Assigned Case Updated',
            'body':
                'The case titled "$newCaseTitle" with Student ID $studentId has been updated by $currentLecturerEmail.\n'
                '${statusSentence != null ? '$statusSentence\n\n' : '\n'}'
                'Changes made:\n$changeSummary',
            'caseId': ref.id,
            'type': 'case_updated_by_investigator',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint('🔔 Notification sent to: $invEmail');
        }
      } else {
        debugPrint('⚠️ Case document does not exist when fetching for notifications');
      }
    } catch (e) {
      // If fetching fails, fall back to originalData
      debugPrint('⚠️ Error fetching case data for notifications: $e');
      final assignedInvestigators = List<String>.from(originalData['assignedInvestigators'] ?? []);
      final currentLecturerNormalized = currentLecturerEmail.trim().toLowerCase();
      
      final otherInvestigators = <String>[];
      for (var email in assignedInvestigators) {
        final trimmedEmail = email.toString().trim();
        final normalizedEmail = trimmedEmail.toLowerCase();
        
        if (trimmedEmail.isNotEmpty && normalizedEmail != currentLecturerNormalized) {
          final alreadyAdded = otherInvestigators.any(
            (e) => e.trim().toLowerCase() == normalizedEmail
          );
          
          if (!alreadyAdded) {
            otherInvestigators.add(trimmedEmail);
          }
        }
      }

      for (final invEmail in otherInvestigators) {
        await notifications.add({
          'targetEmail': invEmail,
          'title': 'Assigned Case Updated',
          'body':
              'The case titled "$newCaseTitle" with Student ID $studentId has been updated by $currentLecturerEmail.\n'
              '${statusSentence != null ? '$statusSentence\n\n' : '\n'}'
              'Changes made:\n$changeSummary',
          'caseId': ref.id,
          'type': 'case_updated_by_investigator',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    if (mounted) {
      setState(() => isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Case updated successfully!'),
          backgroundColor: Colors.indigo,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final docRef = widget.caseDoc.reference;

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).scaffoldBackgroundColor
                : const Color(0xFFF5F7FA),
            body: const Center(child: CircularProgressIndicator(color: Colors.indigo)),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).scaffoldBackgroundColor
                : const Color(0xFFF5F7FA),
            body: const Center(child: Text('Case not found')),
          );
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        _syncControllers(data);

        final createdAt = data['createdAt'] as Timestamp?;
        final incidentDate = data['incidentDate'];
        final reporterName = data['reporterName'] ?? 'Unknown Reporter';

        final evidenceUrl = data['evidenceUrl'] ?? '';
        final evidenceLocalPath = data['evidenceLocalPath'] ?? '';
        final hasLocalFile = evidenceLocalPath.toString().isNotEmpty;
        final hasFirebaseUrl = evidenceUrl.toString().isNotEmpty;

        final investigators = List<String>.from(data['assignedInvestigators'] ?? []);

        String formattedDate = createdAt != null
            ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt.toDate())
            : 'Unknown Date';

        String formattedIncident = '';
        if (incidentDate != null) {
          try {
            final parsed = DateTime.parse(incidentDate);
            formattedIncident = DateFormat('MMM d, yyyy • h:mm a').format(parsed);
          } catch (_) {}
        }

        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).scaffoldBackgroundColor
              : const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: Text(
              caseTitleCtrl.text.isNotEmpty ? caseTitleCtrl.text : 'Case Details',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.indigo,
            actions: [
              IconButton(
                icon: Icon(isEditing ? Icons.cancel : Icons.edit),
                tooltip: isEditing ? 'Cancel Editing' : 'Edit Case',
                onPressed: () => setState(() => isEditing = !isEditing),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reporter / Incident Information Card (meeting link removed)
                _buildSectionCard(
                  title: 'Reporter Information',
                  icon: Icons.person_outline,
                  children: [
                    _buildInfoRow(Icons.person, 'Reporter Name', reporterName),
                    _buildInfoRow(Icons.calendar_today, 'Reported On', formattedDate),
                    if (formattedIncident.isNotEmpty)
                      _buildInfoRow(Icons.event, 'Incident Date', formattedIncident),
                  ],
                ),

                const SizedBox(height: 16),

                // Student Information Card
                _buildSectionCard(
                  title: 'Student Information',
                  icon: Icons.school,
                  children: [
                    _buildEditableField(
                      controller: studentIdCtrl,
                      label: 'Student ID',
                      icon: Icons.badge,
                      isEditing: isEditing,
                    ),
                    const SizedBox(height: 12),
                    _buildEditableField(
                      controller: studentNameCtrl,
                      label: 'Student Name',
                      icon: Icons.person,
                      isEditing: isEditing,
                    ),
                    const SizedBox(height: 12),
                    _buildEmailField(
                      controller: emailCtrl,
                      label: 'Student Email',
                      icon: Icons.email,
                      isEditing: isEditing,
                    ),
                    const SizedBox(height: 12),
                    _buildEditableField(
                      controller: phoneCtrl,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      isEditing: isEditing,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Case Information Card
                _buildSectionCard(
                  title: 'Case Information',
                  icon: Icons.folder,
                  children: [
                    _buildEditableField(
                      controller: caseTitleCtrl,
                      label: 'Case Title',
                      icon: Icons.title,
                      isEditing: isEditing,
                    ),
                    const SizedBox(height: 12),
                    _buildEditableField(
                      controller: descriptionCtrl,
                      label: 'Case Description',
                      icon: Icons.description,
                      isEditing: isEditing,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusDropdown(),
                    // Suspension/Expulsion File Section (read-only for lecturer)
                    if ((status == 'Suspension' || status == 'Expulsion') &&
                        data['suspensionExpulsionFilePath'] != null &&
                        data['suspensionExpulsionFilePath'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          final filePath = data['suspensionExpulsionFilePath'].toString();
                          final fileName = filePath.isNotEmpty
                              ? File(filePath).path.split('/').last
                              : 'File';
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.orange.shade900.withOpacity(0.2)
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? Colors.orange.shade700
                                    : Colors.orange.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: isDark
                                          ? Colors.orange[300]
                                          : Colors.orange.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$status Letter/File',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isDark
                                            ? Colors.orange[300]
                                            : Colors.orange.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                InkWell(
                                  onTap: () => _openSuspensionExpulsionFile(filePath),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.description,
                                        color: Colors.orange.shade700,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fileName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: isDark
                                                    ? Colors.orange[300]
                                                    : Colors.orange.shade900,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Tap to open',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.open_in_new,
                                        color: Colors.orange.shade700,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Evidence File Card
                if (hasLocalFile || hasFirebaseUrl)
                  _buildSectionCard(
                    title: 'Evidence File',
                    icon: Icons.attach_file,
                    children: [
                      _buildEvidenceSection(evidenceLocalPath, evidenceUrl),
                    ],
                  ),

                if (hasLocalFile || hasFirebaseUrl) const SizedBox(height: 16),

                // Assigned Investigators Card
                _buildSectionCard(
                  title: 'Assigned Investigators',
                  icon: Icons.people,
                  children: [
                    if (investigators.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No investigators assigned yet.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ...investigators.map((email) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: email.isNotEmpty ? () => _openEmail(email) : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.mail_outline,
                                      color: Colors.blue.shade600, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Investigator',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          email.isNotEmpty ? email : 'No email',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: email.isNotEmpty
                                                ? Colors.blue.shade700
                                                : Colors.grey.shade600,
                                            decoration: email.isNotEmpty
                                                ? TextDecoration.underline
                                                : TextDecoration.none,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (email.isNotEmpty)
                                    Icon(Icons.open_in_new,
                                        color: Colors.blue.shade600, size: 18),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                ),

                const SizedBox(height: 24),

                // Save Button
                if (isEditing)
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateCase(docRef),
                      icon: const Icon(Icons.save_rounded, size: 22),
                      label: const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      color: isDark ? Theme.of(context).cardColor : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark
                  ? Colors.indigo.shade900.withOpacity(0.2)
                  : Colors.indigo.shade50,
              isDark ? Theme.of(context).cardColor : Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
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
                    child: Icon(icon, color: Colors.indigo.shade700, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.indigo.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isEditing,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isEditing
            ? (isDark ? Colors.grey[800] : Colors.white)
            : (isDark ? Colors.grey[900] : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEditing
              ? (isDark ? Colors.indigo.shade600 : Colors.indigo.shade300)
              : (isDark ? Colors.grey[700]! : Colors.grey.shade300),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        enabled: isEditing,
        maxLines: maxLines,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(icon, color: Colors.indigo.shade600, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: false,
        ),
      ),
    );
  }

  Widget _buildEmailField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isEditing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email = controller.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: isEditing
            ? (isDark ? Colors.grey[800] : Colors.white)
            : (isDark ? Colors.grey[900] : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEditing
              ? (isDark ? Colors.indigo.shade600 : Colors.indigo.shade300)
              : (isDark ? Colors.grey[700]! : Colors.grey.shade300),
          width: 1.5,
        ),
      ),
      child: isEditing
          ? TextField(
              controller: controller,
              enabled: true,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon: Icon(icon, color: Colors.indigo.shade600, size: 20),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            )
          : InkWell(
              onTap: email.isNotEmpty ? () => _openEmail(email) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email.isNotEmpty ? email : 'No email',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: email.isNotEmpty
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade600,
                              decoration: email.isNotEmpty
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (email.isNotEmpty)
                      Icon(Icons.open_in_new, color: Colors.blue.shade600, size: 18),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isEditing
            ? (isDark ? Colors.grey[800] : Colors.white)
            : (isDark ? Colors.grey[900] : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEditing
              ? (isDark ? Colors.indigo.shade600 : Colors.indigo.shade300)
              : (isDark ? Colors.grey[700]! : Colors.grey.shade300),
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: status,
        items: const [
          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
          DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
          DropdownMenuItem(
              value: 'Under Investigation', child: Text('Under Investigation')),
          DropdownMenuItem(value: 'Suspension', child: Text('Suspension')),
          DropdownMenuItem(value: 'Expulsion', child: Text('Expulsion')),
        ],
        onChanged: isEditing
            ? (v) {
                setState(() {
                  status = v!;
                });
              }
            : null,
        decoration: InputDecoration(
          labelText: 'Case Status',
          labelStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(Icons.flag, color: Colors.indigo.shade600, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: false,
        ),
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEvidenceSection(String localPath, String firebaseUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLocal = localPath.toString().isNotEmpty;
    final displayPath = isLocal ? localPath : firebaseUrl;
    final displayName = isLocal
        ? (localPath.split('/').last)
        : (firebaseUrl.split('/').last);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade200, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.file_present, color: Colors.indigo, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Evidence File',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  style: TextStyle(
                    color: Colors.indigo.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.open_in_new, color: Colors.indigo.shade600, size: 20),
            onPressed: () => _openEvidence(displayPath, isLocal),
            tooltip: 'Open file',
          ),
        ],
      ),
    );
  }
}
