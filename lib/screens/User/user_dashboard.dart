import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_home_screen.dart';
import 'my_cases_screen.dart';
import 'user_appeal_screen.dart';
import 'user_notifications_screen.dart';
import 'user_drawer.dart';

// Auth screen for logout redirection
import '../login_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    UserHomeScreen(),
    MyCasesScreen(),
    UserAppealScreen(),
    UserNotificationsScreen(),
  ];

  final List<String> _titles = const [
    'Dashboard',
    'My Cases',
    'Appeal',
    'Notifications',
  ];

  @override
  Widget build(BuildContext context) {
    if (user == null) return const LoginScreen();

    final userEmail = user!.email ?? "Unknown Email";
    final userName = (user!.displayName != null &&
        user!.displayName!.trim().isNotEmpty)
        ? user!.displayName!
        : userEmail.split('@').first;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        centerTitle: true,
        actions: _currentIndex == 3
            ? [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    if (value == 'mark_all') {
                      await _markAllNotificationsAsRead(userEmail);
                    } else if (value == 'clear_all') {
                      await _clearAllNotifications(userEmail);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'mark_all',
                      child: Row(
                        children: [
                          Icon(Icons.done_all, color: Colors.indigo),
                          SizedBox(width: 8),
                          Text("Mark all as read"),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text("Clear all"),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : null,
      ),

      drawer: const UserDrawer(),

      body: _screens[_currentIndex],

      // ✅ Bottom Navigation Bar with Badge Count
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('targetEmail', isEqualTo: userEmail)
            .where('isRead', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data?.docs.length ?? 0;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                  spreadRadius: 0,
                ),
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _currentIndex,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: Colors.indigo,
                unselectedItemColor: isDark ? Colors.grey[600] : Colors.grey.shade500,
                selectedFontSize: 12,
                unselectedFontSize: 11,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
                onTap: (index) => setState(() => _currentIndex = index),
                items: [
                  _buildUserNavItem(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard,
                    label: 'Dashboard',
                    isSelected: _currentIndex == 0,
                    isDark: isDark,
                  ),
                  _buildUserNavItem(
                    icon: Icons.folder_outlined,
                    activeIcon: Icons.folder,
                    label: 'My Cases',
                    isSelected: _currentIndex == 1,
                    isDark: isDark,
                  ),
                  _buildUserNavItem(
                    icon: Icons.campaign_outlined,
                    activeIcon: Icons.campaign,
                    label: 'Appeal',
                    isSelected: _currentIndex == 2,
                    isDark: isDark,
                  ),
                  _buildUserNavItem(
                    icon: Icons.notifications_outlined,
                    activeIcon: Icons.notifications,
                    label: 'Notifications',
                    isSelected: _currentIndex == 3,
                    isDark: isDark,
                    badgeCount: unreadCount,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _markAllNotificationsAsRead(String userEmail) async {
    final query = await FirebaseFirestore.instance
        .collection('notifications')
        .where('targetEmail', isEqualTo: userEmail)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in query.docs) {
      await doc.reference.update({'isRead': true});
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All notifications marked as read")),
      );
    }
  }

  Future<void> _clearAllNotifications(String userEmail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        titleTextStyle: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
        title: const Text("Clear All Notifications"),
        content: const Text(
            "Are you sure you want to permanently delete all notifications?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear All"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final query = await FirebaseFirestore.instance
          .collection('notifications')
          .where('targetEmail', isEqualTo: userEmail)
          .get();

      for (var doc in query.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All notifications cleared")),
        );
      }
    }
  }

  BottomNavigationBarItem _buildUserNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required bool isDark,
    int badgeCount = 0,
  }) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.indigo.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                size: isSelected ? 26 : 24,
                color: isSelected
                    ? Colors.indigo
                    : (badgeCount > 0 && label == 'Notifications'
                        ? Colors.orange.shade400
                        : null),
              ),
            ),
            // Badge for Notifications
            if (badgeCount > 0 && label == 'Notifications')
              Positioned(
                right: -8,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      activeIcon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.indigo.withOpacity(0.15),
              Colors.indigo.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.indigo.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              activeIcon,
              size: 26,
              color: Colors.indigo,
            ),
            if (badgeCount > 0 && label == 'Notifications')
              Positioned(
                right: -8,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      label: label,
    );
  }
}
