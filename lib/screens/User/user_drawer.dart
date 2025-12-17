import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme_controller.dart';

class UserDrawer extends StatefulWidget {
  const UserDrawer({super.key});

  @override
  State<UserDrawer> createState() => _UserDrawerState();
}

class _UserDrawerState extends State<UserDrawer> {
  final user = FirebaseAuth.instance.currentUser;
  String? userName;
  String? userEmail;

  bool _isDarkMode = false;

  Color _adaptiveTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87;

  @override
  void initState() {
    super.initState();
    _isDarkMode = ThemeController.themeNotifier.value == ThemeMode.dark;
    ThemeController.themeNotifier.addListener(_onThemeChanged);
    _loadUserDetails();
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

  Future<void> _loadUserDetails() async {
    try {
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      setState(() {
        userName = doc.data()?['name'] ?? 'Student User';
        userEmail = user?.email ?? 'No Email';
      });
    } catch (_) {
      setState(() {
        userName = 'Student User';
        userEmail = user?.email ?? 'No Email';
      });
    }
  }

  void _showSnack(String msg, {Color color = Colors.indigo}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ---- Change Email ----
  Future<void> _changeEmail() async {
    if (user == null) {
      _showSnack('You must be logged in to change email.',
          color: Colors.redAccent);
      return;
    }

    final oldEmailCtrl = TextEditingController(text: user!.email ?? '');
    final currentPassCtrl = TextEditingController();
    final newEmailCtrl = TextEditingController();
    final confirmEmailCtrl = TextEditingController();
    bool showPass = false;
    final scaffoldContext = context; // Capture widget context for snackbars

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            titleTextStyle: TextStyle(
              color: _adaptiveTextColor(context),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            contentTextStyle: TextStyle(
              color: _adaptiveTextColor(context),
            ),
            title: const Text('Change Email'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldEmailCtrl,
                    enabled: false,
                    style: TextStyle(color: _adaptiveTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Current Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: currentPassCtrl,
                    obscureText: !showPass,
                    style: TextStyle(color: _adaptiveTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(showPass
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setDialogState(() => showPass = !showPass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: _adaptiveTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'New Email',
                      prefixIcon:
                          const Icon(Icons.mark_email_read_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: _adaptiveTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Email',
                      prefixIcon:
                          const Icon(Icons.mark_email_unread_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final pass = currentPassCtrl.text.trim();
                  final newEmail = newEmailCtrl.text.trim();
                  final confirm = confirmEmailCtrl.text.trim();

                  if (pass.isEmpty || newEmail.isEmpty || confirm.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all fields.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }
                  if (newEmail != confirm) {
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(
                          content: Text('❌ New email and confirmation do not match.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }
                  if (newEmail.toLowerCase() == (user!.email ?? '').toLowerCase()) {
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(
                          content: Text('❌ New email must be different from current email.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }
                  if (!newEmail.contains('@') || !newEmail.contains('.')) {
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Please enter a valid email address.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }

                  try {
                    final cred = EmailAuthProvider.credential(
                        email: user!.email!, password: pass);
                    await user!.reauthenticateWithCredential(cred);
                  } on FirebaseAuthException catch (e) {
                    String errorMsg = '❌ Re-authentication failed.';
                    if (e.code == 'wrong-password') {
                      errorMsg = '❌ Incorrect password.';
                    } else if (e.code == 'user-mismatch' || e.code == 'user-not-found') {
                      errorMsg = '❌ Account not found or mismatch.';
                    } else if (e.message != null) {
                      errorMsg = '❌ ${e.message}';
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        SnackBar(
                          content: Text(errorMsg),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }

                  try {
                    await user!.updateEmail(newEmail);
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .update({'email': newEmail});

                    // Also update email in cases and appeals if they exist
                    final batch = FirebaseFirestore.instance.batch();
                    final casesQuery = await FirebaseFirestore.instance
                        .collection('cases')
                        .where('email', isEqualTo: user!.email)
                        .get();
                    for (var doc in casesQuery.docs) {
                      batch.update(doc.reference, {'email': newEmail});
                    }
                    final appealsQuery = await FirebaseFirestore.instance
                        .collection('appeals')
                        .where('email', isEqualTo: user!.email)
                        .get();
                    for (var doc in appealsQuery.docs) {
                      batch.update(doc.reference, {'email': newEmail});
                    }
                    await batch.commit();

                    if (mounted) {
                      Navigator.pop(dialogContext);
                      _showSnack('✅ Email updated successfully.');
                      setState(() => userEmail = newEmail);
                    }
                  } on FirebaseAuthException catch (e) {
                    String errorMsg = '❌ Failed to update email.';
                    if (e.code == 'email-already-in-use') {
                      errorMsg = '❌ This email is already in use by another account.';
                    } else if (e.code == 'invalid-email') {
                      errorMsg = '❌ Invalid email address.';
                    } else if (e.message != null) {
                      errorMsg = '❌ ${e.message}';
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        SnackBar(
                          content: Text(errorMsg),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        SnackBar(
                          content: Text('❌ Failed to update email: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---- Change Password ----
  Future<void> _changePassword() async {
    if (user == null) {
      _showSnack('You must be logged in to change password.',
          color: Colors.redAccent);
      return;
    }

    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool showOld = false, showNew = false, showConfirm = false;
    final scaffoldContext = context; // Capture widget context for snackbars

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            titleTextStyle: TextStyle(
              color: _adaptiveTextColor(context),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            contentTextStyle: TextStyle(
              color: _adaptiveTextColor(context),
            ),
            title: const Text('Change Password'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldCtrl,
                    obscureText: !showOld,
                    style: TextStyle(color: _adaptiveTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(showOld
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setDialogState(
                            () => showOld = !showOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newCtrl,
                    obscureText: !showNew,
                    style: TextStyle(color: _adaptiveTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon:
                          const Icon(Icons.lock_reset_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(showNew
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setDialogState(
                            () => showNew = !showNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: !showConfirm,
                    style: TextStyle(color: _adaptiveTextColor(context)),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon:
                          const Icon(Icons.lock_person_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(showConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setDialogState(
                            () => showConfirm = !showConfirm),
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

                  if (oldPass.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all fields.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }
                  if (newPass.length < 6) {
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Password must be at least 6 characters long.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }
                  if (newPass != confirm) {
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(
                          content: Text('❌ New password and confirmation do not match.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }
                  if (oldPass == newPass) {
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(
                          content: Text('❌ New password must be different from current password.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }

                  try {
                    final cred = EmailAuthProvider.credential(
                      email: user!.email!,
                      password: oldPass,
                    );
                    await user!.reauthenticateWithCredential(cred);
                  } on FirebaseAuthException catch (e) {
                    String errorMsg = '❌ Re-authentication failed.';
                    if (e.code == 'wrong-password') {
                      errorMsg = '❌ Incorrect current password.';
                    } else if (e.code == 'user-mismatch' || e.code == 'user-not-found') {
                      errorMsg = '❌ Account not found or mismatch.';
                    } else if (e.message != null) {
                      errorMsg = '❌ ${e.message}';
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        SnackBar(
                          content: Text(errorMsg),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }

                  try {
                    await user!.updatePassword(newPass);
                    if (mounted) {
                      Navigator.pop(dialogContext);
                      _showSnack('✅ Password updated successfully.');
                    }
                  } on FirebaseAuthException catch (e) {
                    String errorMsg = '❌ Failed to update password.';
                    if (e.code == 'weak-password') {
                      errorMsg = '❌ Password is too weak. Please choose a stronger password.';
                    } else if (e.message != null) {
                      errorMsg = '❌ ${e.message}';
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        SnackBar(
                          content: Text(errorMsg),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        SnackBar(
                          content: Text('❌ Failed to update password: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update'),
              ),
            ],
          );
        },
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
        titleTextStyle: TextStyle(
          color: _adaptiveTextColor(context),
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: _adaptiveTextColor(context),
        ),
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
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
          // Beautiful Header Section (matching lecturer drawer)
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
                      Icons.person,
                      size: 40,
                      color: Colors.indigo,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  userName ?? 'Student User',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.email_outlined,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        userEmail ?? 'No Email',
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

          // Settings Section (styled like lecturer drawer)
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
