import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../helpers/local_database_helper.dart';
import '../helpers/file_utils.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();

  final reporterName = TextEditingController();
  final studentId = TextEditingController();
  final studentName = TextEditingController();
  final studentEmail = TextEditingController();
  final phone = TextEditingController();
  final caseTitle = TextEditingController();
  final caseDescription = TextEditingController();

  PlatformFile? pickedFile;
  DateTime? incidentDate;
  bool isLoading = false;

  // ✅ Pick evidence file and save locally
  Future<void> _pickEvidence() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'docx'],
        withData: true,
      );

      if (result != null && result.files.single != null) {
        final file = result.files.single;
        String localPath;

        // Save to app directory
        if (file.bytes != null) {
          localPath = await saveFileToAppDir(bytes: file.bytes!, originalName: file.name);
        } else if (file.path != null) {
          localPath = await copyFileToAppDir(File(file.path!));
        } else {
          throw Exception("Invalid file path or data.");
        }

        // Insert record in local SQLite evidences table
        await LocalDatabaseHelper.instance.insertEvidence({
          'caseId': '', // will link after case creation
          'originalName': file.name,
          'localPath': localPath,
          'mimeType': p.extension(file.name).replaceAll('.', ''),
          'createdAt': DateTime.now().toIso8601String(),
          'isSynced': 0,
        });

        setState(() => pickedFile = file);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📂 Evidence saved locally at: ${p.basename(localPath)}'),
            backgroundColor: Colors.indigo,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ No file selected.")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error picking file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed to pick file: $e")),
      );
    }
  }

  // ✅ Date & Time picker
  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          incidentDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      } else {
        setState(() => incidentDate = date);
      }
    }
  }

  // ✅ Submit report (save case to Firestore only)
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      // Evidence local file path (if selected)
      String? localEvidencePath;
      if (pickedFile != null) {
        final evidences = await LocalDatabaseHelper.instance.getAllEvidences();
        final match = evidences.firstWhere(
              (e) => e['originalName'] == pickedFile!.name,
          orElse: () => {},
        );
        localEvidencePath = match['localPath'] ?? '';
      }

      // Save the case to Firestore (metadata only)
      final newCase = await FirebaseFirestore.instance.collection('cases').add({
        'reporterName': reporterName.text.trim(),
        'studentId': studentId.text.trim(),
        'studentName': studentName.text.trim(),
        'targetEmail': studentEmail.text.trim(),
        'email': studentEmail.text.trim(),
        'phone': phone.text.trim(),
        'caseTitle': caseTitle.text.trim(),
        'caseDescription': caseDescription.text.trim(),
        'incidentDate': incidentDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'status': 'Pending',
        'evidenceLocalPath': localEvidencePath ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update the local evidence record to link caseId
      if (pickedFile != null && localEvidencePath != null) {
        final evidences = await LocalDatabaseHelper.instance.getAllEvidences();
        for (var e in evidences) {
          if (e['localPath'] == localEvidencePath) {
            await LocalDatabaseHelper.instance.markEvidenceSynced(e['id']);
          }
        }
      }

      // Notify admin
      await FirebaseFirestore.instance.collection('notifications').add({
        'targetEmail': 'admin@system',
        'title': 'New Case Reported',
        'body':
        'A new case titled "${caseTitle.text.trim()}" has been reported for "${studentId.text.trim()}" by Admin ${reporterName.text.trim()}.',
        'caseId': newCase.id,
        'type': 'case_created',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Notify student
      await FirebaseFirestore.instance.collection('notifications').add({
        'targetEmail': studentEmail.text.trim(),
        'title': '📢You Have Been Reported',
        'body':
        'You have been reported for the case "${caseTitle.text.trim()}" by Admin ${reporterName.text.trim()}. Please review it in your account.',
        'caseId': newCase.id,
        'type': 'user_case_alert',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Case reported successfully! Notifications sent.'),
          backgroundColor: Colors.indigo,
        ),
      );

      reporterName.clear();
      studentId.clear();
      studentName.clear();
      studentEmail.clear();
      phone.clear();
      caseTitle.clear();
      caseDescription.clear();

      setState(() {
        incidentDate = null;
        pickedFile = null;
      });
    } catch (e) {
      debugPrint('❌ Error submitting case: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to submit report: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ✅ Input field builder with enhanced styling
  Widget _inputField(TextEditingController controller, String label,
      {int maxLines = 1, bool required = true, IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: required ? (v) => v == null || v.isEmpty ? 'Required field' : null : null,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[400] : Colors.grey.shade600,
        ),
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.indigo.shade600, size: 22)
            : null,
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.indigo.shade900.withOpacity(0.3) : Colors.indigo.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.indigo.shade700, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.indigo.shade900,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark 
          ? Theme.of(context).scaffoldBackgroundColor 
          : const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Reporter Information Section
              _buildSectionCard(
                title: 'Reporter Information',
                icon: Icons.person_outline,
                children: [
                  _inputField(reporterName, 'Your Name (Admin)', icon: Icons.person),
                ],
              ),

              // Student Information Section
              _buildSectionCard(
                title: 'Student Information',
                icon: Icons.school_outlined,
                children: [
                  _inputField(studentId, 'Student ID', icon: Icons.badge),
                  const SizedBox(height: 12),
                  _inputField(studentName, 'Student Name', icon: Icons.person_outline),
                  const SizedBox(height: 12),
                  _inputField(studentEmail, 'Student Email', icon: Icons.email, required: true),
                  const SizedBox(height: 12),
                  _inputField(phone, 'Phone (optional)', required: false, icon: Icons.phone),
                ],
              ),

              // Case Information Section
              _buildSectionCard(
                title: 'Case Information',
                icon: Icons.description_outlined,
                children: [
                  _inputField(caseTitle, 'Case Title', icon: Icons.title),
                  const SizedBox(height: 12),
                  _inputField(caseDescription, 'Case Description (optional)',
                      required: false, maxLines: 4, icon: Icons.description),
                  const SizedBox(height: 16),
                  // Incident Date & Time
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.blue.shade700 : Colors.blue.shade200, 
                        width: 1.5,
                      ),
                    ),
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Incident Date & Time',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  incidentDate == null
                                      ? 'Select Date & Time'
                                      : '${incidentDate!.toLocal()}'
                                          .split('.')[0]
                                          .replaceFirst(' ', ' • '),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: incidentDate == null
                                        ? (isDark ? Colors.grey[500] : Colors.grey.shade500)
                                        : (isDark ? Colors.blue.shade300 : Colors.blue.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue.shade300),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Evidence File Upload
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.indigo.shade900.withOpacity(0.3) : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.indigo.shade700 : Colors.indigo.shade200, 
                        width: 1.5,
                      ),
                    ),
                    child: pickedFile == null
                        ? InkWell(
                            onTap: _pickEvidence,
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.upload_file, color: Colors.indigo, size: 20),
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
                                          color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to upload evidence (PDF, DOC, DOCX, JPG, PNG)',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: isDark ? Colors.indigo.shade300 : Colors.indigo.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.indigo.shade300),
                              ],
                            ),
                          )
                        : Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.attach_file, color: Colors.indigo, size: 20),
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
                                        color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      pickedFile!.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.indigo.shade300 : Colors.indigo.shade700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.redAccent),
                                onPressed: () => setState(() => pickedFile = null),
                                tooltip: 'Remove file',
                              ),
                            ],
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Submit Button
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 20),
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _submitReport,
                  icon: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 22),
                  label: Text(
                    isLoading ? "Submitting..." : "Submit Report",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    shadowColor: Colors.indigo.shade300,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
