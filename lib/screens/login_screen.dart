import 'package:flutter/material.dart';
import 'package:biosyn_report_flutter/widgets/logo_widget.dart';
import 'package:biosyn_report_flutter/theme/colors.dart';
import 'package:biosyn_report_flutter/services/supabase_service.dart';
import 'package:biosyn_report_flutter/utils/responsive.dart';
import 'package:biosyn_report_flutter/utils/error_handler.dart';

class LoginScreen extends StatefulWidget {
  final Function(String, String) onLogin;

  const LoginScreen({
    super.key,
    required this.onLogin,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;


  Future<void> _handleLogin() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() {
        _error = 'Please enter both username and password';
        _isLoading = false;
      });
      return;
    }

    try {
      // Supabase authentication with retry
      await RetryHandler.executeWithRetry(
        maxRetries: 2,
        initialDelay: 1,
        function: () async {
          await SupabaseService.signIn(
            _usernameController.text.trim(),
            _passwordController.text,
          );
        },
      );

      // If successful, proceed with app login/navigation
      // The role will be determined automatically from the user data
      if (mounted) {
        widget.onLogin(
          _usernameController.text.trim(),
          _passwordController.text,
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, context: 'LoginScreen._handleLogin', stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          // Display user-friendly error message
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('invalid') || 
              errorString.contains('password') || 
              errorString.contains('credentials') ||
              errorString.contains('401') ||
              errorString.contains('user not found') ||
              errorString.contains('اسم المستخدم')) {
            _error = 'اسم المستخدم أو كلمة المرور غير صحيحة';
          } else if (errorString.contains('supabase not initialized') ||
                     errorString.contains('connection') ||
                     errorString.contains('network')) {
            _error = 'فشل الاتصال بالخادم. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';
          } else {
            _error = ErrorHandler.getUserFriendlyMessage(e);
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryBlue, AppColors.primaryDark, AppColors.primaryCyan],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: Responsive.responsivePadding(context),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: Responsive.isMobile(context) 
                      ? double.infinity 
                      : Responsive.maxContentWidth(context),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    const LogoWidget(size: 200, showText: true),
                    const SizedBox(height: 24),
                    // Title
                    const Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.gray600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Error Message
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    if (_error != null) const SizedBox(height: 16),
                    // Username Field
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Password Field
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Login Button
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradientHorizontal,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _handleLogin,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: _isLoading
                                ? const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

