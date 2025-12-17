import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/case_management_screen.dart';
import 'screens/cases_screen.dart';
import 'screens/report_screen.dart';
import 'screens/appeal_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/User/user_dashboard.dart';
import 'screens/Lecturer/lecturer_dashboard.dart';
import 'widgets/bottom_navbar.dart';
import 'screens/admin_drawer.dart';
import 'theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("🔥 Firebase initialized successfully");
  } catch (e) {
    debugPrint("⚠️ Firebase initialization failed: $e");
  }
  runApp(const CaseApp());
}

class CaseApp extends StatelessWidget {
  const CaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Disciplinary Case Management',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.indigo,
            scaffoldBackgroundColor: Colors.grey[100],
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              centerTitle: true,
              elevation: 2,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              primary: Colors.indigo,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
              onPrimary: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              centerTitle: true,
              elevation: 2,
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
              bodySmall: TextStyle(color: Colors.white60),
              titleLarge: TextStyle(color: Colors.white),
              titleMedium: TextStyle(color: Colors.white),
              titleSmall: TextStyle(color: Colors.white70),
            ),
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.indigo),
              ),
            ),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<String?> _getUserRole(String uid) async {
    try {
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return userDoc.data()?['role'];
    } catch (e) {
      debugPrint("⚠️ Error getting role: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) return const LoginScreen();

        final user = snapshot.data!;
        return FutureBuilder<String?>(
          future: _getUserRole(user.uid),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = roleSnap.data ?? 'User';

            if (role == 'Admin') {
              debugPrint("👑 Logged in as Admin");
              return const AdminHome();
            } else if (role == 'Lecturer') {
              debugPrint("🎓 Logged in as Lecturer");
              return const LecturerDashboard();
            } else {
              debugPrint("👤 Logged in as User");
              return const UserDashboard();
            }
          },
        );
      },
    );
  }
}

/// ✅ ADMIN HOME — Persistent Drawer & Single AppBar
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;

  // Screens
  final _screens = const [
    DashboardScreen(),
    CaseManagementScreen(),
    CasesScreen(),
    ReportScreen(),
    AppealScreen(),
    AlertsScreen(),
  ];

  // Titles for the shared AppBar
  final _titles = const [
    'Dashboard',
    'Analytics & History',
    'Reported Cases',
    'Reports',
    'Appeals',
    'Alerts',
  ];

  /// 🧩 Helper: Clear or mark all notifications (called when 3-dot menu pressed)
  Future<void> _deleteAllNotifications() async {
    final docs = await FirebaseFirestore.instance
        .collection('notifications')
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
    final unread = await FirebaseFirestore.instance
        .collection('notifications')
        .where('targetEmail', isEqualTo: 'admin@system')
        .where('isRead', isEqualTo: false)
        .get();
    for (var doc in unread.docs) {
      await doc.reference.update({'isRead': true});
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ All alerts marked as read')),
    );
  }

  /// 🗑️ Delete all appeals with confirmation
  Future<void> _deleteAllAppeals(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🗑️ Delete All Appeals?'),
        content: const Text(
          'Are you sure you want to delete all appeals?\nThis action cannot be undone.',
          style: TextStyle(fontSize: 15, color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final appeals = await FirebaseFirestore.instance.collection('appeals').get();
      for (var doc in appeals.docs) {
        await doc.reference.delete();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ All appeals deleted successfully'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting appeals: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(),

      // ✅ Shared AppBar across all screens
      appBar: AppBar(
        title: Text(
          _titles[_index],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        elevation: 2,

        // ✅ Show delete icon when Appeals tab is selected (index 4)
        // ✅ Show 3-dots when Alerts tab is selected (index 5)
        actions: _index == 4
            ? [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete all appeals',
            onPressed: () => _deleteAllAppeals(context),
          ),
        ]
            : _index == 5
                ? [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'mark_read') {
                _markAllAsRead();
              } else if (value == 'clear_all') {
                _deleteAllNotifications();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'mark_read',
                child: Text('Mark all as read'),
              ),
              PopupMenuItem(
                value: 'clear_all',
                child: Text('Clear all alerts'),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ]
                : null,
      ),

      // ✅ Screen content below
      body: _screens[_index],

      // ✅ Bottom navigation
      bottomNavigationBar: BottomNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
