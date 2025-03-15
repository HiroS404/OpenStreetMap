import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        backgroundColor: Colors.orangeAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "General Settings",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SettingsTile(
              icon: Icons.notifications,
              title: "Notifications",
              subtitle: "Enable or disable notifications",
              onTap: () {},
            ),
            SettingsTile(
              icon: Icons.language,
              title: "Language",
              subtitle: "Change app language",
              onTap: () {},
            ),
            SettingsTile(
              icon: Icons.location_on,
              title: "Location Services",
              subtitle: "Enable GPS and location tracking",
              onTap: () {},
            ),
            const Divider(height: 30),
            const Text(
              "Account Settings",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SettingsTile(
              icon: Icons.account_circle,
              title: "Profile",
              subtitle: "Update your profile details",
              onTap: () {},
            ),
            SettingsTile(
              icon: Icons.lock,
              title: "Privacy & Security",
              subtitle: "Manage your privacy settings",
              onTap: () {},
            ),
            SettingsTile(
              icon: Icons.logout,
              title: "Logout",
              subtitle: "Sign out of your account",
              onTap: () {
                // Add logout logic here
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable settings tile widget
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
