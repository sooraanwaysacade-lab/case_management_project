import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart';
import '../helpers/file_utils.dart';

class CaseDetailsScreen extends StatefulWidget {
  final DocumentSnapshot caseDoc;

  const CaseDetailsScreen({super.key, required this.caseDoc});

  @override
  State<CaseDetailsScreen> createState() => _CaseDetailsScreenState();
}

class _CaseDetailsScreenState extends State<CaseDetailsScreen> {
  late TextEditingController studentIdCtrl;
  late TextEditingController studentNameCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController caseTitleCtrl;
  late TextEditingController descriptionCtrl;

  List<TextEditingController> investigatorCtrls = [];

  String status = 'Pending';
  bool isEditing = false;
  late Map<String, dynamic> originalData;
  PlatformFile? suspensionExpulsionFile;
  String? suspensionExpulsionFilePath;
  bool evidenceDeleted = false; // Track if evidence file should be deleted
  String? currentEvidenceLocalPath;
  String? currentEvidenceUrl;
  PlatformFile? newEvidenceFile; // Track new evidence file for replacement

  @override
  void initState() {
    super.initState();
    final data = widget.caseDoc.data() as Map<String, dynamic>;
    originalData = Map<String, dynamic>.from(data);
    studentIdCtrl = TextEditingController(text: data['studentId']);
    studentNameCtrl = TextEditingController(text: data['studentName']);
    emailCtrl = TextEditingController(text: data['email']);
    phoneCtrl = TextEditingController(text: data['phone']);
    caseTitleCtrl = TextEditingController(text: data['caseTitle']);
    descriptionCtrl = TextEditingController(text: data['caseDescription']);
    status = data['status'] ?? 'Pending';
    suspensionExpulsionFilePath = data['suspensionExpulsionFilePath']?.toString();
    currentEvidenceLocalPath = data['evidenceLocalPath']?.toString();
    currentEvidenceUrl = data['evidenceUrl']?.toString();

    final List<dynamic>? investigators = data['assignedInvestigators'];
    if (investigators != null && investigators.isNotEmpty) {
      investigatorCtrls = investigators
          .map((e) => TextEditingController(text: e.toString()))
          .toList();
    } else {
      investigatorCtrls = [TextEditingController()];
    }
  }

