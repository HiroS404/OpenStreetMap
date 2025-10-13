import 'package:flutter/material.dart';
import 'package:map_try/main.dart';
import 'package:map_try/pages/owner_logIn/vendor_create_resto_acc.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ===== App-wide toggles inside this page =====
  final ValueNotifier<bool> notificationsEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> locationEnabled = ValueNotifier<bool>(true);

  // ===== Notification function =====
  void showNotification(String message) {
    if (!notificationsEnabled.value) return; // skip if notifications disabled
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ===== Location function =====
  void performLocationAction(String action) {
    if (!locationEnabled.value) {
      showNotification("Location is disabled");
      return;
    }
    showNotification("Performing: $action");
    // Add real location code here if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          tooltip: 'Back to Home',
          onPressed: () {
            // Always go back to Home
            bottomNavIndexNotifier.value = 0;

            // Pop the current route if possible (mobile)
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepOrangeAccent,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Header =====
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(
                      "https://static.vecteezy.com/system/resources/previews/004/848/597/large_2x/pin-map-gps-food-restaurant-location-logo-design-vector.jpg",
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Account Settings",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            const Divider(height: 30),

            // ===== Account Settings =====
            const SizedBox(height: 10),

            // SettingsTile(
            //   icon: Icons.account_circle,
            //   title: "Profile",
            //   subtitle: "Update your profile details",
            //   onTap: () => showNotification("Opening Profile"),
            // ),
            // SettingsTile(
            //   icon: Icons.lock,
            //   title: "Privacy & Security",
            //   subtitle: "Manage your privacy settings",
            //   onTap: () => showNotification("Opening Privacy & Security"),
            // ),
            // SettingsTile(
            //   icon: Icons.password,
            //   title: "Change Password",
            //   subtitle: "Update your account password",
            //   onTap: () => showNotification("Opening Change Password"),
            // ),
            // SettingsTile(
            //   icon: Icons.delete_forever,
            //   title: "Delete Account",
            //   subtitle: "Permanently remove your account",
            //   onTap: () => showNotification("Opening Delete Account"),
            // ),
            SettingsTile(
              icon: Icons.logout,
              title: "Login",
              subtitle: "Sign in as Resto Owner",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateRestoAccPage()),
                );
              },
            ),
            const Divider(height: 30),

            // ===== App Info =====
            const Text(
              "About",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SettingsTile(
              icon: Icons.info,
              title: "App Version",
              subtitle: "1.0.0",
              onTap: () => showNotification("App Version 1.0.0"),
            ),
            SettingsTile(
              icon: Icons.description,
              title: "Terms of Service",
              subtitle: "Read the terms of use",
              onTap: () => showNotification("Opening Terms of Service"),
            ),
            SettingsTile(
              icon: Icons.privacy_tip,
              title: "Privacy Policy",
              subtitle: "Read our privacy policy",
              onTap: () => showNotification("Opening Privacy Policy"),
            ),

            const Divider(height: 30),

            // ===== Sample Action Buttons =====
            ElevatedButton(
              onPressed:
                  () => showNotification("This is a sample notification"),
              child: const Text("Send Notification"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed:
                  locationEnabled.value
                      ? () => performLocationAction("Get Current Location")
                      : null, // disable button when location is off
              child: const Text("Perform Location Action"),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Reusable Settings Tile =====
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
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepOrange),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

// ===== Reusable Switch Tile =====
class SwitchSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwitchSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}
