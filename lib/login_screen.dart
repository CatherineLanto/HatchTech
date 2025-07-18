import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  final String validUsername = "Hatchtech";
  final String validPassword = "1234";

  bool isLoginFailed = false;
  bool obscurePassword = true;
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

    final prefs = await SharedPreferences.getInstance();
    final userKey = inputUsername.toLowerCase().replaceAll(' ', '');
    
    // Check registered users first
    final registeredUsers = prefs.getStringList('registered_users') ?? [];
    final storedPassword = prefs.getString('user_password_$userKey');
    
    bool isValidLogin = false;
    String specificError = "Invalid username or password";
    
    if (registeredUsers.contains(userKey)) {
      if (storedPassword == inputPassword) {
        // Valid registered user
        isValidLogin = true;
      } else {
        // User exists but wrong password
        specificError = "Incorrect password for this account";
      }
    } else if (inputUsername == validUsername && inputPassword == validPassword) {
      // Fallback to default admin account
      isValidLogin = true;
      // Register the admin account in the system if not already done
      if (!registeredUsers.contains(userKey)) {
        registeredUsers.add(userKey);
        await prefs.setStringList('registered_users', registeredUsers);
        await prefs.setString('user_password_$userKey', validPassword);
        await prefs.setString('user_name_$userKey', validUsername);
        await prefs.setString('original_login_name_$userKey', validUsername);
      }
    } else {
      // Check if username exists with different case/spacing
      bool foundSimilar = false;
      for (String existingUser in registeredUsers) {
        final existingOriginal = prefs.getString('original_login_name_$existingUser') ?? '';
        if (existingOriginal.toLowerCase() == inputUsername.toLowerCase()) {
          foundSimilar = true;
          break;
        }
      }
      if (foundSimilar) {
        specificError = "Account found but username format doesn't match. Try the exact username you used during signup.";
      } else {
        specificError = "No account found with this username. Please check your username or sign up for a new account.";
      }
    }

    if (isValidLogin) {
      setState(() {
        isLoginFailed = false;
        errorMessage = null;
      });

      // Load user-specific data from SharedPreferences
      final savedUsername = prefs.getString('user_name_$userKey') ?? inputUsername;
      
      // Save the original login username for this specific user (only if not already saved)
      if (!prefs.containsKey('original_login_name_$userKey')) {
        await prefs.setString('original_login_name_$userKey', inputUsername);
      }
      
      // Set current user identifier for other screens to use
      await prefs.setString('current_user', userKey);

      Navigator.pushReplacement(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(
          builder: (_) => OverviewPage(
            userName: savedUsername,
            themeNotifier: widget.themeNotifier,
          ),
        ),
      );
    } else {
      setState(() {
        isLoginFailed = true;
        errorMessage = specificError;
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
              onPressed: () {
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
                _showPasswordResetSuccessDialog(email);
              },
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, BuildContext context) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blueAccent),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark 
          ? Colors.grey.shade800 
          : Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
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
                  const Text(
                    "HatchTech",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
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
