import 'package:intl/intl.dart';

/// Utility functions for the app
class AppUtils {
  /// Format DateTime to readable string
  static String formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('MMM dd, yyyy HH:mm');
    return formatter.format(dateTime);
  }

  /// Format duration in seconds to MM:SS format
  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Check if email is valid
  static bool isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  /// Get initials from name
  static String getInitials(String name) {
    if (name.isEmpty) return '';
    return name[0].toUpperCase();
  }

  /// Validate password strength
  static String? validatePassword(String password) {
    if (password.isEmpty) return 'Password cannot be empty';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  /// Get time difference from now
  static String getTimeSince(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return 'Over a week ago';
    }
  }
}
