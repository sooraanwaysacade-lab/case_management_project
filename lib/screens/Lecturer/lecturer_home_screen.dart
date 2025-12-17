import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LecturerHomeScreen extends StatelessWidget {
  const LecturerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final lecturerEmail = user?.email?.toLowerCase() ?? '';

    if (lecturerEmail.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Stream for assigned cases
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cases')
          .where('assignedInvestigators', arrayContains: lecturerEmail)
          .snapshots(),
      builder: (context, casesSnapshot) {
        if (!casesSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.indigo));
        }

        final cases = casesSnapshot.data!.docs;
        int totalCases = cases.length;
        int resolvedCases = cases.where((d) => d['status'] == 'Resolved').length;
        int pendingCases = cases.where((d) => d['status'] == 'Pending').length;
        int suspensionCases = cases.where((d) => d['status'] == 'Suspension').length;
        int expulsionCases = cases.where((d) => d['status'] == 'Expulsion').length;

        // Stream for appeals
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('appeals')
              .snapshots(),
          builder: (context, appealsSnapshot) {
            if (!appealsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.indigo));
            }

            // Get appeals related to lecturer's assigned cases
            final allAppeals = appealsSnapshot.data!.docs;
            final caseIds = cases.map((c) => c.id).toList();
            final relatedAppeals = allAppeals
                .where((a) {
                  final caseId = a.data() as Map<String, dynamic>;
                  return caseIds.contains(caseId['caseId']);
                })
                .toList();
            int appeals = relatedAppeals.length;

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
                    count: totalCases,
                    color: Colors.indigo,
                    icon: Icons.folder_copy,
                  ),
                  _card(
                    context,
                    title: 'Resolved',
                    count: resolvedCases,
                    color: Colors.green,
                    icon: Icons.verified,
                  ),
                  _card(
                    context,
                    title: 'Pending',
                    count: pendingCases,
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
                    count: suspensionCases,
                    color: Colors.purple,
                    icon: Icons.pause_circle,
                  ),
                  _card(
                    context,
                    title: 'Expulsion',
                    count: expulsionCases,
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
