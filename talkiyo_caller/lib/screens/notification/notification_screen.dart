import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  Widget _notificationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.15),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),

          Text(
            time,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        forceMaterialTransparency: true,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: Icon(Icons.arrow_back_ios, color: Colors.grey.shade700),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 22, color: Colors.black),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 20),
        children: [
          _notificationTile(
            icon: Icons.call,
            iconColor: Colors.green,
            title: "New Call Request",
            subtitle: "John Doe wants to connect with you.",
            time: "2m ago",
          ),

          _notificationTile(
            icon: Icons.message,
            iconColor: Colors.blue,
            title: "New Message",
            subtitle: "You received a message from Alex.",
            time: "10m ago",
          ),

          _notificationTile(
            icon: Icons.star,
            iconColor: Colors.orange,
            title: "New Rating",
            subtitle: "Someone rated your session ⭐⭐⭐⭐",
            time: "1h ago",
          ),

          _notificationTile(
            icon: Icons.notifications_active,
            iconColor: Colors.purple,
            title: "Reminder",
            subtitle: "Your scheduled session starts soon.",
            time: "3h ago",
          ),

          _notificationTile(
            icon: Icons.system_update,
            iconColor: Colors.teal,
            title: "App Update",
            subtitle: "A new version of the app is available.",
            time: "Yesterday",
          ),
        ],
      ),
    );
  }
}
