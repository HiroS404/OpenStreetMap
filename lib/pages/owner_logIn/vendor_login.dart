import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:map_try/pages/owner_logIn/vendor_create_resto_acc.dart';
import 'package:map_try/pages/vendor_dashboard.dart';

class VendorLoginPage extends StatefulWidget {
  const VendorLoginPage({super.key});

  @override
  State<VendorLoginPage> createState() => _VendorLoginPageState();
}

class _VendorLoginPageState extends State<VendorLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> _login() async {
    setState(() => isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      final user = userCredential.user;
      if (user == null || !mounted) return;

      // ✅ Fetch restaurant data for this vendor
      final doc =
          await FirebaseFirestore.instance
              .collection('restaurants')
              .doc(user.uid)
              .get();
      if (!mounted) return;
      if (doc.exists) {
        final restoData = doc.data()!;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => VendorProfilePage(restaurantData: restoData, user: user),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No restaurant found for this account')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
     return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 233, 220), // light gray background
      body: Center(
        child: Container(
          width: 1280,
          height: 700,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 217, 111, 50).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              // LEFT PANEL - Form
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 60), 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start, 
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      // MapaKaon Logo at the top-left
                      const Row(
                        children: [
                          Icon(Icons.ramen_dining, size: 20), 
                          SizedBox(width: 5), 
                          Text(
                            "MapaKaon",
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 50),

                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Welcome!",
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 199, 93, 44)
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Login To Your Account",
                            style: TextStyle(
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                      // Username TextField
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'Email',
                          hintStyle: const TextStyle(
                            fontStyle: FontStyle.italic,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(40),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password TextField
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: const TextStyle(
                            fontStyle: FontStyle.italic,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(40),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(40),
                                ),
                              ),
                              child: isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text(
                                      'LOGIN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account yet? ",
                              style: TextStyle(
                                color: Colors.black,
                                letterSpacing: 1.5,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreateRestoAccPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Sign In",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 50),
                      const Text(
                        "©2025 MapaKaon P.O.C.G",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // RIGHT PANEL - Image
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  child: Image.asset(
                    'Assets/login/loginimage.png', 
                    fit: BoxFit.cover,
                    height: double.infinity,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
