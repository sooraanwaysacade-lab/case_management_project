import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../helpers/local_database_helper.dart';
import '../../helpers/file_utils.dart';

class UserAppealScreen extends StatefulWidget {
  const UserAppealScreen({super.key});

  @override
  State<UserAppealScreen> createState() => _UserAppealScreenState();
}

class _UserAppealScreenState extends State<UserAppealScreen> {
  PlatformFile? pickedFile;
  bool isLoading = false;
  String? selectedCaseId;
  List<DocumentSnapshot> userCases = [];
  bool loadingCases = true;

  @override
  void initState() {
    super.initState();
    _loadUserCases();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUserCases() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => loadingCases = false);
      return;
    }

    try {
      final cases = await FirebaseFirestore.instance
          .collection('cases')
          .where('email', isEqualTo: user.email)
          .get();

      setState(() {
        userCases = cases.docs;
        loadingCases = false;
        if (userCases.isNotEmpty) {
          selectedCaseId = userCases.first.id;
        }
      });
    } catch (e) {
      debugPrint("❌ Error loading cases: $e");
      setState(() => loadingCases = false);
    }
  }

  // Pick document
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['pdf', 'doc', 'docx'],
      type: FileType.custom,
    );
    if (result != null) {
      setState(() => pickedFile = result.files.single);
    }
  }

  // Save file to local storage
  Future<String> _saveFileLocally(PlatformFile file) async {
    try {
      String localPath;
      
      if (file.bytes != null) {
        // Save from bytes
        localPath = await saveFileToAppDir(
          bytes: file.bytes!,
          originalName: file.name,
        );
      } else if (file.path != null) {
        // Copy from existing file path
        localPath = await copyFileToAppDir(File(file.path!));
      } else {
        throw Exception("Invalid file path or data.");
      }

      return localPath;
    } catch (e) {
      debugPrint("❌ Error saving file locally: $e");
      rethrow;
    }
  }

  // SUBMIT APPEAL - Uses only local storage (SQLite)
  Future<void> _submitAppeal() async {
    if (selectedCaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Please select a case to appeal."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Please attach a file to submit your appeal."),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    final studentEmail = user?.email ?? "Unknown";
    final createdAt = DateTime.now();
    final createdAtString = createdAt.toIso8601String();

    String localFilePath = "";

    try {
      // Save file to local storage if provided
      if (pickedFile != null) {
        localFilePath = await _saveFileLocally(pickedFile!);
      }

      // Get case details for appeal
      final caseDoc = await FirebaseFirestore.instance
          .collection('cases')
          .doc(selectedCaseId)
          .get();
      final caseData = caseDoc.data() as Map<String, dynamic>?;
      final caseTitle = caseData?['caseTitle'] ?? 'Unknown';
      final caseStudentId = caseData?['studentId'] ?? 'Unknown ID';

      // Save appeal metadata to Firestore with caseId link
      final appealDoc = await FirebaseFirestore.instance.collection("appeals").add({
        "caseId": selectedCaseId,
        "email": studentEmail,
        "studentId": caseStudentId,
        "studentName": caseData?['studentName'] ?? studentEmail,
        "localFilePath": localFilePath, // ✅ Only local path, no Firebase Storage URL
        "status": "Pending",
        "createdAt": FieldValue.serverTimestamp(),
      });

      // Save to local SQLite database using LocalDatabaseHelper
      await LocalDatabaseHelper.instance.insertAppeal({
        'caseId': selectedCaseId,
        'studentId': caseStudentId,
        'studentName': caseData?['studentName'] ?? studentEmail,
        'reason': 'Appeal file submitted',
        'filePath': localFilePath,
        'createdAt': createdAtString,
        'isSynced': 1, // Mark as synced since we saved to Firestore
      });

      // Notify admin
      await FirebaseFirestore.instance.collection("notifications").add({
        "targetEmail": "admin@system",
        "title": "New Appeal Submitted",
        "body":
            "$studentEmail submitted a new appeal for case: \"$caseTitle\" with Student ID $caseStudentId.",
        "caseId": selectedCaseId,
        "appealId": appealDoc.id,
        "isRead": false,
        "createdAt": FieldValue.serverTimestamp(),
        "type": "appeal_submitted",
      });

      // Notify assigned lecturers if any
      final assignedInvestigators = caseData?['assignedInvestigators'] as List<dynamic>?;
      if (assignedInvestigators != null && assignedInvestigators.isNotEmpty) {
        for (var lecturerEmail in assignedInvestigators) {
          await FirebaseFirestore.instance.collection("notifications").add({
            "targetEmail": lecturerEmail.toString(),
            "title": "New Appeal Submitted",
            "body":
                "$studentEmail submitted an appeal for case \"$caseTitle\" with Student ID $caseStudentId.",
            "caseId": selectedCaseId,
            "appealId": appealDoc.id,
            "isRead": false,
            "createdAt": FieldValue.serverTimestamp(),
            "type": "appeal_submitted",
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Appeal submitted successfully and saved locally."),
            backgroundColor: Colors.indigo,
          ),
        );
      }

      setState(() => pickedFile = null);
    } catch (e) {
      debugPrint("❌ Error submitting appeal: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).cardColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.35)
                  : Colors.grey.shade300,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.campaign,
                    color: Colors.indigo.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Submit Appeal",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.indigo.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Choose your case and attach an appeal document.",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey[300]
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Case selection dropdown
            if (loadingCases)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.indigo),
                ),
              )
            else if (userCases.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  "⚠️ You don't have any cases to appeal. Please wait for a case to be reported against you.",
                  style: TextStyle(color: Colors.orange),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: selectedCaseId,
                decoration: InputDecoration(
                  labelText: "Select Case to Appeal",
                  labelStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey.shade700,
                  ),
                  prefixIcon:
                      const Icon(Icons.folder_copy, color: Colors.indigo),
                  filled: true,
                  fillColor:
                      isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.indigo.shade200,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.indigo.shade600,
                      width: 1.8,
                    ),
                  ),
                ),
                items: userCases.map((caseDoc) {
                  final caseData = caseDoc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                    value: caseDoc.id,
                    child: Text(
                      caseData['caseTitle'] ?? 'Untitled Case',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedCaseId = value),
              ),
            const SizedBox(height: 20),

            pickedFile == null
                ? OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: const Text("Attach Document (Optional)"),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.indigo.shade400),
                      foregroundColor:
                          isDark ? Colors.indigo.shade200 : Colors.indigo,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.indigo.shade900.withOpacity(0.25)
                          : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.description, color: Colors.indigo),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pickedFile!.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white
                                  : Colors.indigo.shade900,
                            ),
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () =>
                              setState(() => pickedFile = null),
                        )
                      ],
                    ),
                  ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: isLoading ? null : _submitAppeal,
              icon: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              label: Text(
                isLoading ? "Submitting..." : "Submit Appeal",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
