import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'overview_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.themeNotifier});

  final ValueNotifier<ThemeMode> themeNotifier;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _recoveryController = TextEditingController();

  bool isLoginFailed = false;
  bool obscurePassword = true;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_clearError);
    _passwordController.addListener(_clearError);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _usernameController.dispose();
    _passwordController.dispose();
    _recoveryController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (isLoginFailed) {
      setState(() {
        isLoginFailed = false;
        errorMessage = null;
      });
    }
  }

  void _handleLogin() async {
    final inputUsername = _usernameController.text.trim();
    final inputPassword = _passwordController.text.trim();

    if (inputUsername.isEmpty || inputPassword.isEmpty) {
      setState(() {
        isLoginFailed = true;
        errorMessage = "Please fill in all fields";
      });
      return;
    }

    setState(() {
      isLoading = true;
      isLoginFailed = false;
      errorMessage = null;
    });

    Map<String, dynamic> result;

    // Check if input is email or username
    if (inputUsername.contains('@')) {
      // Sign in with email
      result = await AuthService.signIn(
        email: inputUsername,
        password: inputPassword,
      );
    } else {
      // Sign in with username
      result = await AuthService.signInWithUsername(
        username: inputUsername,
        password: inputPassword,
      );
    }

    setState(() {
      isLoading = false;
    });

    if (result['success']) {
      // Get user data from Firestore
      final userData = await AuthService.getUserData();
      final username = userData?['username'] ?? 'User';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OverviewPage(
            userName: username,
            themeNotifier: widget.themeNotifier,
          ),
        ),
      );
    } else {
      setState(() {
        isLoginFailed = true;
        errorMessage = result['message'];
      });
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  void _showPasswordResetSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 40, color: Colors.green.shade600),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Reset Link Sent!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'A password reset link has been sent to $email. Please check your email and follow the instructions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showForgotPasswordDialog() {
    _recoveryController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Password Recovery'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your email address to receive a password reset link.'),
              const SizedBox(height: 16),
              TextField(
                controller: _recoveryController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = _recoveryController.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter your email address')),
                  );
                  return;
                }
                if (!_isValidEmail(email)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid email address')),
                  );
                  return;
                }
                
                Navigator.pop(context);
                
                final result = await AuthService.resetPassword(email: email);
                
                if (result['success']) {
                  _showPasswordResetSuccessDialog(email);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'])),
                  );
                }
              },
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon, 
        color: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blueAccent,
      ),
      filled: true,
      fillColor: isDarkMode 
          ? const Color(0xFF2A2A2A)
          : Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey.shade700,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blueAccent, 
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDarkMode ? const Color(0xFFCF6679) : Colors.red, 
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode ? [
              const Color(0xFF0D1117), 
              const Color(0xFF121212), 
              const Color(0xFF1E1E1E), 
            ] : [
              Colors.blue.shade50,
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: width < 480 ? 20 : (width - 420) / 2,
              vertical: height > 600 ? 40 : 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height - 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "HatchTech",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    width: width < 480 ? double.infinity : 420,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _usernameController,
                          decoration: _inputDecoration("Username", Icons.person, context),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: obscurePassword,
                          decoration: _inputDecoration("Password", Icons.lock, context).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => obscurePassword = !obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (isLoginFailed && errorMessage != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Log In", style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? "),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SignUpScreen(themeNotifier: widget.themeNotifier),
                                  ),
                                );
                              },
                              child: const Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
