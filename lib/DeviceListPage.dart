import 'dart:ui';
import 'package:cloud_sense_webapp/LoginPage.dart';
import 'package:cloud_sense_webapp/buffalodata.dart';
import 'package:cloud_sense_webapp/cowdata.dart';
import 'package:cloud_sense_webapp/manuallyenter.dart';
import 'package:cloud_sense_webapp/map.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'AddDevice.dart';
import 'DeviceGraphPage.dart';
import 'HomePage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

class DataDisplayPage extends StatefulWidget {
  @override
  _DataDisplayPageState createState() => _DataDisplayPageState();
}

class _DataDisplayPageState extends State<DataDisplayPage> {
  bool _isLoading = true;
  Map<String, List<String>> _deviceCategories = {};
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('email');

    try {
      var currentUser = await Amplify.Auth.getCurrentUser();
      if (currentUser.username.trim().toLowerCase() ==
          "05agriculture.05@gmail.com") {
        // Redirect to DeviceInfoPage if this is the special user
        Navigator.pushReplacementNamed(context, '/deviceinfo');
        return; // Exit further execution
      }
      // Else continue on DeviceListPage normally
      setState(() {
        _email = savedEmail ?? currentUser.username;
      });
      _fetchData();
    } catch (e) {
      // No signed-in user — clear prefs & navigate to login screen
      await Amplify.Auth.signOut();
      await prefs.clear();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => SignInSignUpScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _fetchData() async {
    if (_email == null) return;

    final url =
        'https://ln8b1r7ld9.execute-api.us-east-1.amazonaws.com/default/Cloudsense_user_devices?email_id=$_email';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        // Group LU, TE, and AC sensors under a single "CPS Lab Sensors" category
        Map<String, List<String>> groupedDevices = {};

        result.forEach((key, value) {
          if (key != 'device_id' && key != 'email_id') {
            String category = _mapCategory(key);

            // Group LU, TE, and AC sensors under "CPS Lab Sensors"
            if (key == 'LU' || key == 'TE' || key == 'AC') {
              category = 'CPS Lab Sensors';
            }

            if (groupedDevices[category] == null) {
              groupedDevices[category] = [];
            }

            groupedDevices[category]?.addAll(List<String>.from(value ?? []));
          }
        });

        setState(() {
          _deviceCategories = groupedDevices;
        });
      }
    } catch (error) {
      // Handle errors appropriately
      print('Error fetching data: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _mapCategory(String key) {
    switch (key) {
      case 'CL':
      case 'BD':
        return 'Chlorine Sensors';
      case 'WD':
        return 'Weather Sensors';
      case 'SS':
        return 'Soil Sensors';
      case 'WQ':
        return 'Water Quality Sensors';
      case 'DO':
        return 'DO Sensors';
      case 'IT':
        return 'IIT Weather Sensors';
      case 'WS':
        return 'Water Sensors';
      case 'LU':
      case 'TE':
      case 'AC':
        return 'CPS Lab Sensors'; // All grouped under CPS Lab Sensors
      case 'BF':
        return 'Buffalo Sensors';
      case 'CS':
        return 'Cow Sensors';
      case 'TH':
        return 'Temperature Sensors';
      case 'NH':
        return 'Ammonia Sensors';
      case 'FS':
        return 'Forest Sensors';
      case 'SM':
        return 'SSMET Sensors';
      case 'CF':
        return 'Colonel Farm Sensors';
      case 'SV':
        return 'SVPU Sensors';
      case 'CB':
        return 'COD/BOD Sensors';
      default:
        return 'Rain Sensors';
    }
  }

  Future<void> _handleLogout() async {
    try {
      print("[Logout] Starting logout process.");

      await Amplify.Auth.signOut();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print("[Logout] User signed out and preferences cleared.");

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("[Logout] Primary logout failed: $e");
      // Fallback logout
      try {
        await Amplify.Auth.signOut();
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        print("[Logout] Fallback logout success.");

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
          (Route<dynamic> route) => false,
        );
      } catch (logoutError) {
        print("[Logout] Fallback logout failed: $logoutError");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black
                    .withOpacity(0.4), // Optional overlay for readability
              ),
            ),
          ),
          // Main content
          SingleChildScrollView(
            child: Column(
              children: [
                AppBar(
                  title: Text(
                    'Your Chosen Devices',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize:
                          MediaQuery.of(context).size.width < 800 ? 16 : 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  actions: [
                    TextButton.icon(
                      onPressed: _handleLogout,
                      icon: Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: MediaQuery.of(context).size.width < 800 ? 16 : 24,
                      ),
                      label: Text(
                        'Log out',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize:
                              MediaQuery.of(context).size.width < 800 ? 12 : 24,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20), // Add some space below the AppBar
                Center(
                  child: _isLoading
                      ? CircularProgressIndicator()
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Quote Text
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 70.0, left: 16.0, right: 16.0),
                              child: Text(
                                "Select a device to unlock insights into data.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'OpenSans',
                                  fontSize:
                                      MediaQuery.of(context).size.width < 800
                                          ? 30
                                          : 45,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(
                                height:
                                    5), // Space between quote and device cards
                            _deviceCategories.isNotEmpty
                                ? _buildDeviceCards()
                                : _buildNoDevicesCard(),
                            // SizedBox(height: 20),
                            // ElevatedButton.icon(
                            //   onPressed: () {
                            //     Navigator.push(
                            //       context,
                            //       MaterialPageRoute(
                            //         builder: (context) =>
                            //             MapPage(), // Navigate to MapPage
                            //       ),
                            //     );
                            //   },
                            //   icon: Icon(Icons.map),
                            //   label: Text('View Map'),
                            //   style: ElevatedButton.styleFrom(
                            //     padding: EdgeInsets.symmetric(
                            //         horizontal: 20, vertical: 10),
                            //     backgroundColor: Colors.black,
                            //     foregroundColor: Colors.white,
                            //   ),
                            // ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCards() {
    // Separate counters for each sensor type
    int luxSensorCount = 0;
    int tempSensorCount = 0;
    int accelerometerSensorCount = 0;

    List<Widget> cardList = _deviceCategories.keys.map((category) {
      return Container(
        width: 300,
        height: 300,
        margin: EdgeInsets.all(10),
        child: Card(
          color: _getCardColor(category),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 30),
                Text(
                  category,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _deviceCategories[category]?.length ?? 0,
                    itemBuilder: (context, index) {
                      String sensorName = _deviceCategories[category]![index];
                      String sequentialName = '';

                      // Determine the proper sensor name based on the category
                      if (category == 'CPS Lab Sensors') {
                        if (sensorName.contains('LU')) {
                          luxSensorCount++; // Increment Lux sensor count
                          sequentialName = 'Lux Sensor $luxSensorCount';
                        } else if (sensorName.contains('TE')) {
                          tempSensorCount++; // Increment Temperature sensor count
                          sequentialName =
                              'Temperature Sensor $tempSensorCount';
                        } else if (sensorName.contains('AC')) {
                          accelerometerSensorCount++; // Increment Accelerometer sensor count
                          sequentialName =
                              'Accelerometer Sensor $accelerometerSensorCount';
                        }
                      } else {
                        sequentialName =
                            '${category.split(" ").first} Sensor ${index + 1}';
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.black, // Text color
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                          onPressed: () {
                            if (sensorName.startsWith('BF')) {
                              // If sensor starts with 'BF', navigate to BuffaloDataPage
                              String numericNodeId =
                                  sensorName.replaceAll(RegExp(r'\D'), '');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BuffaloData(
                                    startDateTime: DateTime.now(),
                                    endDateTime:
                                        DateTime.now().add(Duration(days: 1)),
                                    nodeId:
                                        numericNodeId, // Pass the sensor ID or name here
                                  ),
                                ),
                              );
                            } else if (sensorName.startsWith('CS')) {
                              // If sensor starts with 'CS', navigate to CowDataPage
                              String numericNodeId =
                                  sensorName.replaceAll(RegExp(r'\D'), '');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CowData(
                                    startDateTime: DateTime.now(),
                                    endDateTime:
                                        DateTime.now().add(Duration(days: 1)),
                                    nodeId:
                                        numericNodeId, // Pass the sensor ID or name here
                                  ),
                                ),
                              );
                            } else {
                              // Otherwise, navigate to DeviceGraphPage
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DeviceGraphPage(
                                    deviceName:
                                        _deviceCategories[category]![index],
                                    sequentialName: sequentialName,
                                    backgroundImagePath:
                                        'assets/backgroundd.jpg',
                                  ),
                                ),
                              );
                            }
                          },
                          child: Text(
                            sequentialName,
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();

    // Add the "Add Devices" button as a card
    cardList.add(
      Container(
        width: 300,
        height: 300,
        margin: EdgeInsets.all(10),
        child: Card(
          color: const Color.fromARGB(255, 167, 158, 172),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Add New Device',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  backgroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QRScannerPage(
                        devices: _deviceCategories,
                      ),
                    ),
                  );
                },
                child: Text(
                  'Scan QR Code',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  backgroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManualEntryPage(
                        devices: _deviceCategories,
                      ),
                    ),
                  );
                },
                child: Text(
                  'Add Manually',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: cardList,
      ),
    );
  }

  Widget _buildNoDevicesCard() {
    return Center(
      child: Container(
        width: 300,
        height: 300,
        margin: EdgeInsets.all(10),
        child: Card(
          color: const Color.fromARGB(255, 167, 158, 172),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // "No devices found." message
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No Device Found',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 235, 28, 28),
                  ),
                ),
              ),
              SizedBox(height: 10),
              // "Add New Device" heading
              Text(
                'Add New Device',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  backgroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QRScannerPage(
                        devices: _deviceCategories,
                      ),
                    ),
                  );
                },
                child: Text(
                  'Scan QR Code',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  backgroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManualEntryPage(
                        devices: _deviceCategories,
                      ),
                    ),
                  );
                },
                child: Text(
                  'Add Manually',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCardColor(String category) {
    switch (category) {
      case 'Chlorine Sensors':
        return const Color.fromARGB(255, 167, 158, 172);
      case 'Weather Sensors':
        return const Color.fromARGB(255, 167, 158, 172);
      case 'Soil Sensors': // Add color for Soil Sensors
        return const Color.fromARGB(255, 167, 158, 172);
      case 'Water Quality Sensors': // Add color for Water Sensors
        return const Color.fromARGB(255, 167, 158, 172);
      case 'Water Sensors': // Add color for Water Sensors
        return const Color.fromARGB(255, 167, 158, 172);
      case 'DO Sensors': // Add color for Water Sensors
        return const Color.fromARGB(255, 167, 158, 172);

      case 'CPS Lab Sensors': // Color for CPS Lab Sensors
        return const Color.fromARGB(255, 167, 158, 172);
      case 'Buffalo Sensors': // Color for CPS Lab Sensors
        return const Color.fromARGB(255, 167, 158, 172);
      case 'Cow Sensors': // Color for CPS Lab Sensors
        return const Color.fromARGB(255, 167, 158, 172);
      case 'Ammonia Sensors': // Color for CPS Lab Sensors
        return const Color.fromARGB(255, 167, 158, 172);
      case 'Temperature Sensors': // Color for CPS Lab Sensors
        return const Color.fromARGB(255, 167, 158, 172);
      case 'SSMET Sensors': // Color for CPS Lab Sensors
        return const Color.fromARGB(255, 167, 158, 172);
      case 'Colonel Farm Sensors': // Color for CPS Lab Sensors
        return const Color.fromARGB(255, 167, 158, 172);
      case 'SVPU Sensors': // Color for CPS Lab Sensors
        return const Color.fromARGB(255, 167, 158, 172);
      case 'COD/BOD Sensors': // Color for CPS Lab Sensors
        return const Color.fromARGB(255, 167, 158, 172);
      default:
        return const Color.fromARGB(255, 167, 158, 172);
    }
  }
}
