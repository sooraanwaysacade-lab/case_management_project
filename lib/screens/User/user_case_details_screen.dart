import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';

class UserCaseDetailsScreen extends StatelessWidget {
  final DocumentSnapshot caseDoc;
  const UserCaseDetailsScreen({super.key, required this.caseDoc});

  Future<void> _openEvidence(String filePathOrUrl, bool isLocal) async {
    try {
      if (isLocal) {
        final f = File(filePathOrUrl);
        if (await f.exists()) {
          await OpenFilex.open(filePathOrUrl);
        } else {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(_scaffoldContext!).showSnackBar(
            SnackBar(content: Text("Local file not found: $filePathOrUrl")),
          );
        }
      } else {
        if (filePathOrUrl.trim().isEmpty) return;
        final uri = Uri.parse(filePathOrUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(_scaffoldContext!).showSnackBar(
            const SnackBar(content: Text("❌ Could not open link.")),
          );
        }
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(_scaffoldContext!).showSnackBar(
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
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(_scaffoldContext!).showSnackBar(
              SnackBar(
                content: Text('⚠️ Unable to open file: ${result.message}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(_scaffoldContext!).showSnackBar(
            const SnackBar(
              content: Text("⚠️ File not found on device."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(_scaffoldContext!).showSnackBar(
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
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(_scaffoldContext!).showSnackBar(
        SnackBar(
          content: Text("❌ Couldn't open email app: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  static BuildContext? _scaffoldContext;

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
    final data = caseDoc.data() as Map<String, dynamic>;
    final createdAt = data['createdAt'] as Timestamp?;
    final incidentDate = data['incidentDate'];

    final evidenceUrl = data['evidenceUrl'] ?? '';
    final evidenceLocalPath = data['evidenceLocalPath'] ?? '';
    final hasLocalFile = evidenceLocalPath.toString().isNotEmpty;
    final hasFirebaseUrl = evidenceUrl.toString().isNotEmpty;

    final investigators =
        List<String>.from(data['assignedInvestigators'] ?? []);

    String formattedDate = createdAt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt.toDate())
        : 'Unknown Date';

    String formattedIncident = '';
    if (incidentDate != null) {
      try {
        final parsed = DateTime.parse(incidentDate);
        formattedIncident =
            DateFormat('MMM d, yyyy • h:mm a').format(parsed);
      } catch (_) {}
    }

    final status = (data['status'] ?? 'Pending').toString();
    final statusColor = _getStatusColor(status);

    final bool hasSuspensionFile =
        (status == 'Suspension' || status == 'Expulsion') &&
            data['suspensionExpulsionFilePath'] != null &&
            data['suspensionExpulsionFilePath'].toString().isNotEmpty;

    final bgColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).scaffoldBackgroundColor
        : const Color(0xFFF5F7FA);

    return Builder(
      builder: (ctx) {
        _scaffoldContext = ctx;
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(
              (data['caseTitle'] ?? 'Case Details').toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.indigo,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Information Card
                _buildSectionCard(
                  context: ctx,
                  title: 'Student Information',
                  icon: Icons.school,
                  children: [
                    _buildInfoRow(
                      ctx,
                      icon: Icons.badge,
                      label: 'Student ID',
                      value: data['studentId'] ?? 'N/A',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      ctx,
                      icon: Icons.person,
                      label: 'Student Name',
                      value: data['studentName'] ?? 'N/A',
                    ),
                    const SizedBox(height: 12),
                    _buildEmailRow(
                      ctx,
                      label: 'Student Email',
                      email: (data['email'] ?? '').toString(),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      ctx,
                      icon: Icons.phone,
                      label: 'Phone Number',
                      value: data['phone']?.toString().isNotEmpty == true
                          ? data['phone']
                          : 'N/A',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Case Information Card
                _buildSectionCard(
                  context: ctx,
                  title: 'Case Information',
                  icon: Icons.folder,
                  children: [
                    _buildInfoRow(
                      ctx,
                      icon: Icons.title,
                      label: 'Case Title',
                      value: data['caseTitle'] ?? 'Untitled Case',
                    ),
                    const SizedBox(height: 12),
                    // Only show description if it exists
                    if (data['caseDescription']?.toString().isNotEmpty == true)
                      _buildInfoRow(
                        ctx,
                        icon: Icons.description,
                        label: 'Case Description',
                        value: data['caseDescription'],
                      )
                    else
                      // Show just the label when no description
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.description, size: 20, color: Colors.indigo.shade600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Case Description',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    // Status label on one line, badge immediately underneath,
                    // using tighter spacing than the default info row gap.
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.flag,
                              size: 20, color: Colors.indigo.shade600),
                          const SizedBox(width: 12),
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag,
                              size: 16,
                              color: statusColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Incident Information Card (no reporter name)
                _buildSectionCard(
                  context: ctx,
                  title: 'Incident Information',
                  icon: Icons.event_note,
                  children: [
                    _buildInfoRow(
                      ctx,
                      icon: Icons.calendar_month,
                      label: 'Reported On',
                      value: formattedDate,
                    ),
                    if (formattedIncident.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        ctx,
                        icon: Icons.event,
                        label: 'Incident Date',
                        value: formattedIncident,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // (Meeting link / hearing note removed as per requirements)

                // Evidence File Card
                if (hasLocalFile || hasFirebaseUrl)
                  _buildSectionCard(
                    context: ctx,
                    title: 'Evidence File',
                    icon: Icons.attach_file,
                    children: [
                      _buildEvidenceSection(
                        ctx,
                        evidenceLocalPath,
                        evidenceUrl,
                      ),
                    ],
                  ),

                if (hasLocalFile || hasFirebaseUrl)
                  const SizedBox(height: 16),

                // Suspension / Expulsion Letter Card
                if (hasSuspensionFile)
                  _buildSectionCard(
                    context: ctx,
                    title: '${status} Letter',
                    icon: Icons.gavel_outlined,
                    children: [
                      _buildSuspensionExpulsionFileCard(
                        ctx,
                        data['suspensionExpulsionFilePath'].toString(),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Assigned Investigators (read-only)
                if (investigators.isNotEmpty)
                  _buildSectionCard(
                    context: ctx,
                    title: 'Assigned Investigators',
                    icon: Icons.people,
                    children: investigators.map((email) {
                      final trimmed = email.toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: trimmed.isNotEmpty
                              ? () => _openEmail(trimmed)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        trimmed.isNotEmpty
                                            ? trimmed
                                            : 'No email',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: trimmed.isNotEmpty
                                              ? Colors.blue.shade700
                                              : Colors.grey.shade600,
                                          decoration: trimmed.isNotEmpty
                                              ? TextDecoration.underline
                                              : TextDecoration.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (trimmed.isNotEmpty)
                                  Icon(Icons.open_in_new,
                                      color: Colors.blue.shade600, size: 18),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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
    required BuildContext context,
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
                    child:
                        Icon(icon, color: Colors.indigo.shade700, size: 22),
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

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
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

  Widget _buildEmailRow(
    BuildContext context, {
    required String label,
    required String email,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trimmed = email.trim();
    return InkWell(
      onTap: trimmed.isNotEmpty ? () => _openEmail(trimmed) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.email, color: Colors.blue.shade600, size: 20),
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
                    trimmed.isNotEmpty ? trimmed : 'No email',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: trimmed.isNotEmpty
                          ? Colors.blue.shade700
                          : (isDark ? Colors.grey[400] : Colors.grey.shade600),
                      decoration: trimmed.isNotEmpty
                          ? TextDecoration.underline
                          : TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            if (trimmed.isNotEmpty)
              Icon(Icons.open_in_new, color: Colors.blue.shade600, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceSection(
    BuildContext context,
    String localPath,
    String firebaseUrl,
  ) {
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
            icon: Icon(Icons.open_in_new,
                color: Colors.indigo.shade600, size: 20),
            onPressed: () => _openEvidence(displayPath, isLocal),
            tooltip: 'Open file',
          ),
        ],
      ),
    );
  }

  Widget _buildSuspensionExpulsionFileCard(
      BuildContext context, String filePath) {
    final fileName =
        filePath.isNotEmpty ? File(filePath).path.split('/').last : 'File';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.orange.shade50,
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
                    color: isDark
                        ? Colors.orange.shade200
                        : Colors.orange.shade900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap the icon to open your letter',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark ? Colors.grey[300] : Colors.grey.shade600,
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
        ],
      ),
    );
  }
}


