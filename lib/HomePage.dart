import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Ensures Flutter bindings are initialized before running the app (needed for async ops like SharedPreferences).
  runApp(
    ChangeNotifierProvider(
      create: (_) =>
          ThemeProvider(), // Provides theme state management across the app.
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Cloud Sense Vis',
      theme: themeProvider.isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: HomePage(),
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode =>
      _isDarkMode; // Getter to access the current theme mode.

  ThemeProvider() {
    _loadTheme(); // Load saved theme preference on initialization.
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode; // Toggle between dark and light modes.
    notifyListeners(); // Notify all listeners about the theme change.

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode); // Save theme preference.
  }

  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode =
        prefs.getBool('isDarkMode') ?? false; // Default to light theme.
    notifyListeners(); // Ensure UI updates after loading saved theme.
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Color _aboutUsColor = const Color.fromARGB(255, 235, 232, 232);
  Color _loginTestColor = const Color.fromARGB(255, 235, 232, 232);
  Color _accountinfoColor = const Color.fromARGB(255, 235, 232, 232);
  // Color _deviceinfoColor = const Color.fromARGB(255, 235, 232, 232);

  Future<void> _handleLoginNavigation() async {
    try {
      var currentUser = await Amplify.Auth.getCurrentUser();
      var userAttributes = await Amplify.Auth.fetchUserAttributes();
      String? email;
      for (var attr in userAttributes) {
        if (attr.userAttributeKey == AuthUserAttributeKey.email) {
          email = attr.value;
          break;
        }
      }
      print('Current user ID: ${currentUser.username}, Email: $email');
      if (email?.trim().toLowerCase() == '05agriculture.05@gmail.com') {
        print('Navigating to MapPage (/deviceinfo)');
        Navigator.pushNamed(context, '/deviceinfo');
      } else {
        print('Navigating to DeviceListPage (/devicelist)');
        Navigator.pushNamed(context, '/devicelist');
      }
    } catch (e) {
      print('No user logged in or error: $e');
      Navigator.pushNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    return LayoutBuilder(builder: (context, constraints) {
      bool isMobile = constraints.maxWidth < 800;
      return Scaffold(
        appBar: AppBar(
          iconTheme: IconThemeData(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          backgroundColor: isDarkMode
              ? const Color.fromARGB(255, 50, 50, 50)
              : const Color.fromARGB(255, 231, 231, 231),
          title: Row(
            children: [
              isMobile ? SizedBox(width: 10) : SizedBox(width: 80),
              Icon(
                Icons.cloud,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              SizedBox(width: isMobile ? 10 : 20),
              Text(
                'Cloud Sense Vis',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 20 : 32,
                ),
              ),
              Spacer(), // Pushes items to the right.
              if (isMobile)
                IconButton(
                  icon: Icon(
                    themeProvider.isDarkMode
                        ? Icons.light_mode
                        : Icons.dark_mode,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () => themeProvider.toggleTheme(),
                ),
              if (!isMobile) ...[
                IconButton(
                  icon: Icon(
                    themeProvider.isDarkMode
                        ? Icons.light_mode
                        : Icons.dark_mode,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () => themeProvider.toggleTheme(),
                ),
                SizedBox(width: 20),
                _buildNavButton('ABOUT US', _aboutUsColor, () {
                  Navigator.pushNamed(context, '/about-us');
                }),
                SizedBox(width: 20),
                _buildNavButton('LOGIN/SIGNUP', _loginTestColor, () {
                  _handleLoginNavigation();
                }),
                SizedBox(width: 20),
                _buildNavButton('ACCOUNT INFO', _accountinfoColor, () {
                  Navigator.pushNamed(context, '/accountinfo');
                }),
                // SizedBox(width: 20),
                // _buildNavButton('DEVICE INFO', _deviceinfoColor, () {
                //   Navigator.pushNamed(context, '/deviceinfo');
                // }),
              ],
            ],
          ),
        ),
        endDrawer: isMobile
            ? Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                      ),
                      child: Text(
                        'Menu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.info),
                      title: Text('ABOUT US'),
                      onTap: () {
                        Navigator.pushNamed(context, '/about-us');
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.login),
                      title: Text('LOGIN/SIGNUP'),
                      onTap: () {
                        _handleLoginNavigation();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.login),
                      title: Text('ACCOUNT INFO'),
                      onTap: () {
                        Navigator.pushNamed(context, '/accountinfo');
                      },
                    ),
                    // ListTile(
                    //   leading: Icon(Icons.login),
                    //   title: Text('DEVICE INFO'),
                    //   onTap: () {
                    //     Navigator.pushNamed(context, '/deviceinfo');
                    //   },
                    // ),
                  ],
                ),
              )
            : null,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Image.asset(
                    'assets/soil.jpg',
                    width: double.infinity,
                    height: MediaQuery.of(context).size.width < 800 ? 400 : 550,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.width < 800 ? 400 : 550,
                    color: Colors.black.withOpacity(0.5),
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(
                      left: MediaQuery.of(context).size.width < 800 ? 20 : 100,
                      top: MediaQuery.of(context).size.width < 800 ? 60 : 120,
                      right:
                          MediaQuery.of(context).size.width < 1000 ? 60 : 400,
                      bottom: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to Cloud Sense Vis',
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: MediaQuery.of(context).size.width < 800
                                ? 30
                                : 65,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0.0),
                          child: Text(
                            "At Cloud Sense Vis, we're dedicated to providing you with real-time data to help you make informed decisions about your surroundings.Our app uses advanced technology to ensure the data is accurate and timely, giving you the insights you need when it matters most. ",
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width < 800
                                  ? 16
                                  : 22,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.justify,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 50),
// "What We Offer" Section
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color.fromARGB(255, 32, 29, 29)
                                : const Color.fromARGB(255, 231, 231, 231),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode
                                    ? const Color.fromARGB(255, 196, 194, 194)
                                    : const Color.fromARGB(255, 32, 29, 29)
                                        .withOpacity(0.4),
                                spreadRadius: 1.5,
                                blurRadius: 5,
                                offset:
                                    Offset(0, 4), // changes position of shadow
                              ),
                              BoxShadow(
                                color: isDarkMode
                                    ? const Color.fromARGB(255, 196, 194, 194)
                                    : const Color.fromARGB(255, 32, 29, 29)
                                        .withOpacity(0.4),
                                spreadRadius: 1.5,
                                blurRadius: 5,
                                offset: Offset(0, -4), // shadow at the top
                              ),
                              BoxShadow(
                                color: isDarkMode
                                    ? const Color.fromARGB(255, 196, 194, 194)
                                    : const Color.fromARGB(255, 32, 29, 29)
                                        .withOpacity(0.4),
                                spreadRadius: 1.5,
                                blurRadius: 5,
                                offset: Offset(-4, 0), // shadow at the left
                              ),
                              BoxShadow(
                                color: isDarkMode
                                    ? const Color.fromARGB(255, 196, 194, 194)
                                    : const Color.fromARGB(255, 32, 29, 29)
                                        .withOpacity(0.4),
                                spreadRadius: 1.5,
                                blurRadius: 5,
                                offset: Offset(4, 0), // shadow at the right
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(60.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'What We Offer?',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Explore the sensors and dive into the live data they capture. With just a tap, you can access detailed insights for each sensor, keeping you informed.\n\nMonitor conditions to ensure a healthy and safe space, detect potential issues, and stay alert for any irregularities. Track various factors to help you plan effectively and contribute to optimizing your usage. Fine-tune your surroundings to prevent potential problems and adjust settings for comfort and efficiency. With all the essential insights at your fingertips, you can create a more comfortable and sustainable living space.',
                                  style: TextStyle(
                                    fontSize:
                                        MediaQuery.of(context).size.width < 800
                                            ? 14
                                            : 20,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              SizedBox(height: 50),
              // "Our Mission" Section
              Stack(
                children: [
                  Image.asset(
                    'assets/weather.png',
                    width: double.infinity,
                    height: MediaQuery.of(context).size.width < 800 ? 400 : 500,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.width < 800 ? 400 : 500,
                    color: Colors.black.withOpacity(0.5),
                    padding: EdgeInsets.fromLTRB(
                      MediaQuery.of(context).size.width < 800 ? 20.0 : 80.0,
                      MediaQuery.of(context).size.width < 800 ? 40.0 : 85.0,
                      MediaQuery.of(context).size.width < 800 ? 20.0 : 90.0,
                      50.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Our Mission',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 800
                                ? 30
                                : 50,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'At Cloud Sense Vis, we aim to revolutionize the way you interact with your surroundings by offering intuitive and seamless monitoring solutions. Our innovative app provides instant access to essential data, giving you the tools to anticipate and respond to changes. With Cloud Sense Vis, you can trust that you’re equipped with the knowledge needed to maintain a safe, healthy, and efficient lifestyle.',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 800
                                ? 14
                                : 24,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 0),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildNavButton(String text, Color color, VoidCallback onPressed) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() {
        if (text == 'ABOUT US') _aboutUsColor = Colors.blue;
        if (text == 'LOGIN/SIGNUP') _loginTestColor = Colors.blue;
        if (text == 'ACCOUNT INFO') _accountinfoColor = Colors.blue;
        // if (text == 'MQTT DATA') _mqttdataColor = Colors.blue;
      }),
      onExit: (_) => setState(() {
        if (text == 'ABOUT US')
          _aboutUsColor = const Color.fromARGB(255, 235, 232, 232);
        if (text == 'LOGIN/SIGNUP')
          _loginTestColor = const Color.fromARGB(255, 235, 232, 232);
        if (text == 'ACCOUNT INFO')
          _accountinfoColor = const Color.fromARGB(255, 235, 232, 232);
        // if (text == 'DEVICE INFO')
        //   _deviceinfoColor = const Color.fromARGB(255, 235, 232, 232);
        // if (text == 'MQTT DATA')
        //   _mqttdataColor = const Color.fromARGB(255, 235, 232, 232);
      }),
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            color:
                isDarkMode ? Colors.white : Colors.black, // Adjust color here
            fontWeight: FontWeight.bold, // Optional for better emphasis
          ),
        ),
      ),
    );
  }
}