  Future<void> _pickEvidenceFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          newEvidenceFile = result.files.single;
          evidenceDeleted = false; // Reset deletion flag if replacing
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📂 Evidence file selected: ${result.files.single.name}'),
            backgroundColor: Colors.indigo,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Failed to pick file: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _pickSuspensionExpulsionFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          suspensionExpulsionFile = result.files.single;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📂 File selected: ${result.files.single.name}'),
            backgroundColor: Colors.indigo,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Failed to pick file: $e"),
          backgroundColor: Colors.redAccent,
        ),
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
      // URL encode the email to handle special characters
      final encodedEmail = Uri.encodeComponent(email.trim());
      final emailUri = Uri.parse('mailto:$encodedEmail');
      
      // Try launching directly - don't check canLaunchUrl first as it can be unreliable
      try {
        await launchUrl(
          emailUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        // If externalNonBrowserApplication fails, try platformDefault
        try {
          await launchUrl(
            emailUri,
            mode: LaunchMode.platformDefault,
          );
        } catch (e2) {
          // Last resort: try externalApplication
          await launchUrl(
            emailUri,
            mode: LaunchMode.externalApplication,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Could not open email app. Please ensure Gmail or another email app is installed.\nError: $e"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _openEvidence(String pathOrUrl) async {
    if (pathOrUrl.trim().isEmpty) return;

    try {
      if (pathOrUrl.startsWith('/') || pathOrUrl.startsWith('file://')) {
        final normalizedPath = pathOrUrl.replaceAll('file://', '');
        final file = File(normalizedPath);
        if (await file.exists()) {
          await OpenFilex.open(file.path);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Evidence file not found on device."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        if (await canLaunchUrlString(pathOrUrl)) {
          await launchUrlString(pathOrUrl, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("❌ Could not open link."),
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

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Delete this Case?'),
        content: const Text(
          'Are you sure you want to delete this case? This action cannot be undone.',
          style: TextStyle(color: Colors.redAccent, fontSize: 15),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) await _deleteCase();
  }

  Future<void> _deleteCase() async {
    final caseData = widget.caseDoc.data() as Map<String, dynamic>;
    final title = caseData['caseTitle'] ?? 'Unnamed Case';
    final studentEmail = caseData['email'] ?? '';

    await widget.caseDoc.reference.delete();

    final notifications = FirebaseFirestore.instance.collection('notifications');
    await notifications.add({
      'targetEmail': 'admin@system',
      'title': '🗑️ Case Deleted',
      'body': 'The case "$title" has been deleted by admin.',
      'caseId': widget.caseDoc.id,
      'type': 'case_deleted',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (studentEmail.isNotEmpty) {
      await notifications.add({
        'targetEmail': studentEmail,
        'title': '🗑️ Your Case Deleted',
        'body': 'Your case "$title" has been deleted by admin.',
        'caseId': widget.caseDoc.id,
        'type': 'case_deleted',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🗑️ Case "$title" deleted successfully.'),
        backgroundColor: Colors.redAccent,
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  // --------------------------------------------------------------------
  // ⭐ UPDATED METHOD — NOW SENDS DETAILED NOTIFICATIONS WITH CHANGES
  // --------------------------------------------------------------------
  Future<void> _updateCase() async {
    final caseTitle = caseTitleCtrl.text.trim();
    final studentEmail = emailCtrl.text.trim();

    final investigatorEmails = investigatorCtrls
        .map((ctrl) => ctrl.text.trim())
        .where((email) => email.isNotEmpty)
        .toList();

    // Save suspension/expulsion file if selected
    String? finalSuspensionExpulsionPath = suspensionExpulsionFilePath;
    if (suspensionExpulsionFile != null) {
      try {
        if (suspensionExpulsionFile!.bytes != null) {
          finalSuspensionExpulsionPath = await saveFileToAppDir(
            bytes: suspensionExpulsionFile!.bytes!,
            originalName: suspensionExpulsionFile!.name,
          );
        } else if (suspensionExpulsionFile!.path != null) {
          finalSuspensionExpulsionPath = await copyFileToAppDir(
            File(suspensionExpulsionFile!.path!),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Error saving file: $e"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // Save new evidence file if selected (replacement)
    String? finalEvidencePath = currentEvidenceLocalPath;
    if (newEvidenceFile != null) {
      try {
        if (newEvidenceFile!.bytes != null) {
          finalEvidencePath = await saveFileToAppDir(
            bytes: newEvidenceFile!.bytes!,
            originalName: newEvidenceFile!.name,
          );
        } else if (newEvidenceFile!.path != null) {
          finalEvidencePath = await copyFileToAppDir(
            File(newEvidenceFile!.path!),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Error saving evidence file: $e"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    final newData = {
      'studentId': studentIdCtrl.text.trim(),
      'studentName': studentNameCtrl.text.trim(),
      'email': studentEmail,
      'phone': phoneCtrl.text.trim(),
      'caseTitle': caseTitle,
      'caseDescription': descriptionCtrl.text.trim(),
      'status': status,
      'assignedInvestigators': investigatorEmails,
      if (finalSuspensionExpulsionPath != null)
        'suspensionExpulsionFilePath': finalSuspensionExpulsionPath,
      // Handle evidence file: replace if new file selected, delete if marked for deletion
      if (newEvidenceFile != null && finalEvidencePath != null) ...{
        'evidenceLocalPath': finalEvidencePath,
        'evidenceUrl': FieldValue.delete(), // Remove old Firebase URL if exists
      } else if (evidenceDeleted) ...{
        'evidenceLocalPath': FieldValue.delete(),
        'evidenceUrl': FieldValue.delete(),
      },
    };

    // -------------------------------------------------------
    // 🔍 DETECT CHANGES
    // -------------------------------------------------------
    List<String> changes = [];

    void compareField(String label, dynamic oldValue, dynamic newValue) {
      if (oldValue.toString() != newValue.toString()) {
        changes.add("• $label: \"$oldValue\" → \"$newValue\"");
      }
    }

    compareField("Student ID", originalData['studentId'], newData['studentId']);
    compareField("Student Name", originalData['studentName'], newData['studentName']);
    compareField("Email", originalData['email'], newData['email']);
    compareField("Phone", originalData['phone'], newData['phone']);
    compareField("Case Title", originalData['caseTitle'], newData['caseTitle']);
    compareField("Case Description", originalData['caseDescription'], newData['caseDescription']);
    compareField("Status", originalData['status'], newData['status']);

    // Investigators list comparison
    final oldList = List<String>.from(originalData['assignedInvestigators'] ?? []);
    final newList = investigatorEmails;

    for (var oldInv in oldList) {
      if (!newList.contains(oldInv)) {
        changes.add("• Investigator Removed: $oldInv");
      }
    }
    for (var newInv in newList) {
      if (!oldList.contains(newInv)) {
        changes.add("• Investigator Added: $newInv");
      }
    }

    // Check if evidence was deleted or replaced
    if (evidenceDeleted) {
      changes.add("• Evidence File: Removed");
    } else if (newEvidenceFile != null) {
      changes.add("• Evidence File: Replaced with \"${newEvidenceFile!.name}\"");
    }

    // Format changes text professionally
    final changesText = changes.isEmpty
        ? "No changes were made to this case."
        : "The following changes were made:\n\n${changes.join("\n")}";

    // -------------------------------------------------------
    // 🔥 UPDATE DB FIRST
    // -------------------------------------------------------
    await widget.caseDoc.reference.update({
      ...newData,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // -------------------------------------------------------
    // 🔄 UPDATE RELATED APPEALS TO MAINTAIN CONSISTENCY
    // -------------------------------------------------------
    try {
      final appealsQuery = await FirebaseFirestore.instance
          .collection('appeals')
          .where('caseId', isEqualTo: widget.caseDoc.id)
          .get();

      // Update all appeals related to this case
      final appealUpdates = <String, dynamic>{
        'email': studentEmail,
        'studentId': newData['studentId'],
        'studentName': newData['studentName'],
      };

      // Only update if there are actual changes to email, studentId, or studentName
      final hasEmailChange = originalData['email'] != newData['email'];
      final hasStudentIdChange = originalData['studentId'] != newData['studentId'];
      final hasStudentNameChange = originalData['studentName'] != newData['studentName'];

      if (hasEmailChange || hasStudentIdChange || hasStudentNameChange) {
        final batch = FirebaseFirestore.instance.batch();
        for (var appealDoc in appealsQuery.docs) {
          batch.update(appealDoc.reference, appealUpdates);
        }
        await batch.commit();
        debugPrint('Updated ${appealsQuery.docs.length} appeal(s) to match case changes');
      }
    } catch (e) {
      debugPrint('⚠️ Error updating related appeals: $e');
      // Don't show error to user as case update was successful
    }

    // -------------------------------------------------------
    // 🔔 SEND UPDATED NOTIFICATIONS WITH CHANGES INCLUDED
    // -------------------------------------------------------
    final notifications = FirebaseFirestore.instance.collection('notifications');
    final studentId = newData['studentId'] ?? '';

    // 1️⃣ Notify Admin
    await notifications.add({
      'targetEmail': 'admin@system',
      'title': 'Case Updated Successfully',
      'body':
      'Case Title: $caseTitle\n Student ID: $studentId\nUpdate Details:\n$changesText\n',
      'caseId': widget.caseDoc.id,
      'type': 'case_updated',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2️⃣ Notify Student
    if (studentEmail.isNotEmpty) {
      await notifications.add({
        'targetEmail': studentEmail,
        'title': '📢 Your Case Has Been Updated',
        'body':
        'Dear ${newData['studentName']}, Your case has been updated by the administrator.\nCase Title: $caseTitle\nYour Student ID: $studentId\nChanges Made:\n$changesText\nPlease review the updated information in your case details.',
        'caseId': widget.caseDoc.id,
        'type': 'case_updated',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 3️⃣ Notify Assigned Investigators
    for (var invEmail in investigatorEmails) {
      await notifications.add({
        'targetEmail': invEmail,
        'title': '📢Case Updated by Admin',
        'body':
        'Case Title: $caseTitle\nStudent ID: $studentId\nChanges Made:\n$changesText\nPlease review the updated details.',
        'caseId': widget.caseDoc.id,
        'type': 'case_updated',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // -------------------------------------------------------

    setState(() {
      isEditing = false;
      evidenceDeleted = false; // Reset deletion flag
      newEvidenceFile = null; // Reset new evidence file
      // Update current evidence paths if replaced
      if (finalEvidencePath != null) {
        currentEvidenceLocalPath = finalEvidencePath;
        currentEvidenceUrl = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Case updated successfully!'),
        backgroundColor: Colors.indigo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.caseDoc.data() as Map<String, dynamic>;
    final createdAt = data['createdAt'] as Timestamp?;
    final incidentDate = data['incidentDate'];
    final reporterName = data['reporterName'] ?? 'Unknown Reporter';
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

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

    // Use state variables if evidence was deleted, otherwise use data from Firestore
    final localEvidencePath = evidenceDeleted 
        ? '' 
        : (currentEvidenceLocalPath ?? data['evidenceLocalPath'] ?? '');
    final firebaseUrl = evidenceDeleted 
        ? '' 
        : (currentEvidenceUrl ?? data['evidenceUrl'] ?? '');
    final hasLocalFile = localEvidencePath.toString().isNotEmpty;
    final hasFirebaseUrl = firebaseUrl.toString().isNotEmpty;

    final investigators =
    List<String>.from(data['assignedInvestigators'] ?? []);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF5F7FA), // Light gray-blue background for professional look
      appBar: AppBar(
        title: Text(
          data['caseTitle'] ?? 'Case Details',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.cancel : Icons.edit),
            tooltip: isEditing ? 'Cancel Editing' : 'Edit Case',
            onPressed: () => setState(() => isEditing = !isEditing),
          ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Delete Case',
              onPressed: _confirmDelete,
            ),
          const SizedBox(width: 4),
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
                // Suspension/Expulsion File Upload Section
                if (status == 'Suspension' || status == 'Expulsion') ...[
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
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
                            if (suspensionExpulsionFilePath != null ||
                                suspensionExpulsionFile != null)
                              _buildSuspensionExpulsionFileSection(),
                            if (isEditing)
                              ElevatedButton.icon(
                                onPressed: _pickSuspensionExpulsionFile,
                                icon: const Icon(Icons.upload_file, size: 18),
                                label: Text(
                                  suspensionExpulsionFilePath != null ||
                                          suspensionExpulsionFile != null
                                      ? 'Replace $status File'
                                      : 'Upload $status Letter/File',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
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
            if (hasLocalFile || hasFirebaseUrl || newEvidenceFile != null)
              _buildSectionCard(
                title: 'Evidence File',
                icon: Icons.attach_file,
                children: [
                  _buildEvidenceSection(
                    newEvidenceFile != null 
                        ? (newEvidenceFile!.path ?? '') 
                        : localEvidencePath, 
                    newEvidenceFile != null ? '' : firebaseUrl
                  ),
                  if (isEditing)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ElevatedButton.icon(
                        onPressed: _pickEvidenceFile,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: Text(
                          newEvidenceFile != null || hasLocalFile || hasFirebaseUrl
                              ? 'Replace Evidence File'
                              : 'Upload Evidence File',
                          style: const TextStyle(fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),

            if (hasLocalFile || hasFirebaseUrl || newEvidenceFile != null) const SizedBox(height: 16),

            // Assigned Investigators Card
            _buildSectionCard(
              title: 'Assigned Investigators',
              icon: Icons.people,
              children: [
                ..._buildInvestigatorList(),
                if (isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          investigatorCtrls.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('Add Investigator'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.indigo,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),
            
            // Save Button
            if (isEditing)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _updateCase,
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
  }

  List<Widget> _buildInvestigatorList() {
    if (investigatorCtrls.isEmpty) {
      return [
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
        ),
      ];
    }

    return List.generate(investigatorCtrls.length, (i) {
      final email = investigatorCtrls[i].text.trim();
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isEditing ? Colors.white : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isEditing ? Colors.indigo.shade300 : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: isEditing
              ? TextField(
                  controller: investigatorCtrls[i],
                  enabled: true,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Investigator Email ${i + 1}',
                    labelStyle: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: Icon(Icons.mail_outline,
                        color: Colors.indigo.shade600, size: 20),
                    suffixIcon: investigatorCtrls.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.redAccent, size: 22),
                            onPressed: () {
                              setState(() {
                                investigatorCtrls.removeAt(i);
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                )
              : InkWell(
                  onTap: email.isNotEmpty ? () => _openEmail(email) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                'Investigator ${i + 1}',
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
        ),
      );
    });
  }

  Future<void> _deleteSuspensionExpulsionFile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete File?'),
        content: const Text(
          'Are you sure you want to remove this suspension/expulsion file?',
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
      setState(() {
        suspensionExpulsionFile = null;
        suspensionExpulsionFilePath = null;
      });
      // Update Firestore to remove the file path
      await widget.caseDoc.reference.update({
        'suspensionExpulsionFilePath': FieldValue.delete(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File removed successfully'),
          backgroundColor: Colors.indigo,
        ),
      );
    }
  }

  Widget _buildSuspensionExpulsionFileSection() {
    final filePath = suspensionExpulsionFile?.path ??
        suspensionExpulsionFilePath ??
        '';
    final fileName = suspensionExpulsionFile?.name ??
        (filePath.isNotEmpty ? File(filePath).path.split('/').last : 'File');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.description, color: Colors.orange.shade700, size: 28),
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
                    color: Colors.orange.shade900,
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
          IconButton(
            icon: Icon(Icons.open_in_new, color: Colors.orange.shade700),
            onPressed: () => _openSuspensionExpulsionFile(filePath),
            tooltip: 'Open file',
          ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _deleteSuspensionExpulsionFile,
              tooltip: 'Delete file',
            ),
        ],
      ),
    );
  }

  Future<void> _deleteEvidenceFile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Evidence File?'),
        content: const Text(
          'Are you sure you want to remove this evidence file? This action cannot be undone.',
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
      setState(() {
        evidenceDeleted = true;
        currentEvidenceLocalPath = null;
        currentEvidenceUrl = null;
      });
      // Update Firestore to remove the evidence file paths
      await widget.caseDoc.reference.update({
        'evidenceLocalPath': FieldValue.delete(),
        'evidenceUrl': FieldValue.delete(),
      });
      // Update originalData to reflect the deletion
      originalData.remove('evidenceLocalPath');
      originalData.remove('evidenceUrl');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidence file removed successfully'),
            backgroundColor: Colors.indigo,
          ),
        );
      }
    }
  }

  Widget _buildEvidenceSection(String localPath, String firebaseUrl) {
    // If new evidence file is selected, use it for display
    final displayPath = newEvidenceFile != null 
        ? (newEvidenceFile!.path ?? '') 
        : localPath;
    final isLocal = displayPath.toString().isNotEmpty || localPath.toString().isNotEmpty;
    final displayName = newEvidenceFile != null
        ? newEvidenceFile!.name
        : (isLocal && localPath.toString().isNotEmpty
            ? File(localPath).path.split('/').last
            : (firebaseUrl.toString().isNotEmpty
                ? Uri.parse(firebaseUrl).pathSegments.last
                : 'Evidence File'));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
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
            child: const Icon(Icons.file_present,
                color: Colors.indigo, size: 24),
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
            onPressed: () {
              if (newEvidenceFile != null && newEvidenceFile!.path != null) {
                _openEvidence(newEvidenceFile!.path!);
              } else {
                _openEvidence(isLocal ? localPath : firebaseUrl);
              }
            },
            tooltip: 'Open file',
          ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _deleteEvidenceFile,
              tooltip: 'Delete file',
            ),
        ],
      ),
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
              isDark 
                  ? Theme.of(context).cardColor 
                  : Colors.white,
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
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
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
                      Icon(Icons.open_in_new,
                          color: Colors.blue.shade600, size: 18),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusDropdown() {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    
    return Container(
      decoration: BoxDecoration(
        color: isEditing ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEditing ? Colors.indigo.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: status,
        items: const [
          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
          DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
          DropdownMenuItem(
              value: 'Under Investigation',
              child: Text('Under Investigation')),
          DropdownMenuItem(value: 'Suspension', child: Text('Suspension')),
          DropdownMenuItem(value: 'Expulsion', child: Text('Expulsion')),
        ],
        onChanged: isEditing
            ? (v) {
                setState(() {
                  status = v!;
                  if (v != 'Suspension' && v != 'Expulsion') {
                    suspensionExpulsionFile = null;
                  }
                });
              }
            : null,
        decoration: InputDecoration(
          labelText: 'Case Status',
          labelStyle: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(Icons.flag, color: Colors.indigo.shade600, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: false,
        ),
        style: TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

