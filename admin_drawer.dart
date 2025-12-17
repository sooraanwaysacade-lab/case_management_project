import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme_controller.dart';
import '../screens/login_screen.dart';

class AdminDrawer extends StatefulWidget {
  const AdminDrawer({super.key});

  @override
  State<AdminDrawer> createState() => _AdminDrawerState();

  /// ✅ Helper method to create a Drawer icon that works in nested Scaffolds
  static Widget buildMenuIcon(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      onPressed: () {
        // Open the drawer from the nearest Scaffold ancestor
        Scaffold.maybeOf(context)?.openDrawer();
      },
    );
  }
}

class _AdminDrawerState extends State<AdminDrawer> {
  final user = FirebaseAuth.instance.currentUser;
  String? adminName;
  String? adminEmail;
  bool _isDarkMode = false;

  Color _adaptiveTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87;

  @override
  void initState() {
    super.initState();
    _loadAdminDetails();
    // Initialize dark mode state from ThemeController
    _isDarkMode = ThemeController.themeNotifier.value == ThemeMode.dark;
    // Listen to theme changes
    ThemeController.themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _isDarkMode = ThemeController.themeNotifier.value == ThemeMode.dark;
      });
    }
  }

  Future<void> _loadAdminDetails() async {
    try {
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      setState(() {
        adminName = doc.data()?['name'] ?? 'Administrator';
        adminEmail = user?.email ?? 'No Email';
      });
    } catch (_) {
      setState(() {
        adminName = 'Administrator';
        adminEmail = user?.email ?? 'No Email';
      });
    }
  }

  void _showSnack(String msg, {Color color = Colors.indigo}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<bool> _reauthenticate(String password) async {
    try {
      final cred = EmailAuthProvider.credential(
        email: user!.email!,
        password: password,
      );
      await user!.reauthenticateWithCredential(cred);
      return true;
    } catch (_) {
      _showSnack('❌ Incorrect current password.', color: Colors.redAccent);
      return false;
    }
  }

  // ✉️ Change Email
  Future<void> _changeEmail() async {
    final currentEmailCtrl = TextEditingController();
    final currentPasswordCtrl = TextEditingController();
    final newEmailCtrl = TextEditingController();
    final confirmEmailCtrl = TextEditingController();
    bool obscurePassword = true;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          titleTextStyle: TextStyle(
              color: _adaptiveTextColor(context),
              fontWeight: FontWeight.bold,
              fontSize: 18),
          contentTextStyle: TextStyle(color: _adaptiveTextColor(context)),
          title: const Text('Change Email'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentEmailCtrl,
                  style: TextStyle(color: _adaptiveTextColor(context)),
                  decoration: const InputDecoration(
                    labelText: 'Current Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: currentPasswordCtrl,
                  obscureText: obscurePassword,
                  style: TextStyle(color: _adaptiveTextColor(context)),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setDialogState(
                              () => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newEmailCtrl,
                  style: TextStyle(color: _adaptiveTextColor(context)),
                  decoration: const InputDecoration(
                    labelText: 'New Email',
                    prefixIcon: Icon(Icons.mark_email_read_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmEmailCtrl,
                  style: TextStyle(color: _adaptiveTextColor(context)),
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Email',
                    prefixIcon: Icon(Icons.mark_email_unread_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final currentEmail = currentEmailCtrl.text.trim();
                final currentPassword = currentPasswordCtrl.text.trim();
                final newEmail = newEmailCtrl.text.trim();
                final confirmEmail = confirmEmailCtrl.text.trim();

                if (newEmail != confirmEmail) {
                  _showSnack('❌ Emails do not match.',
                      color: Colors.redAccent);
                  return;
                }

                if (currentEmail != user?.email) {
                  _showSnack('❌ Current email does not match.',
                      color: Colors.redAccent);
                  return;
                }

                final ok = await _reauthenticate(currentPassword);
                if (!ok) return;

                try {
                  await user?.updateEmail(newEmail);
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user?.uid)
                      .update({'email': newEmail});

                  if (mounted) {
                    Navigator.pop(context);
                    _showSnack('Email updated successfully.');
                  }
                } catch (e) {
                  _showSnack('❌ Failed to update email: $e',
                      color: Colors.redAccent);
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  // 🔒 Change Password
  Future<void> _changePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          titleTextStyle: TextStyle(
              color: _adaptiveTextColor(context),
              fontWeight: FontWeight.bold,
              fontSize: 18),
          contentTextStyle: TextStyle(color: _adaptiveTextColor(context)),
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldCtrl,
                  obscureText: obscureOld,
                  style: TextStyle(color: _adaptiveTextColor(context)),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureOld
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setDialogState(
                              () => obscureOld = !obscureOld),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newCtrl,
                  obscureText: obscureNew,
                  style: TextStyle(color: _adaptiveTextColor(context)),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setDialogState(
                              () => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscureConfirm,
                  style: TextStyle(color: _adaptiveTextColor(context)),
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_person_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setDialogState(
                              () => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final oldPass = oldCtrl.text.trim();
                final newPass = newCtrl.text.trim();
                final confirm = confirmCtrl.text.trim();

                if (newPass != confirm) {
                  _showSnack('❌ Passwords do not match.',
                      color: Colors.redAccent);
                  return;
                }

                final ok = await _reauthenticate(oldPass);
                if (!ok) return;

                try {
                  await user?.updatePassword(newPass);
                  if (mounted) {
                    Navigator.pop(context);
                    _showSnack('Password updated successfully.');
                  }
                } catch (e) {
                  _showSnack('❌ Failed to update password: $e',
                      color: Colors.redAccent);
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleDarkMode(bool val) {
    setState(() => _isDarkMode = val);
    ThemeController.themeNotifier.value =
    val ? ThemeMode.dark : ThemeMode.light;
    _showSnack(val ? '🌙 Dark Mode Enabled' : '☀️ Light Mode Enabled');
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        titleTextStyle: TextStyle(color: _adaptiveTextColor(context)),
        contentTextStyle: TextStyle(color: _adaptiveTextColor(context)),
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout')),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Drawer(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Beautiful Header Section
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.indigo, Colors.blueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.only(
              top: 60,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 40,
                      color: Colors.indigo,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  adminName ?? 'Administrator',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                // Email
                Row(
                  children: [
                    const Icon(Icons.email_outlined, 
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        adminEmail ?? 'No Email',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Settings Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                width: 1,
              ),
            ),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.settings, 
                    color: Colors.indigo, size: 22),
              ),
              title: Text(
                'Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              iconColor: isDark ? Colors.white70 : Colors.grey[600],
              collapsedIconColor: isDark ? Colors.white70 : Colors.grey[600],
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.email_outlined,
                  title: 'Change Email',
                  onTap: _changeEmail,
                  isDark: isDark,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  onTap: _changePassword,
                  isDark: isDark,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SwitchListTile(
                    secondary: Icon(
                      _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: isDark ? Colors.amber : Colors.blueGrey,
                    ),
                    title: Text(
                      'Dark Mode',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: _isDarkMode,
                    onChanged: _toggleDarkMode,
                    activeColor: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Logout Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.red[900]!.withOpacity(0.2) 
                  : Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark 
                    ? Colors.red[800]!.withOpacity(0.5) 
                    : Colors.red[200]!,
                width: 1,
              ),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.logout,
                  color: Colors.redAccent,
                  size: 22,
                ),
              ),
              title: Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isDark ? Colors.red[200] : Colors.red[700],
                ),
              ),
              onTap: _logout,
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[700] : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700],
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
