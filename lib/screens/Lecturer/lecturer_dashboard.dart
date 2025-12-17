import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Screens (Lecturer section)
import 'lecturer_home_screen.dart';
import 'lecturer_assigned_cases_screen.dart';
import 'lecturer_appeals_screen.dart';
import 'lecturer_notifications_screen.dart';
import 'lecturer_report_screen.dart';
import 'lecturer_drawer.dart';

// Auth screen for logout redirection
import '../login_screen.dart';

class LecturerDashboard extends StatefulWidget {
  const LecturerDashboard({super.key});

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  bool isDarkMode = false;
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    LecturerHomeScreen(),
    LecturerAssignedCasesScreen(),
    LecturerReportScreen(),
    LecturerAppealsScreen(),
    LecturerNotificationsScreen(),
  ];

  final List<String> _titles = const [
    'Lecturer Dashboard',
    'Assigned Cases',
    'Report Case',
    'Appeals',
    'Notifications',
  ];

  @override
  Widget build(BuildContext context) {
    if (user == null) return const LoginScreen();

    final lecturerEmail = user!.email ?? "Unknown Email";
    final lecturerName = (user!.displayName != null &&
        user!.displayName!.trim().isNotEmpty)
        ? user!.displayName!
        : lecturerEmail.split('@').first;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        centerTitle: true,
        actions: _currentIndex == 4
            ? [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    if (value == 'mark_all') {
                      await _markAllNotificationsAsRead(lecturerEmail);
                    } else if (value == 'clear_all') {
                      await _clearAllNotifications(lecturerEmail);
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

      drawer: LecturerDrawer(
        lecturerName: lecturerName,
        lecturerEmail: lecturerEmail,
        isDarkMode: isDarkMode,
        onThemeChanged: (value) => setState(() => isDarkMode = value),
        onLogout: () async {
          final confirm = await _confirmLogout(context);
          if (confirm == true) {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            }
          }
        },
      ),

      body: _screens[_currentIndex],

      // ✅ Bottom Navigation Bar with Badge Count
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('targetEmail', isEqualTo: lecturerEmail)
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
                  _buildLecturerNavItem(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard,
                    label: 'Home',
                    isSelected: _currentIndex == 0,
                    isDark: isDark,
                  ),
                  _buildLecturerNavItem(
                    icon: Icons.assignment_outlined,
                    activeIcon: Icons.assignment,
                    label: 'Cases',
                    isSelected: _currentIndex == 1,
                    isDark: isDark,
                  ),
                  _buildLecturerNavItem(
                    icon: Icons.description_outlined,
                    activeIcon: Icons.description,
                    label: 'Report',
                    isSelected: _currentIndex == 2,
                    isDark: isDark,
                  ),
                  _buildLecturerNavItem(
                    icon: Icons.mail_outline,
                    activeIcon: Icons.mail,
                    label: 'Appeals',
                    isSelected: _currentIndex == 3,
                    isDark: isDark,
                  ),
                  _buildLecturerNavItem(
                    icon: Icons.notifications_outlined,
                    activeIcon: Icons.notifications,
                    label: 'Alerts',
                    isSelected: _currentIndex == 4,
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

  Future<bool?> _confirmLogout(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout Confirmation"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllNotificationsAsRead(String lecturerEmail) async {
    final query = await FirebaseFirestore.instance
        .collection('notifications')
        .where('targetEmail', isEqualTo: lecturerEmail)
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

  Future<void> _clearAllNotifications(String lecturerEmail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
          .where('targetEmail', isEqualTo: lecturerEmail)
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

  BottomNavigationBarItem _buildLecturerNavItem({
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
                    : (badgeCount > 0 && label == 'Alerts'
                        ? Colors.orange.shade400
                        : null),
              ),
            ),
            // Badge for Alerts
            if (badgeCount > 0 && label == 'Alerts')
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
            if (badgeCount > 0 && label == 'Alerts')
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
