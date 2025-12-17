import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _notificationsRef =
  FirebaseFirestore.instance.collection('notifications');

  Stream<QuerySnapshot> _notifications() {
    try {
      return _notificationsRef
          .where('targetEmail', isEqualTo: 'admin@system')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } catch (e) {
      debugPrint("⚠️ Firestore query error: $e");
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

  Future<void> _deleteAllNotifications() async {
    final docs = await _notificationsRef
        .where('targetEmail', isEqualTo: 'admin@system')
        .get();
    for (var doc in docs.docs) {
      await doc.reference.delete();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🧹 All notifications cleared')),
    );
  }

  Future<void> _markAllAsRead() async {
    final unread = await _notificationsRef
        .where('targetEmail', isEqualTo: 'admin@system')
        .where('isRead', isEqualTo: false)
        .get();
    for (var doc in unread.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    /// 🟢 Important: No local Scaffold AppBar
    /// The main AppBar from main.dart will display "Alerts" and the 3-dot menu

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
                    'No alerts yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see notifications here when they arrive',
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
                  icon = Icons.add_alert_rounded;
                  color = Colors.green;
                  break;
                case 'case_updated':
                  icon = Icons.edit_note;
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
                          ? (isDark ? Colors.grey[700]! : Colors.grey.shade200)
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
                                        d['title'] ?? 'System Notification',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: isDark ? Colors.white : Colors.black87,
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
                              color: isDark ? Colors.red[300] : Colors.red.shade600,
                              size: 22,
                            ),
                            tooltip: "Delete notification",
                            onPressed: () async {
                              final confirm = await _confirmDeleteNotification(doc.id);
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
