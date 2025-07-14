import 'package:flutter/material.dart';
import 'package:hatchtech/dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Define valid credentials
  final String validUsername = "Hatchtech";
  final String validPassword = "1234";

  bool isLoginFailed = false;

  void _handleLogin() {
    final inputUsername = _usernameController.text.trim();
    final inputPassword = _passwordController.text.trim();

    if (inputUsername == validUsername && inputPassword == validPassword) {
      setState(() {
        isLoginFailed = false;
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Dashboard()),
      );
    } else {
      setState(() {
        isLoginFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[100],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.egg, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                'HatchTech',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person),
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock),
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              isLoginFailed
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Invalid username or password',
                          style: TextStyle(color: Colors.red),
                        ),
                        TextButton(
                          onPressed: () {
                            // Add forgot password logic if needed
                          },
                          child: const Text('Forgot Password?'),
                        ),
                      ],
                    )
                  : Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // Add forgot password logic if needed
                        },
                        child: const Text('Forgot Password?'),
                      ),
                    ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _handleLogin,
                child: const Text('Log In'),
              ),
              const SizedBox(height: 10),
              const Text("Don't have an account? Sign Up"),
            ],
          ),
        ),
      ),
    );
  }
}