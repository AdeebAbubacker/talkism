import 'package:flutter/material.dart';

import '../models/app_user.dart';

class UserTile extends StatelessWidget {
  const UserTile({super.key, required this.user, required this.onCallTap});

  final AppUser user;
  final VoidCallback? onCallTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: user.isOnline
              ? const Color(0xFFDCFCE7)
              : const Color(0xFFE5E7EB),
          child: Text(
            user.displayName.isEmpty ? '?' : user.displayName[0].toUpperCase(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
        title: Text(
          user.displayName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user.phoneNumber.trim().isNotEmpty)
                Text(
                  user.phoneNumber,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
              if (user.phoneNumber.trim().isNotEmpty) const SizedBox(height: 4),
              Text(
                user.isOnline ? 'Online' : 'Offline',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: user.isOnline
                      ? const Color(0xFF15803D)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton.filled(
          onPressed: user.isOnline ? onCallTap : null,
          icon: const Icon(Icons.call),
        ),
      ),
    );
  }
}
