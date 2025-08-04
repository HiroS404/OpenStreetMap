import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:map_try/pages/owner_logIn/vendor_login.dart';
import 'package:map_try/pages/vendor_data_registration.dart';

class CreateRestoAccPage extends StatefulWidget {
  const CreateRestoAccPage({super.key});

  @override
  State<CreateRestoAccPage> createState() => _CreateRestoAccPageState();
}

class _CreateRestoAccPageState extends State<CreateRestoAccPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> _register() async {
    setState(() => isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      final user = userCredential.user;
      if (!mounted) return;

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => VendorRegistrationPage(user: user)),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Registration failed')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Resto Account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : _register,
              child:
                  isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Create Account'),
            ),
            const SizedBox(height: 20),
            // ✅ Already have account button
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VendorLoginPage()),
                );
              },
              child: const Text("Already have an account? Log In"),
            ),
          ],
        ),
      ),
    );
  }
}
