import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Displays a custom toast/snackbar notification at the top of the screen.
///
/// [message] - Text message to display.
/// [isSuccess] - If true, shows a success-style toast; otherwise, an error-style one.
/// [icon] - Optional custom icon (e.g., Icons.check_circle).
void showToast({
  required String message,
  bool isSuccess = true,
  IconData? icon,
}) {
  // Colors for success or error
  Color bgColor = isSuccess ? Colors.green.shade600 : Colors.red.shade600;
  IconData usedIcon = icon ?? (isSuccess ? Icons.check_circle : Icons.error);

  FToast fToast = FToast();
  fToast.init(navigatorKey.currentContext!);

  Widget toast = Container(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12.0),
      color: bgColor,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(usedIcon, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  // Show the toast at the top
  fToast.showToast(
    child: toast,
    gravity: ToastGravity.TOP,
    toastDuration: const Duration(seconds: 3),
  );
}

/// To allow toast usage globally (e.g., before `BuildContext` exists)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
