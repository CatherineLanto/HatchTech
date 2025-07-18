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

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _recoveryController = TextEditingController();

  final String validUsername = "Hatchtech";
  final String validPassword = "1234";

  bool isLoginFailed = false;
  bool obscurePassword = true;
  String? errorMessage;
  
  late AnimationController _animationController;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_clearError);
    
    // Initialize staggered animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _animations = List.generate(4, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.15,
            (index * 0.15) + 0.6,
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });
    
    // Start animations after a brief delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _animationController.forward();
      }
    });
    _passwordController.addListener(_clearError);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _usernameController.dispose();
    _passwordController.dispose();
    _recoveryController.dispose();
    _animationController.dispose();
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

    if (inputUsername == validUsername && inputPassword == validPassword) {
      setState(() {
        isLoginFailed = false;
        errorMessage = null;
      });

      // Load user-specific data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userKey = inputUsername.toLowerCase().replaceAll(' ', '');
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
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => OverviewPage(
            userName: savedUsername,
            themeNotifier: widget.themeNotifier,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.3),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
        ),
      );
    } else {
      setState(() {
        isLoginFailed = true;
        errorMessage = "Invalid username or password";
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
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read,
                    color: Colors.blueAccent,
                    size: 45,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Reset Link Sent!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We\'ve sent a password reset link to:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please check your email and follow the instructions to reset your password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
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
                      'Got It',
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

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String? dialogErrorMessage;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_reset, size: 48, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text(
                  'Forgot Password',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your username or email and we’ll send you a reset link.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _recoveryController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    if (dialogErrorMessage != null) {
                      setDialogState(() {
                        dialogErrorMessage = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined),
                    labelText: 'Email Address',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    errorBorder: dialogErrorMessage != null
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          )
                        : null,
                    focusedErrorBorder: dialogErrorMessage != null
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                if (dialogErrorMessage != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      dialogErrorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _recoveryController.clear();
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        String emailInput = _recoveryController.text.trim();
                        
                        if (emailInput.isEmpty) {
                          setDialogState(() {
                            dialogErrorMessage = 'Please enter an email address';
                          });
                          return;
                        }
                        
                        if (!_isValidEmail(emailInput)) {
                          setDialogState(() {
                            dialogErrorMessage = 'Please enter a valid email address';
                          });
                          return;
                        }
                        
                        Navigator.pop(context);
                        _recoveryController.clear();

                        _showPasswordResetSuccessDialog(emailInput);
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Send Link'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, BuildContext context) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Theme.of(context).inputDecorationTheme.fillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, -0.5),
                  end: Offset.zero,
                ).animate(_animations[0]),
                child: FadeTransition(
                  opacity: _animations[0],
                  child: const Text(
                    "HatchTech",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.3),
                  end: Offset.zero,
                ).animate(_animations[1]),
                child: FadeTransition(
                  opacity: _animations[1],
                  child: Container(
                    width: width < 480 ? double.infinity : 420,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
                    ),
                    child: Column(
                      children: [
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-0.3, 0.0),
                            end: Offset.zero,
                          ).animate(_animations[2]),
                          child: FadeTransition(
                            opacity: _animations[2],
                            child: TextField(
                              controller: _usernameController,
                              decoration: _inputDecoration("Username", Icons.person, context),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.3, 0.0),
                            end: Offset.zero,
                          ).animate(_animations[2]),
                          child: FadeTransition(
                            opacity: _animations[2],
                            child: TextField(
                              controller: _passwordController,
                              obscureText: obscurePassword,
                              decoration: _inputDecoration("Password", Icons.lock, context).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => obscurePassword = !obscurePassword),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (isLoginFailed && errorMessage != null)
                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.3),
                              end: Offset.zero,
                            ).animate(_animations[3]),
                            child: FadeTransition(
                              opacity: _animations[3],
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                          ),
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.3, 0.0),
                            end: Offset.zero,
                          ).animate(_animations[3]),
                          child: FadeTransition(
                            opacity: _animations[3],
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: const Text('Forgot Password?'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.5),
                            end: Offset.zero,
                          ).animate(_animations[3]),
                          child: FadeTransition(
                            opacity: _animations[3],
                            child: SizedBox(
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
                          ),
                        ),
                        const SizedBox(height: 16),
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.3),
                            end: Offset.zero,
                          ).animate(_animations[3]),
                          child: FadeTransition(
                            opacity: _animations[3],
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Don't have an account? "),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation, secondaryAnimation) => 
                                          SignUpScreen(themeNotifier: widget.themeNotifier),
                                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                          const begin = Offset(1.0, 0.0);
                                          const end = Offset.zero;
                                          const curve = Curves.easeInOutCubic;
                                          var tween = Tween(begin: begin, end: end).chain(
                                            CurveTween(curve: curve),
                                          );
                                          return SlideTransition(
                                            position: animation.drive(tween),
                                            child: child,
                                          );
                                        },
                                        transitionDuration: const Duration(milliseconds: 300),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Sign Up",
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
