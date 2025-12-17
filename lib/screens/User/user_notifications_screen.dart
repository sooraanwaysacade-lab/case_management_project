import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserNotificationsScreen extends StatefulWidget {
  final Function(int, bool)? onUnreadStatusChanged;

  const UserNotificationsScreen({super.key, this.onUnreadStatusChanged});

  @override
  State<UserNotificationsScreen> createState() =>
      _UserNotificationsScreenState();
}

class _UserNotificationsScreenState extends State<UserNotificationsScreen> {
  String? userEmail;
  bool isLoading = true;

  CollectionReference get _notificationsRef =>
      FirebaseFirestore.instance.collection('notifications');

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      userEmail = user?.email;
      isLoading = false;
    });
  }

  Stream<QuerySnapshot> _notifications() {
    if (userEmail == null || userEmail!.isEmpty) {
      return const Stream.empty();
    }
    try {
      return _notificationsRef
          .where('targetEmail', isEqualTo: userEmail)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } catch (e) {
      debugPrint("⚠️ Firestore query error (user notifications): $e");
      return const Stream.empty();
    }
  }

  Future<void> _deleteNotification(String id) async {
    await _notificationsRef.doc(id).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Notification deleted')),
      );
    }
  }

  Future<bool?> _confirmDeleteNotification(String id) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        titleTextStyle: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        contentTextStyle: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
        title: const Text('Delete Notification'),
        content: const Text('Are you sure to delete this message?'),
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
  }

  void _notifyUnreadCount(List<QueryDocumentSnapshot> docs) {
    if (widget.onUnreadStatusChanged == null) return;
    final unreadCount =
        docs.where((d) => (d.data() as Map<String, dynamic>)['isRead'] != true)
            .length;
    widget.onUnreadStatusChanged!.call(
      unreadCount,
      unreadCount > 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.indigo),
      );
    }

    if (userEmail == null || userEmail!.isEmpty) {
      return Center(
        child: Text(
          'Unable to load your notifications.',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.grey[300] : Colors.grey.shade700,
          ),
        ),
      );
    }

    return Container(
      color: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF5F7FA),
      child: StreamBuilder<QuerySnapshot>(
        stream: _notifications(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.indigo),
            );
          }

          if (snap.hasError) {
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
                    '⚠️ Error loading notifications',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snap.error}',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final docs = snap.data?.docs ?? [];
          _notifyUnreadCount(docs);

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 80,
                    color: isDark ? Colors.grey[600] : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You'll see updates about your cases here.",
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.grey[400] : Colors.grey.shade600,
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
              final doc = docs[i];
              final d = doc.data() as Map<String, dynamic>;
              final ts = d['createdAt'] as Timestamp?;
              final time = ts != null
                  ? DateFormat('MMM d, yyyy • h:mm a').format(ts.toDate())
                  : 'Just now';

              IconData icon;
              Color color;
              switch (d['type']) {
                case 'case_created':
                  icon = Icons.assignment_turned_in;
                  color = Colors.green;
                  break;
                case 'case_updated':
                  icon = Icons.edit;
                  color = Colors.blue;
                  break;
                case 'status_change':
                  icon = Icons.warning_amber_rounded;
                  color = Colors.orange;
                  break;
                case 'case_deleted':
                  icon = Icons.delete_forever;
                  color = Colors.redAccent;
                  break;
                case 'user_case_alert':
                  icon = Icons.report;
                  color = Colors.indigo;
                  break;
                case 'appeal_submitted':
                  icon = Icons.mail_outline;
                  color = Colors.orange;
                  break;
                case 'appeal_reviewed':
                  icon = Icons.fact_check_outlined;
                  color = Colors.green;
                  break;
                default:
                  icon = Icons.notifications_active;
                  color = Colors.indigo;
              }

              final isRead = d['isRead'] == true;

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  final confirm = await _confirmDeleteNotification(doc.id);
                  if (confirm == true) {
                    await _deleteNotification(doc.id);
                    return true;
                  }
                  return false;
                },
                background: Container(
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                child: Card(
                  elevation: isRead ? 1 : 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isRead
                          ? (isDark
                              ? Colors.grey[700]!
                              : Colors.grey.shade200)
                          : color.withOpacity(0.3),
                      width: isRead ? 1 : 2,
                    ),
                  ),
                  color: isRead
                      ? (isDark ? Theme.of(context).cardColor : Colors.white)
                      : (isDark
                          ? color.withOpacity(0.15)
                          : color.withOpacity(0.08)),
                  child: InkWell(
                    onTap: () async {
                      if (!isRead) {
                        await doc.reference.update({'isRead': true});
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon Container
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(isDark ? 0.25 : 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color: color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title Row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        d['title'] ?? 'Notification',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Body Text
                                Text(
                                  d['body'] ?? 'No details available.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87.withOpacity(0.8),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Time Row
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Delete Button
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: isDark
                                  ? Colors.red[300]
                                  : Colors.red.shade600,
                              size: 22,
                            ),
                            tooltip: "Delete notification",
                            onPressed: () async {
                              final confirm =
                                  await _confirmDeleteNotification(doc.id);
                              if (confirm == true) {
                                await _deleteNotification(doc.id);
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
