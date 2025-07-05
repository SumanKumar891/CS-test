import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'dart:ui';
import 'package:cloud_sense_webapp/DeviceListPage.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignInSignUpScreen extends StatefulWidget {
  @override
  _SignInSignUpScreenState createState() => _SignInSignUpScreenState();
}

class _SignInSignUpScreenState extends State<SignInSignUpScreen> {
  bool _isSignIn = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _errorMessage = '';
  bool _emailValid = true;
  bool _isLoading = false;
  String? _verificationCode;
  String? _emailToVerify;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser(); // Check if user is already signed in
    _emailController.addListener(() {
      setState(() {
        _emailValid = EmailValidator.validate(
            _emailController.text); // Real-time email validation
      });
    });
  }

  Future<void> _checkCurrentUser() async {
    try {
      var currentUser = await Amplify.Auth.getCurrentUser();
      if (currentUser != null) {
        // If user is already signed in, navigate to DeviceListPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DataDisplayPage(),
          ),
        );
      }
    } catch (e) {
      // Ignore errors — means no current user
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      // Ensure any previous session is cleared before signing in
      try {
        await Amplify.Auth.signOut();
      } catch (e) {
        // Ignoring errors here since user might not be signed in
      }

      // Attempt to sign in with provided credentials
      SignInResult res = await Amplify.Auth.signIn(
        username: _emailController.text,
        password: _passwordController.text,
      );

      if (res.isSignedIn) {
        // Store email in shared preferences for session management
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String email = _emailController.text.trim().toLowerCase();
        await prefs.setString('email', _emailController.text);

        // ✅ Navigate based on specific user
        if (email == "05agriculture.05@gmail.com") {
          print("Navigating to /deviceinfo for $email");
          Navigator.pushReplacementNamed(context, '/deviceinfo');
        } else {
          print("Navigating to /devicelist for $email");
          Navigator.pushReplacementNamed(context, '/devicelist');
        }
      } else {
        _showSnackbar('Sign-in failed');
      }
    } on AuthException catch (e) {
      _showSnackbar(e.message); // Show error message if sign-in fails
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  void _showSnackbar(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _forgotPassword() async {
    String? email = await _showEmailInputDialog(); // Get user email
    if (email != null && _emailValid) {
      try {
        // Request password reset
        await Amplify.Auth.resetPassword(username: email);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A password reset code has been sent to your email.'),
          ),
        );

        // Ask for reset code and new password
        _showPasswordResetCodeDialog(email);
      } on AuthException catch (e) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    }
  }

  // Dialog to enter the reset code
  Future<void> _showPasswordResetCodeDialog(String email) async {
    String? resetCode;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController resetCodeController = TextEditingController();

        return AlertDialog(
          title: Text('Enter Reset Code'),
          content: TextField(
            controller: resetCodeController,
            decoration: InputDecoration(labelText: 'Reset Code'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Submit'),
              onPressed: () {
                resetCode = resetCodeController.text;
                Navigator.of(context).pop();
                if (resetCode != null && resetCode!.isNotEmpty) {
                  // Show the new password dialog after the reset code is entered
                  _showNewPasswordDialog(email, resetCode!);
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Dialog to enter the new password and confirm password
  Future<void> _showNewPasswordDialog(String email, String resetCode) async {
    String? newPassword;
    String? confirmPassword;
    bool passwordsMatch = true;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController newPasswordController = TextEditingController();
        TextEditingController confirmPasswordController =
            TextEditingController();

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Enter New Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newPasswordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  if (!passwordsMatch)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Passwords do not match',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Submit'),
                  onPressed: () async {
                    newPassword = newPasswordController.text;
                    confirmPassword = confirmPasswordController.text;

                    if (newPassword == confirmPassword) {
                      Navigator.of(context).pop();
                      await _confirmResetPassword(
                          email, resetCode, newPassword!);
                    } else {
                      setState(() {
                        passwordsMatch = false;
                      });
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmResetPassword(
      String email, String resetCode, String newPassword) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: resetCode,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Password has been reset. Please log in with your new password.')),
      );
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    }
  }

  Future<String?> _showEmailInputDialog() async {
    String? email;
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController emailController = TextEditingController();
        return AlertDialog(
          title: Text('Reset Password'),
          content: TextField(
            controller: emailController,
            decoration: InputDecoration(labelText: 'Email'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Submit'),
              onPressed: () {
                email = emailController.text;
                Navigator.of(context).pop(email);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true; // Show loading indicator during sign-up
    });

    try {
      // Sign up with email, password, and name attributes
      await Amplify.Auth.signUp(
        username: _emailController.text,
        password: _passwordController.text,
        options: SignUpOptions(
          userAttributes: {
            CognitoUserAttributeKey.email: _emailController.text,
            CognitoUserAttributeKey.name: _nameController.text,
          },
        ),
      );

      // Store email for verification step
      _emailToVerify = _emailController.text;
      _showVerificationDialog(); // Prompt user to enter verification code
    } on UsernameExistsException {
      // Resend code if user already exists but hasn't verified
      try {
        await Amplify.Auth.resendSignUpCode(username: _emailController.text);
        _emailToVerify = _emailController.text;
        _showVerificationDialog();
      } on AuthException catch (e) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message; // Handle other sign-up errors
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resendVerificationCode() async {
    if (_emailToVerify == null) {
      _showSnackbar(
          'Please provide your email to resend the verification code.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Amplify.Auth.resendSignUpCode(username: _emailToVerify!);
      _showSnackbar('Verification code has been resent to your email.');
    } on AuthException catch (e) {
      _showSnackbar(e.message);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmSignUp() async {
    if (_verificationCode == null || _emailToVerify == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Amplify.Auth.confirmSignUp(
        username: _emailToVerify!,
        confirmationCode: _verificationCode!,
      );

      // After successful sign-up and verification, redirect to the sign-in page
      setState(() {
        _isSignIn = true; // Switch to sign-in mode
      });

      // Display a success message or snackbar to notify the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-up successful! Please sign in.')),
      );
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Verify Your Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'A verification code has been sent to your email. Please enter the code below:'),
              TextField(
                onChanged: (value) {
                  _verificationCode = value; // Store verification code
                },
                decoration: InputDecoration(labelText: 'Verification Code'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _resendVerificationCode(); // Resend code if needed
              },
              child: Text('Resend Code'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmSignUp(); // Confirm sign-up using the code
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDarkMode ? Colors.black : Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/sun.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                color: isDarkMode
                    ? Colors.black
                        .withOpacity(0.7) // Darker overlay for dark mode
                    : Colors.black
                        .withOpacity(0.5), // Lighter overlay for light mode
              ),
            ),
          ),
          Center(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 800),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(0.1, 0.0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              },
              child: _isSignIn ? _buildSignIn(isDarkMode) : _buildSignUp(),
            ),
          ),
          if (_errorMessage.isNotEmpty)
            Positioned(
              bottom: 16.0,
              left: 16.0,
              right: 15.0,
              child: Container(
                padding: EdgeInsets.all(16.0),
                color: Colors.redAccent,
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

// Builds the sign-in widget, adjusting layout based on screen size
  Widget _buildSignIn(bool isDarkMode) {
    return SingleChildScrollView(
      key: ValueKey(
          'SignIn'), // Used for widget identification (helpful for animations or testing)
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Check if the screen width is less than 800px (small screen)
          bool isSmallScreen = constraints.maxWidth < 800;

          // Adjust layout: Column for small screens, Row for large screens
          return isSmallScreen
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _buildContent(isSmallScreen, isDarkMode),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _buildContent(isSmallScreen, isDarkMode),
                );
        },
      ),
    );
  }

  // Builds a list of widgets for the Sign-In screen layout
  List<Widget> _buildContent(bool isSmallScreen, bool isDarkMode) {
    return [
      // Welcome section (Left side for large screens, top for small screens)
      Container(
        width: isSmallScreen
            ? double.infinity
            : 400, // Full width for small screens
        height: 500,
        color: isDarkMode
            ? Color.fromARGB(155, 255, 255, 255)
            : Color.fromARGB(155, 0, 0, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 55),
            // Heading text
            Text(
              'Welcome Back!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? Colors.black
                    : Color.fromARGB(223, 216, 226, 231),
              ),
            ),
            SizedBox(height: 15),
            // Subheading text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Text(
                'To keep connected with us please login with your personal info.',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? Colors.purple
                      : Color.fromARGB(223, 205, 108, 230),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Image section
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Container(
                width: 290,
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  image: DecorationImage(
                    image: AssetImage('assets/login.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Add spacing between sections for small screens
      SizedBox(height: isSmallScreen ? 32 : 0),

      // Sign-in form section
      Container(
        width: isSmallScreen ? double.infinity : 400,
        height: 500,
        padding: EdgeInsets.all(32.0),
        color: isDarkMode
            ? const Color.fromARGB(255, 38, 37, 37)
            : const Color.fromARGB(155, 255, 255, 255),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 24),
            // Login title
            Text(
              'Login',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? Colors.white
                    : Color.fromARGB(243, 173, 21, 211),
              ),
            ),
            SizedBox(height: 42),

            // Email text field
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle:
                    TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                border: OutlineInputBorder(),
                errorText: _emailValid ? null : 'Invalid email format',
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: isDarkMode ? Colors.redAccent : Colors.red),
                ),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
            SizedBox(height: 16),

            // Password text field with visibility toggle
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle:
                    TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),

            // Show loading indicator or Sign-in button
            if (_isLoading)
              CircularProgressIndicator()
            else
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: ElevatedButton(
                  onPressed: _signIn,
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.black
                          : const Color.fromARGB(255, 245, 241, 240),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    backgroundColor: isDarkMode
                        ? Colors.purple
                        : Color.fromARGB(223, 205, 108, 230),
                  ),
                ),
              ),
            SizedBox(height: 22),

            // Forgot Password link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.white
                        : Color.fromARGB(181, 113, 5, 214),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: _forgotPassword,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        bottom: -1,
                        child: Container(
                          height: 1.5,
                          width: 40,
                          color: isDarkMode
                              ? Colors.blue
                              : Color.fromARGB(243, 32, 39, 230),
                        ),
                      ),
                      Text(
                        'Reset',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.blue
                              : Color.fromARGB(243, 32, 39, 230),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Sign-up link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Don\'t have an Account?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.white
                        : Color.fromARGB(181, 113, 5, 214),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSignIn = false; // Switch to sign-up form
                    });
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        bottom: -1,
                        child: Container(
                          height: 1.5,
                          width: 45,
                          color: isDarkMode
                              ? Colors.blue
                              : Color.fromARGB(243, 32, 39, 230),
                        ),
                      ),
                      Text(
                        'Sign Up',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.blue
                              : Color.fromARGB(243, 32, 39, 230),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    ];
  }

  // Builds the Sign-Up screen with responsive design for both small and large screens
  Widget _buildSignUp() {
    // Checks if the current theme is in dark mode
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      key: ValueKey('SignUp'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determines if the screen size is small (typically mobile screens)
          bool isSmallScreen = constraints.maxWidth < 800;

          // Responsive layout: Column for small screens, Row for larger screens
          return isSmallScreen
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _buildSignUpContent(isSmallScreen, isDarkMode),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _buildSignUpContent(isSmallScreen, isDarkMode),
                );
        },
      ),
    );
  }

  // Builds the content for the Sign-Up screen, responsive for both small and large screens
  List<Widget> _buildSignUpContent(bool isSmallScreen, bool isDarkMode) {
    return [
      // Form container
      Container(
        width: isSmallScreen ? double.infinity : 400,
        height: 500,
        padding: EdgeInsets.all(32.0),
        color: isDarkMode
            ? const Color.fromARGB(255, 38, 37, 37)
            : const Color.fromARGB(155, 255, 255, 255),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 16),
            Text(
              'Create Account',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? Colors.white
                    : const Color.fromARGB(243, 173, 21, 211),
              ),
            ),
            SizedBox(height: 24),
            // Name input field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle:
                    TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.blue
                          : const Color.fromARGB(255, 76, 39, 176)),
                ),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
            SizedBox(height: 16),
            // Email input field
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle:
                    TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                border: OutlineInputBorder(),
                errorText: _emailValid ? null : 'Invalid email format',
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: isDarkMode ? Colors.redAccent : Colors.red),
                ),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
            SizedBox(height: 16),
            // Password input field
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle:
                    TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.blue
                          : const Color.fromARGB(255, 76, 39, 176)),
                ),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
            // Sign-Up button
            if (_isLoading)
              CircularProgressIndicator()
            else
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: ElevatedButton(
                  onPressed: _signUp,
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                        color: isDarkMode
                            ? Colors.black
                            : const Color.fromARGB(255, 245, 241, 240)),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    backgroundColor: isDarkMode
                        ? Colors.purple
                        : const Color.fromARGB(223, 205, 108, 230),
                  ),
                ),
              ),
            SizedBox(height: 24),
            // Navigation to Sign-In
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an Account?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.white
                        : const Color.fromARGB(181, 113, 5, 214),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSignIn = true;
                    });
                  },
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.blue
                          : const Color.fromARGB(243, 32, 39, 230),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
      SizedBox(height: isSmallScreen ? 32 : 0),
      // Welcome container
      Container(
        width: isSmallScreen ? double.infinity : 400,
        height: 500,
        color: isDarkMode
            ? const Color.fromARGB(155, 255, 255, 255)
            : const Color.fromARGB(155, 0, 0, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 55),
            Text(
              'Welcome!',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? Colors.black
                      : const Color.fromARGB(223, 216, 226, 231)),
            ),
            SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Text(
                'Enter your personal details and start your journey with us.',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.purple
                        : const Color.fromARGB(223, 205, 108, 230)),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Container(
                width: 290,
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  image: DecorationImage(
                    image: AssetImage('assets/login.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
