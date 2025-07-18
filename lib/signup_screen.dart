import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'overview_screen.dart';

class SignUpScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeNotifier;

  const SignUpScreen({super.key, required this.themeNotifier});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirm = true;
  
  String? errorMessage;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    
    _username.addListener(_clearError);
    _email.addListener(_clearError);
    _password.addListener(_clearError);
    _confirmPassword.addListener(_clearError);
  }

  @override
  void dispose() {
    _username.removeListener(_clearError);
    _email.removeListener(_clearError);
    _password.removeListener(_clearError);
    _confirmPassword.removeListener(_clearError);
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _clearError() {
    if (hasError) {
      setState(() {
        hasError = false;
        errorMessage = null;
      });
    }
  }

  void _showSuccessDialog() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return Dialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1B4332) : Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 40,
                    color: isDarkMode ? const Color(0xFF40C057) : Colors.green.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Welcome to HatchTech!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your account has been created successfully. Start monitoring your incubators now!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OverviewPage(
                            userName: _username.text.trim(),
                            themeNotifier: widget.themeNotifier,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _signUp() async {
    if (_username.text.trim().isEmpty || 
        _email.text.trim().isEmpty || 
        _password.text.trim().isEmpty || 
        _confirmPassword.text.trim().isEmpty) {
      setState(() {
        hasError = true;
        errorMessage = "Please fill in all fields";
      });
      return;
    }

    if (!_email.text.contains('@')) {
      setState(() {
        hasError = true;
        errorMessage = "Please enter a valid email address";
      });
      return;
    }

    if (_password.text != _confirmPassword.text) {
      setState(() {
        hasError = true;
        errorMessage = "Passwords do not match";
      });
      return;
    }

    // Check if username already exists
    final prefs = await SharedPreferences.getInstance();
    final existingUsers = prefs.getStringList('registered_users') ?? [];
    final userKey = _username.text.trim().toLowerCase().replaceAll(' ', '');
    
    if (existingUsers.contains(userKey)) {
      setState(() {
        hasError = true;
        errorMessage = "Username already exists. Please choose a different one.";
      });
      return;
    }

    // Save the new user account
    try {
      final username = _username.text.trim();
      // userKey already defined above with consistent formatting
      
      // Add to list of registered users
      existingUsers.add(userKey);
      await prefs.setStringList('registered_users', existingUsers);
      
      // Save user credentials and info
      await prefs.setString('user_password_$userKey', _password.text);
      await prefs.setString('user_email_$userKey', _email.text.trim());
      await prefs.setString('user_name_$userKey', username);
      await prefs.setString('original_login_name_$userKey', username);
      
      // Set current user session immediately after account creation
      await prefs.setString('current_user', userKey);
      
      setState(() {
        hasError = false;
        errorMessage = null;
      });

      _showSuccessDialog();
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = "Failed to create account. Please try again.";
      });
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
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
              const Color(0xFF0D1117), // Dark navy
              const Color(0xFF121212), // Dark background
              const Color(0xFF1E1E1E), // Slightly lighter dark
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
              vertical: height > 700 ? 40 : 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height - 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Join HatchTech",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? const Color(0xFF6BB6FF) : Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create your account to get started",
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? const Color(0xFFB0B0B0) : Colors.grey.shade600,
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
                          controller: _username,
                          decoration: _inputDecoration("Username", Icons.person),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration("Email", Icons.email),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _password,
                          obscureText: obscurePassword,
                          decoration: _inputDecoration("Password", Icons.lock).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => obscurePassword = !obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmPassword,
                          obscureText: obscureConfirm,
                          decoration: _inputDecoration("Confirm Password", Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (hasError && errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDarkMode ? const Color(0xFF3D1A1A) : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDarkMode ? const Color(0xFFCF6679) : Colors.red.shade300,
                              ),
                            ),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: isDarkMode ? const Color(0xFFCF6679) : Colors.red.shade700,
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Create Account", style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already have an account? "),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LoginScreen(themeNotifier: widget.themeNotifier),
                                  ),
                                );
                              },
                              child: const Text(
                                "Log In",
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
