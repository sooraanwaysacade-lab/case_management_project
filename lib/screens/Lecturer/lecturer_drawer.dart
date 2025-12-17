import 'package:flutter/material.dart';
import '../../theme_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LecturerDrawer extends StatefulWidget {
  final String lecturerName;
  final String lecturerEmail;
  final VoidCallback onLogout;
  final ValueChanged<bool> onThemeChanged; // kept for backward compatibility
  final bool isDarkMode;

  const LecturerDrawer({
    super.key,
    required this.lecturerName,
    required this.lecturerEmail,
    required this.onLogout,
    required this.onThemeChanged,
    required this.isDarkMode,
  });

  @override
  State<LecturerDrawer> createState() => _LecturerDrawerState();
}

class _LecturerDrawerState extends State<LecturerDrawer> {
  bool _isDarkMode = false;

  // Obscure toggles
  bool _obscureCurrentEmailPass = true;
  bool _obscureCurrentPass = true;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  Color _adaptiveTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87;

  @override
  void initState() {
    super.initState();
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

  void _showSnack(String msg, {Color color = Colors.indigo}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ---------- Dialogs ----------

  Future<void> _showChangeEmailDialog() async {
    Navigator.of(context).pop(); // close drawer

    // ✅ Create new local controllers (prevents dispose crash)
    final currentEmailCtrl = TextEditingController();
    final currentEmailPasswordCtrl = TextEditingController();
    final newEmailCtrl = TextEditingController();
    final confirmEmailCtrl = TextEditingController();
    final emailFormKey = GlobalKey<FormState>();
    bool obscurePassword = true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            titleTextStyle: TextStyle(
              color: _adaptiveTextColor(context),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            contentTextStyle: TextStyle(
              color: _adaptiveTextColor(context),
            ),
            title: const Text("Change Email"),
            content: Form(
              key: emailFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: _adaptiveTextColor(context)),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Please enter Current Email";
                        if (v.trim().toLowerCase() != widget.lecturerEmail.toLowerCase()) {
                          return "Email doesn't match your current email";
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Current Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: currentEmailPasswordCtrl,
                      obscureText: obscurePassword,
                      style: TextStyle(color: _adaptiveTextColor(context)),
                      validator: (v) => (v == null || v.isEmpty) ? "Please enter Current Password" : null,
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
                    TextFormField(
                      controller: newEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: _adaptiveTextColor(context)),
                      validator: (v) =>
                      (v == null || v.isEmpty) ? "Please enter New Email" : null,
                      decoration: const InputDecoration(
                        labelText: 'New Email',
                        prefixIcon: Icon(Icons.mark_email_read_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: confirmEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: _adaptiveTextColor(context)),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Please confirm New Email";
                        if (v.trim() != newEmailCtrl.text.trim()) return "Emails do not match";
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Email',
                        prefixIcon: Icon(Icons.mark_email_unread_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (emailFormKey.currentState!.validate()) {
                    Navigator.pop(context);
                    _showSnack("✅ Email updated successfully (placeholder).");
                  }
                },
                child: const Text("Update"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showChangePasswordDialog() async {
    Navigator.of(context).pop(); // close drawer first

    // ✅ Create new local controllers
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final passwordFormKey = GlobalKey<FormState>();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            titleTextStyle: TextStyle(
              color: _adaptiveTextColor(context),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            contentTextStyle: TextStyle(
              color: _adaptiveTextColor(context),
            ),
            title: const Text("Change Password"),
            content: Form(
              key: passwordFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPassCtrl,
                      obscureText: obscureOld,
                      style: TextStyle(color: _adaptiveTextColor(context)),
                      validator: (val) => (val == null || val.isEmpty) ? "Please enter Current Password" : null,
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
                    TextFormField(
                      controller: newPassCtrl,
                      obscureText: obscureNew,
                      style: TextStyle(color: _adaptiveTextColor(context)),
                      validator: (val) => (val == null || val.isEmpty) ? "Please enter New Password" : null,
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
                    TextFormField(
                      controller: confirmPassCtrl,
                      obscureText: obscureConfirm,
                      style: TextStyle(color: _adaptiveTextColor(context)),
                      validator: (val) => (val == null || val.isEmpty) ? "Please enter Confirm New Password" : null,
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (passwordFormKey.currentState!.validate()) {
                    if (newPassCtrl.text.trim() != confirmPassCtrl.text.trim()) {
                      _showSnack("Passwords do not match", color: Colors.redAccent);
                      return;
                    }
                    Navigator.pop(context);
                    _showSnack("✅ Password changed successfully (placeholder).");
                  }
                },
                child: const Text("Update"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLogoutConfirmation() async {
    Navigator.of(context).pop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          titleTextStyle: TextStyle(
            color: _adaptiveTextColor(context),
            fontWeight: FontWeight.bold,
          ),
          contentTextStyle: TextStyle(
            color: _adaptiveTextColor(context),
          ),
          title: const Text("Confirm Logout"),
          content: const Text("Are you sure you want to log out?"),
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
        );
      },
    );

    if (confirmed == true) widget.onLogout();
  }

  void _toggleDarkMode(bool val) {
    setState(() => _isDarkMode = val);
    ThemeController.themeNotifier.value =
        val ? ThemeMode.dark : ThemeMode.light;
    _showSnack(val ? '🌙 Dark Mode Enabled' : '☀️ Light Mode Enabled');
  }

  // ---------- UI ----------

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
                      Icons.person,
                      size: 40,
                      color: Colors.indigo,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  widget.lecturerName,
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
                        widget.lecturerEmail,
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
                  onTap: _showChangeEmailDialog,
                  isDark: isDark,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  onTap: _showChangePasswordDialog,
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
              onTap: _showLogoutConfirmation,
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
