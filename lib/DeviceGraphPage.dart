import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_sense_webapp/downloadcsv.dart';
import 'package:cloud_sense_webapp/push_notifications.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'dart:math' as math;
import 'package:flutter/material.dart';

// Updated CompassNeedlePainter with corrected arrowhead positioning
class CompassNeedlePainter extends CustomPainter {
  CompassNeedlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Define the needle length (60% of radius as per your code)
    final needleLength = radius * 0.4;

    // Paint for the red tip (pointing to wind direction, initially pointing up/North)
    final redPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Paint for the white tail (opposite direction)
    final whitePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Paint for the red arrowhead (filled triangle)
    final arrowPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Draw the red tip (from center to North, will be rotated by Transform.rotate)
    final tipX = center.dx;
    final tipY = center.dy - needleLength; // Pointing up (North)
    canvas.drawLine(center, Offset(tipX, tipY), redPaint);

    // Draw the white tail (from center to South)
    final tailX = center.dx;
    final tailY = center.dy + needleLength; // Pointing down (South)
    canvas.drawLine(center, Offset(tailX, tailY), whitePaint);

    // Draw the arrowhead at the tip of the red line
    final arrowSize = 8.0; // Width of the arrowhead base
    final arrowHeight = 10.0; // Height of the arrowhead (from base to tip)
    final arrowPath = Path();
    // The base of the arrowhead is at the end of the red line (tipX, tipY)
    // Calculate the two base points perpendicular to the needle direction
    // Since the needle points up (North) initially, the direction is along the negative Y-axis
    // Perpendicular direction is along the X-axis (left and right)
    final baseLeft = Offset(tipX - arrowSize / 2, tipY); // Left base point
    final baseRight = Offset(tipX + arrowSize / 2, tipY); // Right base point
    // The tip of the arrowhead extends further in the direction of the red line (upward)
    final arrowTip = Offset(
        tipX, tipY - arrowHeight); // Tip of the arrowhead (further North)
    arrowPath.moveTo(arrowTip.dx, arrowTip.dy); // Tip of the arrow
    arrowPath.lineTo(baseLeft.dx, baseLeft.dy); // Left base
    arrowPath.lineTo(baseRight.dx, baseRight.dy); // Right base
    arrowPath.close(); // Close the triangle
    canvas.drawPath(arrowPath, arrowPaint);

    // Draw a small circle at the center to cover the intersection
    final centerPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CompassBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.black.withOpacity(0.7), Colors.black.withOpacity(0.5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, gradientPaint);

    final innerCirclePaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.8, innerCirclePaint);

    final tickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    final tickLength = 8.0;
    for (int i = 0; i < 360; i += 30) {
      final angle = i * math.pi / 180;
      final startX = center.dx + (radius - tickLength) * math.sin(angle);
      final startY = center.dy - (radius - tickLength) * math.cos(angle);
      final endX = center.dx + radius * math.sin(angle);
      final endY = center.dy - radius * math.cos(angle);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);
    }

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DeviceGraphPage extends StatefulWidget {
  final String deviceName;
  final sequentialName;

  DeviceGraphPage(
      {required this.deviceName,
      required this.sequentialName,
      required String backgroundImagePath});

  @override
  _DeviceGraphPageState createState() => _DeviceGraphPageState();
}

class _DeviceGraphPageState extends State<DeviceGraphPage> {
  DateTime _selectedDay = DateTime.now();
  List<ChartData> temperatureData = [];
  List<ChartData> humidityData = [];
  List<ChartData> lightIntensityData = [];
  List<ChartData> windSpeedData = [];
  List<ChartData> rainLevelData = [];
  List<ChartData> rainDifferenceData = [];
  List<ChartData> solarIrradianceData = [];
  List<ChartData> windDirectionData = [];
  List<ChartData> chlorineData = [];
  List<ChartData> electrodeSignalData = [];
  List<ChartData> hypochlorousData = [];
  List<ChartData> temppData = [];
  List<ChartData> residualchlorineData = [];
  List<ChartData> tempData = [];
  List<ChartData> tdsData = [];
  List<ChartData> codData = [];
  List<ChartData> bodData = [];
  List<ChartData> pHData = [];
  List<ChartData> doData = [];
  List<ChartData> ecData = [];
  List<ChartData> temmppData = [];
  List<ChartData> humidityyData = [];
  List<ChartData> lightIntensityyData = [];
  List<ChartData> windSpeeddData = [];
  List<ChartData> ttempData = [];
  List<ChartData> dovaluedata = [];
  List<ChartData> dopercentagedata = [];
  List<ChartData> temperaturData = [];
  List<ChartData> humData = [];
  List<ChartData> luxData = [];
  List<ChartData> coddata = [];
  List<ChartData> boddata = [];
  List<ChartData> phdata = [];
  List<ChartData> temperattureData = [];
  List<ChartData> humidittyData = [];
  List<ChartData> ammoniaData = [];
  List<ChartData> temperaturedata = [];
  List<ChartData> humiditydata = [];
  List<ChartData> rfdData = [];
  List<ChartData> rfsData = [];
  List<ChartData> ittempData = [];
  List<ChartData> itpressureData = [];
  List<ChartData> ithumidityData = [];
  List<ChartData> itradiationData = [];
  List<ChartData> itwindspeedData = [];
  List<ChartData> itvisibilityData = [];
  List<ChartData> itrainData = [];
  List<ChartData> itwinddirectionData = [];
  List<ChartData> fstempData = [];
  List<ChartData> fspressureData = [];
  List<ChartData> fshumidityData = [];
  List<ChartData> fsradiationData = [];
  List<ChartData> fswindspeedData = [];
  List<ChartData> smwindspeedData = [];
  List<ChartData> smWindDirectionData = [];
  List<ChartData> smAtmPressureData = [];
  List<ChartData> smLightIntensityData = [];
  List<ChartData> smRainfallWeeklyData = [];
  List<ChartData> smMaximumTemperatureData = [];
  List<ChartData> smRainfallDailyData = [];
  List<ChartData> smAverageHumidityData = [];
  List<ChartData> smBatteryVoltageData = [];
  List<ChartData> smAverageTemperatureData = [];
  List<ChartData> smMaximumHumidityData = [];
  List<ChartData> smMinimumTemperatureData = [];
  List<ChartData> smMinimumHumidityData = [];
  List<ChartData> smCurrentHumidityData = [];
  List<ChartData> smRainfallHourlyData = [];
  List<ChartData> smIMEINumberData = [];
  List<ChartData> smRainfallMinutlyData = [];
  List<ChartData> smCurrentTemperatureData = [];
  List<ChartData> smSignalStrength = [];
  Map<String, List<ChartData>> smParametersData = {};
  Map<String, List<ChartData>> cfParametersData = {};
  Map<String, List<ChartData>> svParametersData = {};
  List<ChartData> cod2Data = [];
  List<ChartData> bod2Data = [];
  List<ChartData> temp2Data = [];
  final DateFormat formatter = DateFormat('dd-MM-yyyy HH:mm:ss');

  List<ChartData> fsrainData = [];
  List<ChartData> fswinddirectionData = [];
  Timer? _reloadTimer;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _hasShownAmmoniaNotification =
      false; // To prevent repeated notifications
  double _ammoniaThreshold = 0.0; // Threshold for ammonia alerts

  bool isShiftPressed = false;
  late final FocusNode _focusNode;

  List<Map<String, dynamic>> rainHourlyItems = [];
  List<List<dynamic>> _csvRainRows = [];

  double _precipitationProbability = 0.0;
  List<double> _weeklyPrecipitationData = [];
  int _selectedDeviceId = 0; // Variable to hold the selected device ID
  bool _isHovering = false;
  String? _activeButton;
  String _currentChlorineValue = '0.00';
  String _currentrfdValue = '0.00';
  String _currentAmmoniaValue = '0.00';
  bool _isLoading = false;
  String _lastSelectedRange = 'single'; // Default to single
  bool isWindDirectionValid(String? windDirection) {
    return windDirection != null && windDirection != "-";
  }

  bool iswinddirectionValid(String? direction) {
    print('Validating wind direction: $direction');
    if (direction == null || direction.isEmpty) {
      print('Wind direction invalid: null or empty');
      return false;
    }
    try {
      double value = double.parse(direction);
      bool isValid = value >= 0 && value <= 360;
      print('Wind direction parsed: $value, isValid: $isValid');
      return isValid;
    } catch (e) {
      print('Wind direction invalid: parse error - $e');
      return false;
    }
  }

  // New variables to store rain forecasting data for WD 211
  String _totalRainLast24Hours = '0.00 mm';
  String _mostRecentHourRain = '0.00 mm';

  bool hasNonZeroValues(List<dynamic> data,
      {bool includePrecipitation = true}) {
    // Exclude precipitation from the zero check if `includePrecipitation` is false
    if (includePrecipitation) {
      return data.isNotEmpty && data.any((entry) => entry.value != 0);
    } else {
      return data.isNotEmpty &&
          data.any((entry) =>
              entry.value != 0 && entry.type != 'precipitationProbability');
    }
  }

  @override
  void initState() {
    super.initState();
    requestPermissions();
    _fetchDeviceDetails();
    _fetchDataForRange('single');
    _focusNode = FocusNode();
    _initializeNotifications();

    // Set up the periodic timer to reload data every 30 seconds
    _reloadTimer = Timer.periodic(Duration(seconds: 120), (timer) {
      _reloadData();
    });
  }

  @override
  void dispose() {
    // Cancel the timer to prevent memory leaks
    _reloadTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

// Add this method to initialize notifications
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  // Add this method to show notification
  Future<void> _showAmmoniaAlertNotification(double value) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'ammonia_alerts',
      'Ammonia Alerts',
      channelDescription: 'Alerts for high ammonia values',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'High Ammonia Level Alert',
      'Ammonia level has reached ${value.toStringAsFixed(2)}, exceeding the safe threshold of $_ammoniaThreshold',
      platformChannelSpecifics,
    );
  }

  Future<void> _fetchDeviceDetails() async {
    try {
      final response = await http.get(Uri.parse(
          'https://xa9ry8sls0.execute-api.us-east-1.amazonaws.com/CloudSense_device_activity_api_function'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final devices = data['chloritrone_data'] ?? data['weather_data'] ?? [];
        final selectedDevice = devices.firstWhere(
            (device) => device['DeviceId'] == _selectedDeviceId.toString(),
            orElse: () => null);

        if (selectedDevice != null) {
          setState(() {});
        }
      } else {
        throw Exception('Failed to load device details');
      }
    } catch (e) {
      print('Error fetching device details: $e');
    }
  }

  List<List<dynamic>> _csvRows = [];
  String _lastWindDirection = "";
  String _lastwinddirection = "";
  // String _lastfswinddirection = "";
  String _lastBatteryPercentage = "";
  double _lastfsBattery = 0.0;
  double _lastsmBattery = 0.0;
  double _lastcfBattery = 0.0;
  double _lastsvBattery = 0.0;
  String _lastRSSI_Value = "";

  Future<void> _fetchDataForRange(String range,
      [DateTime? selectedDate, double? latitude, double? longitude]) async {
    setState(() {
      _isLoading = true;
      _csvRows.clear();
      chlorineData.clear();
      temperatureData.clear();
      humidityData.clear();
      lightIntensityData.clear();
      windSpeedData.clear();
      rainLevelData.clear();
      solarIrradianceData.clear();
      windDirectionData.clear();
      electrodeSignalData.clear();
      hypochlorousData.clear();
      temppData.clear();
      residualchlorineData.clear();
      tempData.clear();
      tdsData.clear();
      codData.clear();
      bodData.clear();
      pHData.clear();
      doData.clear();
      ecData.clear();
      temmppData.clear();
      humidityyData.clear();
      lightIntensityyData.clear();
      windSpeeddData.clear();
      ttempData.clear();
      dovaluedata.clear();
      dopercentagedata.clear();
      temperaturData.clear();
      humData.clear();
      luxData.clear();
      ammoniaData.clear();
      temperaturedata.clear();
      humiditydata.clear();
      ittempData.clear();
      itpressureData.clear();
      ithumidityData.clear();
      itradiationData.clear();
      itvisibilityData.clear();
      itrainData.clear();
      itwinddirectionData.clear();
      itwindspeedData.clear();
      fshumidityData.clear();
      fspressureData.clear();
      fsradiationData.clear();
      fsrainData.clear();
      fstempData.clear();
      fswinddirectionData.clear();
      _lastfsBattery = 0.0;
      _lastsmBattery = 0.0;
      _lastcfBattery = 0.0;
      _lastsvBattery = 0.0;

      fswindspeedData.clear();

      smParametersData.clear();
      cfParametersData.clear();
      svParametersData.clear();

      _weeklyPrecipitationData.clear();
    });
    DateTime startDate;
    DateTime endDate = DateTime.now();

    switch (range) {
      case '7days':
        startDate = endDate.subtract(Duration(days: 7));
        break;
      case '30days':
        startDate = endDate.subtract(Duration(days: 30));
        break;
      case '3months':
        startDate = endDate.subtract(Duration(days: 90));
        break;
      case '6months':
        startDate = endDate.subtract(Duration(days: 180));
        break;
      case 'single':
        startDate = _selectedDay; // Use the selected day as startDate
        endDate = startDate;
        print('Selected Day: $_selectedDay');
        print('Start Date: $startDate, End Date: $endDate');

        // Single day means endDate is same as startDate
        break;
      default:
        startDate = endDate; // Default to today
    }

    _lastSelectedRange = range; // Store the currently selected range

    // Format dates for most APIs (DD-MM-YYYY)
    final dateFormatter = DateFormat('dd-MM-yyyy');
    final startdate = dateFormatter.format(startDate);
    final enddate = dateFormatter.format(endDate);

    // Format dates for SM sensor API (YYYYMMDD)
    final smDateFormatter = DateFormat('yyyyMMdd');
    final smStartDate = smDateFormatter.format(startDate);
    final smEndDate = smDateFormatter.format(endDate);

    final DateFormat formatter = DateFormat('dd-MM-yyyy HH:mm:ss');
    int deviceId =
        int.parse(widget.deviceName.replaceAll(RegExp(r'[^0-9]'), ''));

    setState(() {
      _selectedDeviceId = deviceId; // Set the selected device ID
    });
    // Call the additional rain data API for WD211
    if (widget.deviceName == 'WD211') {
      await _fetchRainForecastingData();
    }
    if (widget.deviceName == 'WD511') {
      await _fetchRainForecastData();
    }

    String apiUrl;
    if (widget.deviceName.startsWith('SM')) {
      apiUrl =
          'https://n42fiw7l89.execute-api.us-east-1.amazonaws.com/default/SSMet_API_Func?device_id=$deviceId&start_date=$smStartDate&end_date=$smEndDate';
    } else if (widget.deviceName.startsWith('CF')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/colonelfarmdata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('SV')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/svpudata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('WD')) {
      apiUrl =
          'https://62f4ihe2lf.execute-api.us-east-1.amazonaws.com/CloudSense_Weather_data_api_function?DeviceId=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('CL') ||
        (widget.deviceName.startsWith('BD'))) {
      apiUrl =
          'https://b0e4z6nczh.execute-api.us-east-1.amazonaws.com/CloudSense_Chloritrone_api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
      print(startdate);
    } else if (widget.deviceName.startsWith('WQ')) {
      apiUrl =
          'https://oy7qhc1me7.execute-api.us-west-2.amazonaws.com/default/k_wqm_api?deviceid=${widget.deviceName}&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('IT')) {
      apiUrl =
          'https://7a3bcew3y2.execute-api.us-east-1.amazonaws.com/default/IIT_Bombay_API_func?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('WS')) {
      apiUrl =
          'https://xjbnnqcup4.execute-api.us-east-1.amazonaws.com/default/CloudSense_Water_quality_api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('CB')) {
      apiUrl =
          'https://a9z5vrfpkd.execute-api.us-east-1.amazonaws.com/default/CloudSense_BOD_COD_Api_func?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('FS')) {
      apiUrl =
          'https://w7w21t8s23.execute-api.us-east-1.amazonaws.com/default/SSMet_Forest_API_func?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('DO')) {
      apiUrl =
          'https://br2s08as9f.execute-api.us-east-1.amazonaws.com/default/CloudSense_Water_quality_api_2_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('TH')) {
      apiUrl =
          'https://5s3pangtz0.execute-api.us-east-1.amazonaws.com/default/CloudSense_TH_Data_Api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('NH')) {
      apiUrl =
          'https://qgbwurafri.execute-api.us-east-1.amazonaws.com/default/CloudSense_NH_Data_Api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('LU') ||
        widget.deviceName.startsWith('TE') ||
        widget.deviceName.startsWith('AC')) {
      apiUrl =
          'https://2bftil5o0c.execute-api.us-east-1.amazonaws.com/default/CloudSense_sensor_api_function?DeviceId=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('20')) {
      apiUrl =
          'https://gzdsa7h08k.execute-api.us-east-1.amazonaws.com/default/lat_long_api_func?deviceId=$deviceId';
      print("Device ID: $deviceId");

      try {
        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          print("API Response: ${response.body}");
          // Optional: Parse JSON if needed
          // final jsonData = json.decode(response.body);
          // print("Parsed JSON: $jsonData");
        } else {
          print("Failed to fetch data. Status Code: ${response.statusCode}");
        }
      } catch (e) {
        print("Error during API call: $e");
      }
    } else {
      setState(() {}); // Not sure if needed here
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        List<List<dynamic>> rows = [];
        String lastWindDirection = 'Unknown';
        String lastwinddirection;
        String lastBatteryPercentage = 'Unknown';
        String lastRSSI_Value = 'Unknown';

        if (widget.deviceName.startsWith('SM')) {
          print('SM API Response: ${response.body}');
          setState(() {
            smParametersData.clear();
            smParametersData = _parseSMParametersData(data);
            print('Parsed SM Parameters: $smParametersData');

            if (smParametersData.isEmpty) {
              print('No valid SM parameters found');
              _csvRows = [
                ['Timestamp', 'Message'],
                ['', 'No data available']
              ];
            } else {
              List<String> headers = ['Timestamp'];
              headers.addAll(smParametersData.keys);

              List<List<dynamic>> dataRows = [];
              int maxLength = smParametersData.values
                  .map((list) => list.length)
                  .reduce((a, b) => a > b ? a : b);

              for (int i = 0; i < maxLength; i++) {
                List<dynamic> row = [
                  smParametersData.values.isNotEmpty &&
                          smParametersData.values.first.length > i
                      ? formatter
                          .format(smParametersData.values.first[i].timestamp)
                      : ''
                ];
                for (var key in smParametersData.keys) {
                  var value = smParametersData[key]!.length > i
                      ? smParametersData[key]![i].value
                      : null;
                  // ✅ Preserve 0, replace null with empty string
                  row.add(value ?? '');
                }
                dataRows.add(row);
              }

              _csvRows = [headers, ...dataRows];
              print('✅ CSV Rows Prepared: ${_csvRows.length} rows');
              print('✅ Sample Row: ${_csvRows[1]}');
            }

            // Clear unrelated data
            temperatureData = [];
            humidityData = [];
            // etc...
          });

          // // ✅ Now trigger download
          // downloadCSV(context);
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('CF')) {
          print('CF API Response: ${response.body}');
          setState(() {
            cfParametersData.clear();
            cfParametersData = _parseCFParametersData(data);
            print('Parsed CF Parameters: $cfParametersData');

            if (cfParametersData.isEmpty) {
              print('No valid CF parameters found');
              _csvRows = [
                ['Timestamp', 'Message'],
                ['', 'No data available']
              ];
            } else {
              List<String> headers = ['Timestamp'];
              headers.addAll(cfParametersData.keys);

              List<List<dynamic>> dataRows = [];
              int maxLength = cfParametersData.values
                  .map((list) => list.length)
                  .reduce((a, b) => a > b ? a : b);

              for (int i = 0; i < maxLength; i++) {
                List<dynamic> row = [
                  cfParametersData.values.isNotEmpty &&
                          cfParametersData.values.first.length > i
                      ? formatter
                          .format(cfParametersData.values.first[i].timestamp)
                      : ''
                ];
                for (var key in cfParametersData.keys) {
                  var value = cfParametersData[key]!.length > i
                      ? cfParametersData[key]![i].value
                      : null;
                  // ✅ Preserve 0, replace null with empty string
                  row.add(value ?? '');
                }
                dataRows.add(row);
              }

              _csvRows = [headers, ...dataRows];
              print('✅ CSV Rows Prepared: ${_csvRows.length} rows');
              print('✅ Sample Row: ${_csvRows[1]}');
            }

            // Clear unrelated data
            temperatureData = [];
            humidityData = [];
            // etc...
          });

          // // ✅ Now trigger download
          // downloadCSV(context);
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('SV')) {
          print('SV API Response: ${response.body}');
          setState(() {
            svParametersData.clear();
            svParametersData = _parseSVParametersData(data);
            print('Parsed SV Parameters: $svParametersData');

            if (svParametersData.isEmpty) {
              print('No valid SV parameters found');
              _csvRows = [
                ['Timestamp', 'Message'],
                ['', 'No data available']
              ];
            } else {
              List<String> headers = ['Timestamp'];
              headers.addAll(svParametersData.keys);

              List<List<dynamic>> dataRows = [];
              int maxLength = svParametersData.values
                  .map((list) => list.length)
                  .reduce((a, b) => a > b ? a : b);

              for (int i = 0; i < maxLength; i++) {
                List<dynamic> row = [
                  svParametersData.values.isNotEmpty &&
                          svParametersData.values.first.length > i
                      ? formatter
                          .format(svParametersData.values.first[i].timestamp)
                      : ''
                ];
                for (var key in svParametersData.keys) {
                  var value = svParametersData[key]!.length > i
                      ? svParametersData[key]![i].value
                      : null;
                  // ✅ Preserve 0, replace null with empty string
                  row.add(value ?? '');
                }
                dataRows.add(row);
              }

              _csvRows = [headers, ...dataRows];
              print('✅ CSV Rows Prepared: ${_csvRows.length} rows');
              print('✅ Sample Row: ${_csvRows[1]}');
            }

            // Clear unrelated data
            temperatureData = [];
            humidityData = [];
            // etc...
          });

          // // ✅ Now trigger download
          // downloadCSV(context);
          await _fetchDeviceDetails();
        }

        if (widget.deviceName.startsWith('CL') ||
            widget.deviceName.startsWith('BD')) {
          setState(() {
            chlorineData = _parseBDChartData(data, 'chlorine');
            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];

            // Update current chlorine value
            if (chlorineData.isNotEmpty) {
              _currentChlorineValue =
                  chlorineData.last.value.toStringAsFixed(2);
            }

            // Prepare data for CSV

            rows = [
              ["Timestamp", "Chlorine"],
              ...chlorineData.map(
                  (entry) => [formatter.format(entry.timestamp), entry.value])
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('WQ')) {
          setState(() {
            tempData = _parseWaterChartData(data, 'temperature');
            tdsData = _parseWaterChartData(data, 'TDS');
            codData = _parseWaterChartData(data, 'COD');
            bodData = _parseWaterChartData(data, 'BOD');
            pHData = _parseWaterChartData(data, 'pH');
            doData = _parseWaterChartData(data, 'DO');
            ecData = _parseWaterChartData(data, 'EC');
            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];

            rows = [
              [
                "Timestamp",
                "temperature",
                "TDS ",
                "COD",
                "BOD",
                "pH",
                "DO",
                "EC"
              ],
              for (int i = 0; i < tempData.length; i++)
                [
                  formatter.format(tempData[i].timestamp),
                  tempData[i].value,
                  tdsData[i].value,
                  codData[i].value,
                  bodData[i].value,
                  pHData[i].value,
                  doData[i].value,
                  ecData[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('CB')) {
          setState(() {
            print('Items in response: ${data['items']}');
            temp2Data = _parseCBChartData(data, 'temperature');

            cod2Data = _parseCBChartData(data, 'COD');
            bod2Data = _parseCBChartData(data, 'BOD');

            rows = [
              [
                "Timestamp",
                "temperature",
                "COD",
                "BOD",
              ],
              for (int i = 0; i < temp2Data.length; i++)
                [
                  formatter.format(temp2Data[i].timestamp),
                  temp2Data[i].value,
                  cod2Data[i].value,
                  bod2Data[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('IT')) {
          setState(() {
            print('Processing IT device data');
            print('Items in response: ${data['items']}');
            ittempData = _parseITChartData(data, 'temperature');
            itpressureData = _parseITChartData(data, 'pressure');
            ithumidityData = _parseITChartData(data, 'humidity');
            itradiationData = _parseITChartData(data, 'radiation');
            itrainData = _parseITChartData(data, 'rain_level');
            itvisibilityData = _parseITChartData(data, 'visibility');
            itwinddirectionData = _parseITChartData(data, 'wind_direction');
            itwindspeedData = _parseITChartData(data, 'wind_speed');
            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];

            // Assign _lastWindDirection from the latest item
            if (data.containsKey('items') &&
                data['items'] is List &&
                data['items'].isNotEmpty) {
              var lastItem = data['items'].last;
              print('Last item: $lastItem');
              print(
                  'wind_direction in last item: ${lastItem['wind_direction']}');
              _lastwinddirection =
                  lastItem['wind_direction']?.toString() ?? '0';
              print('Assigned _lastWindDirection: $_lastwinddirection');
            } else {
              _lastwinddirection = '0';
              print('No valid items in data, setting _lastWindDirection to 0');
            }
            rows = [
              [
                "Timestamp",
                "Temperature",
                "Pressure ",
                "Humidity",
                "Radiation",
                "Visibility",
                "Wind Direction",
                "Wind Speed"
              ],
              for (int i = 0; i < ittempData.length; i++)
                [
                  formatter.format(ittempData[i].timestamp),
                  ittempData[i].value,
                  itpressureData[i].value,
                  ithumidityData[i].value,
                  itradiationData[i].value,
                  itvisibilityData[i].value,
                  itwinddirectionData[i].value,
                  itwindspeedData[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('WS')) {
          setState(() {
            print('Items in response: ${data['items']}');
            temppData = _parsewaterChartData(data, 'Temperature');
            electrodeSignalData =
                _parsewaterChartData(data, 'Electrode_signal');
            residualchlorineData = _parsewaterChartData(data, 'Chlorine_value');
            hypochlorousData = _parsewaterChartData(data, 'Hypochlorous_value');

            // temperatureData = [];
            // humidityData = [];
            // lightIntensityData = [];
            // windSpeedData = [];
            // rainLevelData = [];
            // solarIrradianceData = [];
            // chlorineData = [];

            rows = [
              [
                "Timestamp",
                "Temperature",
                "Electrode Signal ",
                "Chlorine",
                "HypochlorouS",
              ],
              for (int i = 0; i < temppData.length; i++)
                [
                  formatter.format(temppData[i].timestamp),
                  temppData[i].value,
                  electrodeSignalData[i].value,
                  residualchlorineData[i].value,
                  hypochlorousData[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('DO')) {
          setState(() {
            ttempData = _parsedoChartData(data, 'Temperature');
            dovaluedata = _parsedoChartData(data, 'DO Value');
            dopercentagedata = _parsedoChartData(data, 'DO Percentage');

            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];
            temmppData = [];
            humidityyData = [];
            lightIntensityData = [];
            windSpeeddData = [];

            rows = [
              [
                "Timestamp",
                "Temperature",
                "DO Value ",
                "DO Percentage",
              ],
              for (int i = 0; i < ttempData.length; i++)
                [
                  formatter.format(ttempData[i].timestamp),
                  ttempData[i].value,
                  dovaluedata[i].value,
                  dopercentagedata[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('TH')) {
          setState(() {
            temperattureData = _parsethChartData(data, 'Temperature');
            humidittyData = _parsethChartData(data, 'Humidity');

            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];
            temmppData = [];
            humidityyData = [];
            lightIntensityData = [];
            windSpeeddData = [];

            rows = [
              [
                "Timestamp",
                "Temperature",
                "Humidity ",
              ],
              for (int i = 0; i < temperattureData.length; i++)
                [
                  formatter.format(temperattureData[i].timestamp),
                  temperattureData[i].value,
                  humidittyData[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('NH')) {
          setState(() {
            ammoniaData = _parseammoniaChartData(data, 'AmmoniaPPM');
            temperaturedata = _parseammoniaChartData(data, 'Temperature');
            humiditydata = _parseammoniaChartData(data, 'Humidity');

            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];
            electrodeSignalData = [];
            hypochlorousData = [];
            temppData = [];
            residualchlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];
            temmppData = [];
            humidityyData = [];
            lightIntensityData = [];
            windSpeeddData = [];
            ttempData = [];
            dovaluedata = [];
            dopercentagedata = [];
            temperaturData = [];
            humData = [];
            luxData = [];
            coddata = [];
            boddata = [];
            phdata = [];
            temperattureData = [];
            humidittyData = [];

            // if (ammoniaData.isNotEmpty) {
            //   _currentAmmoniaValue = ammoniaData.last.value.toStringAsFixed(2);
            // }
// Update ammonia value and check threshold
            // Check if ammonia value exceeds 25 ppm and trigger notification
            // if (ammoniaData.isNotEmpty) {
            //   double currentAmmoniaValue = ammoniaData.last.value;
            //   if (currentAmmoniaValue > 0) {
            //     // Trigger the notification when ammonia level exceeds 25 ppm
            //     PushNotifications()
            //         .sendAmmoniaAlertNotification(currentAmmoniaValue);
            //   }
            // }

            rows = [
              [
                "Timestamp",
                "Ammonia",
                "Temperature",
                "Humidity ",
              ],
              for (int i = 0; i < ammoniaData.length; i++)
                [
                  formatter.format(ammoniaData[i].timestamp),
                  ammoniaData[i].value,
                  temperaturedata[i].value,
                  humiditydata[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('TE')) {
          setState(() {
            temperaturData = _parsesensorChartData(data, 'Temperature');
            humData = _parsesensorChartData(data, 'Humidity');

            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];
            temmppData = [];
            humidityyData = [];
            lightIntensityData = [];
            windSpeeddData = [];

            if (data['sensor_data_items'].isNotEmpty) {
              lastRSSI_Value =
                  data['sensor_data_items'].last['RSSI_Value']?.toString() ??
                      'Unknown';
            }

            rows = [
              [
                "Timestamp",
                "Temperature",
                "Humidity",
              ],
              for (int i = 0; i < temperaturData.length; i++)
                [
                  formatter.format(temperaturData[i].timestamp),
                  temperaturData[i].value,
                  humData[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('LU')) {
          setState(() {
            luxData = _parsesensorChartData(data, 'LUX');

            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];
            temmppData = [];
            humidityyData = [];
            lightIntensityData = [];
            windSpeeddData = [];

            rows = [
              [
                "Timestamp",
                "LUX",
              ],
              for (int i = 0; i < luxData.length; i++)
                [
                  formatter.format(luxData[i].timestamp),
                  luxData[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('FS')) {
          setState(() {
            fstempData = _parsefsChartData(data, 'temperature');
            fspressureData = _parsefsChartData(data, 'pressure');
            fshumidityData = _parsefsChartData(data, 'humidity');
            fsradiationData = _parsefsChartData(data, 'radiation');
            fsrainData = _parsefsChartData(data, 'rain_level');
            fswinddirectionData = _parsefsChartData(data, 'wind_direction');
            fswindspeedData = _parsefsChartData(data, 'wind_speed');

            // //Extract the last wind direction from the data
            // if (data['weather_items'].isNotEmpty) {
            //   lastWindDirection = data['weather_items'].last['WindDirection'];
            //   lastBatteryPercentage =
            //       data['weather_items'].last['BatteryPercentage'];
            // }
            // Assign _lastWindDirection from the latest item
            if (data.containsKey('items') &&
                data['items'] is List &&
                data['items'].isNotEmpty) {
              var lastItem = data['items'].last;

              print('Last item: $lastItem');
              print('Last item keys: ${lastItem.keys}');

              // _lastfswinddirection =
              //     lastItem['wind_direction']?.toString() ?? '0';

              var batteryVoltage = lastItem['battery_voltage'];
              if (batteryVoltage != null) {
                _lastfsBattery =
                    double.tryParse(batteryVoltage.toString()) ?? 0.0;
                print('Battery Voltage: $_lastfsBattery V');
              } else {
                _lastfsBattery = 0;
                print('No battery_voltage found, defaulting to 0.0');
              }
            }

            // Prepare data for CSV
            rows = [
              [
                "Timestamp",
                "Temperature",
                "Pressure ",
                "relative Humidity",
                "Radiation",
                "Wind Speed",
                "Wind Direction",
              ],
              for (int i = 0; i < fstempData.length; i++)
                [
                  formatter.format(fstempData[i].timestamp),
                  fstempData[i].value,
                  fspressureData[i].value,
                  fshumidityData[i].value,
                  fsradiationData[i].value,
                  fswindspeedData[i].value,
                  fswinddirectionData[i].value,
                ]
            ];
          });
          // Fetch device details specifically for Weather data
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('WD')) {
          setState(() {
            temperatureData = _parseChartData(data, 'Temperature');
            humidityData = _parseChartData(data, 'Humidity');
            lightIntensityData = _parseChartData(data, 'LightIntensity');
            windSpeedData = _parseChartData(data, 'WindSpeed');
            rainDifferenceData = _parseRainDifferenceData(data);
            solarIrradianceData = _parseChartData(data, 'SolarIrradiance');

            chlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];

            //Extract the last wind direction from the data
            if (data['weather_items'].isNotEmpty) {
              lastWindDirection = data['weather_items'].last['WindDirection'];
              lastBatteryPercentage =
                  data['weather_items'].last['BatteryPercentage'];
            }

            // Prepare data for CSV
            rows = [
              [
                "Timestamp",
                "Temperature",
                "Humidity",
                "LightIntensity",
                "SolarIrradiance",
              ],
              for (int i = 0; i < temperatureData.length; i++)
                [
                  formatter.format(temperatureData[i].timestamp),
                  temperatureData[i].value,
                  humidityData[i].value,
                  lightIntensityData[i].value,
                  solarIrradianceData[i].value,
                ]
            ];
          });
          // Fetch device details specifically for Weather data
          await _fetchDeviceDetails();
        } else {
          setState(() {
            rfdData = _parserainChartData(data, 'RFD');
            rfsData = _parserainChartData(data, 'RFS');

            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];
            temmppData = [];
            humidityyData = [];
            lightIntensityData = [];
            windSpeeddData = [];

            // Update current chlorine value
            if (rfdData.isNotEmpty) {
              _currentrfdValue = rfdData.last.value.toStringAsFixed(2);
            }

            // rows = [
            //   [
            //     "Timestamp",
            //     "RFD ",
            //     "RFS ",
            //   ],
            //   for (int i = 0; i < rfdData.length; i++)
            //     [
            //       formatter.format(rfdData[i].timestamp),
            //       rfdData[i].value,
            //       rfsData[i].value,
            //     ]
            // ];
          });
          await _fetchDeviceDetails();
        }

        // Store CSV rows for download later
        setState(() {
          // Only set _csvRows for sensors other than SM and CF
          if (!widget.deviceName.startsWith('SM') &&
              !widget.deviceName.startsWith('CF') &&
              !widget.deviceName.startsWith('SV')) {
            _csvRows = rows;
          }
          _lastWindDirection =
              lastWindDirection; // Store the last wind direction
          _lastBatteryPercentage = lastBatteryPercentage;
          _lastRSSI_Value = lastRSSI_Value;
          // _lastwinddirection = lastwinddirection;

          if (_csvRows.isEmpty) {
          } else {}
        });
      }
    } catch (e) {
      setState(() {});
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void downloadCSV(BuildContext context, {DateTimeRange? range}) async {
    List<List<dynamic>> csvRows;

    if (widget.deviceName.startsWith('SM')) {
      if (smParametersData.isEmpty) {
        csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available']
        ];
      } else {
        List<String> headers = ['Timestamp'];
        headers.addAll(smParametersData.keys);

        List<List<dynamic>> dataRows = [];
        Set<DateTime> timestamps = {};
        smParametersData.values.forEach((dataList) {
          dataList.forEach((data) => timestamps.add(data.timestamp));
        });
        List<DateTime> sortedTimestamps = timestamps.toList()..sort();
        print('Sorted Timestamps for SM CSV Download: $sortedTimestamps');

        for (var timestamp in sortedTimestamps) {
          List<dynamic> row = [formatter.format(timestamp)];
          for (var key in smParametersData.keys) {
            var dataList = smParametersData[key]!;
            var matchingData = dataList.firstWhere(
              (data) => data.timestamp == timestamp,
              orElse: () => ChartData(timestamp: timestamp, value: 0.0),
            );
            row.add(matchingData.value ?? '');
          }
          dataRows.add(row);
        }

        csvRows = [headers, ...dataRows];
        print('✅ CSV Rows for SM Download: ${csvRows.length} rows');
        print('✅ Sample Row for SM Download: ${csvRows[1]}');
      }
    } else if (widget.deviceName.startsWith('CF')) {
      if (cfParametersData.isEmpty) {
        csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available']
        ];
      } else {
        List<String> headers = ['Timestamp'];
        headers.addAll(cfParametersData.keys);

        List<List<dynamic>> dataRows = [];
        Set<DateTime> timestamps = {};
        cfParametersData.values.forEach((dataList) {
          dataList.forEach((data) => timestamps.add(data.timestamp));
        });
        List<DateTime> sortedTimestamps = timestamps.toList()..sort();
        print('Sorted Timestamps for CF CSV Download: $sortedTimestamps');

        for (var timestamp in sortedTimestamps) {
          List<dynamic> row = [formatter.format(timestamp)];
          for (var key in cfParametersData.keys) {
            var dataList = cfParametersData[key]!;
            var matchingData = dataList.firstWhere(
              (data) => data.timestamp == timestamp,
              orElse: () => ChartData(timestamp: timestamp, value: 0.0),
            );
            row.add(matchingData.value ?? '');
          }
          dataRows.add(row);
        }

        csvRows = [headers, ...dataRows];
        print('✅ CSV Rows for CF Download: ${csvRows.length} rows');
        print('✅ Sample Row for CF Download: ${csvRows[1]}');
      }
    } else if (widget.deviceName.startsWith('SV')) {
      if (svParametersData.isEmpty) {
        csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available']
        ];
      } else {
        List<String> headers = ['Timestamp'];
        headers.addAll(svParametersData.keys);

        List<List<dynamic>> dataRows = [];
        Set<DateTime> timestamps = {};
        svParametersData.values.forEach((dataList) {
          dataList.forEach((data) => timestamps.add(data.timestamp));
        });
        List<DateTime> sortedTimestamps = timestamps.toList()..sort();
        print('Sorted Timestamps for SV CSV Download: $sortedTimestamps');

        for (var timestamp in sortedTimestamps) {
          List<dynamic> row = [formatter.format(timestamp)];
          for (var key in svParametersData.keys) {
            var dataList = svParametersData[key]!;
            var matchingData = dataList.firstWhere(
              (data) => data.timestamp == timestamp,
              orElse: () => ChartData(timestamp: timestamp, value: 0.0),
            );
            row.add(matchingData.value ?? '');
          }
          dataRows.add(row);
        }

        csvRows = [headers, ...dataRows];
        print('✅ CSV Rows for SV Download: ${csvRows.length} rows');
        print('✅ Sample Row for SV Download: ${csvRows[1]}');
      }
    } else if (widget.deviceName.startsWith('WD211') ||
        widget.deviceName.startsWith('WD511')) {
      if (rfdData.isEmpty || rfsData.isEmpty) {
        csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available']
        ];
      } else {
        csvRows = [
          ["Timestamp", "RFD ", "RFS "],
          for (int i = 0; i < rfdData.length; i++)
            [
              formatter.format(rfdData[i].timestamp),
              rfdData[i].value,
              rfsData[i].value,
            ]
        ];
        print('✅ CSV Rows for Rain Forecast Download: ${csvRows.length} rows');
        print('✅ Sample Row for Rain Forecast Download: ${csvRows[1]}');
      }
    } else {
      // Use _csvRows for other sensors (CL, BD, WQ, IT, WS, DO, TH, NH, TE, LU, FS, WD, etc.)
      if (_csvRows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No data available for download.")),
        );
        return;
      }
      csvRows = _csvRows;
      print('Using _csvRows for Download: ${csvRows.length} rows');
    }

    String csvData = const ListToCsvConverter().convert(csvRows);
    String fileName = _generateFileName();

    if (kIsWeb) {
      final blob = html.Blob([csvData], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Downloading"),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      try {
        await saveCSVFile(csvData, fileName);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error downloading: $e")),
        );
      }
    }
  }

  String _generateFileName() {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'SensorData_$timestamp.csv';
  }

  Future<void> saveCSVFile(String csvData, String fileName) async {
    try {
      // Get the Downloads directory.
      final downloadsDirectory = Directory('/storage/emulated/0/Download');
      if (downloadsDirectory.existsSync()) {
        final filePath = '${downloadsDirectory.path}/$fileName';
        final file = File(filePath);

        await file.writeAsString(csvData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("File downloaded to $filePath"),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to find Downloads directory")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving file: $e")),
      );
    }
  }

  Future<void> _fetchRainForecastingData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://w6dzlucugb.execute-api.us-east-1.amazonaws.com/default/CloudSense_rain_data_api?DeviceId=211'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _totalRainLast24Hours =
              data['TotalRainLast24Hours']?.toString() ?? '0.00 mm';
          _mostRecentHourRain =
              data['MostRecentHourRain']?.toString() ?? '0.00 mm';
        });
      } else {
        throw Exception('Failed to load rain forecasting data');
      }
    } catch (e) {
      print('Error fetching rain forecasting data: $e');
    }
  }

  Future<void> _fetchRainForecastData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://w6dzlucugb.execute-api.us-east-1.amazonaws.com/default/CloudSense_rain_data_api?DeviceId=511'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _totalRainLast24Hours =
              data['TotalRainLast24Hours']?.toString() ?? '0.00 mm';
          _mostRecentHourRain =
              data['MostRecentHourRain']?.toString() ?? '0.00 mm';
        });
      } else {
        throw Exception('Failed to load rain forecasting data');
      }
    } catch (e) {
      print('Error fetching rain forecasting data: $e');
    }
  }

  Future<void> _showDownloadOptionsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Download Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  downloadCSV(context);
                },
                child: const Text('Download for Selected Range'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CsvDownloader(
                              deviceName: widget.deviceName,
                            )),
                  );
                },
                child: const Text('Download for Custom Range'),
              ),
            ],
          ),
        );
      },
    );
  }

  List<ChartData> _parseBDChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parseBDDate(item['human_time']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parseChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['weather_items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }

      // Parse the value based on the `type`
      double value;
      if (type == 'RainLevel' && item[type] is String) {
        // Remove unit from RainLevel string and parse the numeric part
        String rainLevelStr =
            item[type].split(' ')[0]; // Extract "2.51" from "2.51 mm"
        value = double.tryParse(rainLevelStr) ?? 0.0;
      } else {
        // For other types, parse directly
        value = double.tryParse(item[type].toString()) ?? 0.0;
      }

      return ChartData(
        timestamp: _parseDate(item['HumanTime']),
        value: value,
      );
    }).toList();
  }

  List<ChartData> _parseRainDifferenceData(Map<String, dynamic> data) {
    final List<dynamic> items = data['rain_hourly_items'] ?? [];

    return items.map((item) {
      if (item == null) {
        return ChartData(
            timestamp: DateTime.now(), value: 0.0); // Default value
      }

      // Extract and parse RainDifference value, removing unit "mm"
      String rainDifferenceStr = item['RainDifference'].split(' ')[0];
      double rainDifferenceValue = double.tryParse(rainDifferenceStr) ?? 0.0;

      return ChartData(
        timestamp: DateTime.parse(item['HourTimestamp']),
        value: rainDifferenceValue,
      );
    }).toList();
  }

  List<ChartData> _parsewaterChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    final result = items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      String valueStr = item[type]?.toString().split(' ')[0] ?? '0.0';
      double value = double.tryParse(valueStr) ?? 0.0;
      DateTime timestamp = _parsewaterDate(item['HumanTime']);
      print('Parsed $type: timestamp=$timestamp, value=$value');
      return ChartData(
        timestamp: timestamp,
        value: value,
      );
    }).toList();
    print('Parsed $type data: $result');
    return result;
  }

  List<ChartData> _parseITChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parseITDate(item['human_time']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parsefsChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parsefsDate(item['timestamp']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  Map<String, List<ChartData>> _parseSMParametersData(
      Map<String, dynamic> data) {
    final List<dynamic> items = data['items'] ?? [];
    Map<String, List<ChartData>> parametersData = {};
    print('SM API Items Count: ${items.length}'); // Debug

    if (items.isEmpty) {
      print('No items in SM API response');
      return parametersData;
    }

    // Collect all possible parameter keys from the first item, excluding non-numeric fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      // Exclude non-numeric fields like TimeStamp, TimeStampFormatted, Topic, IMEINumber, DeviceId
      return ![
        'TimeStamp',
        'TimeStampFormatted',
        'Topic',
        'IMEINumber',
        'DeviceId'
      ].contains(key);
    }).toList();

    // Initialize ChartData lists for each parameter
    for (var key in parameterKeys) {
      parametersData[key] = [];
    }

    // Parse data for each item
    for (var item in items) {
      if (item == null) continue;
      DateTime timestamp = _parseSMDate(item['TimeStamp']);
      for (var key in parameterKeys) {
        if (item[key] != null) {
          // Only include non-null values
          double value = double.tryParse(item[key].toString()) ?? 0.0;
          parametersData[key]!
              .add(ChartData(timestamp: timestamp, value: value));
        }
      }
    }
    // Update _lastsmBattery with the latest BatteryVoltage (from the last item)
    for (var item in items.reversed) {
      if (item != null && item['BatteryVoltage'] != null) {
        _lastsmBattery =
            double.tryParse(item['BatteryVoltage'].toString()) ?? 0.0;
        print('Updated _lastsmBattery: $_lastsmBattery V'); // Debug
        break; // Exit after finding the latest non-null value
      }
    }

    // Remove parameters with empty lists (i.e., all values were null)
    parametersData.removeWhere((key, value) => value.isEmpty);
    print('Parsed SM Parameters: ${parametersData.keys.join(', ')}'); // Debug

    return parametersData;
  }

  Map<String, List<ChartData>> _parseCFParametersData(
      Map<String, dynamic> data) {
    final List<dynamic> items = data['items'] ?? [];
    Map<String, List<ChartData>> parametersData = {};
    print('CF API Items Count: ${items.length}'); // Debug

    if (items.isEmpty) {
      print('No items in CF API response');
      return parametersData;
    }

    // Collect all possible parameter keys from the first item, excluding non-numeric fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      // Exclude non-numeric fields like TimeStamp, Topic, IMEINumber, DeviceId, Latitude, Longitude
      return ![
        'TimeStamp',
        'Topic',
        'IMEINumber',
        'DeviceId',
        'Latitude',
        'Longitude'
      ].contains(key);
    }).toList();

    // Initialize ChartData lists for each parameter
    for (var key in parameterKeys) {
      parametersData[key] = [];
    }

    // Parse data for each item
    for (var item in items) {
      if (item == null) continue;
      DateTime timestamp = _parseCFDate(item['TimeStamp']);
      for (var key in parameterKeys) {
        if (item[key] != null) {
          // Only include non-null values
          double value = double.tryParse(item[key].toString()) ?? 0.0;
          parametersData[key]!
              .add(ChartData(timestamp: timestamp, value: value));
        }
      }
    }

    // Update _lastcfBattery with the latest BatteryVoltage (from the last item)
    for (var item in items.reversed) {
      if (item != null && item['BatteryVoltage'] != null) {
        _lastcfBattery =
            double.tryParse(item['BatteryVoltage'].toString()) ?? 0.0;
        print('Updated _lastcfBattery: $_lastcfBattery V'); // Debug
        break; // Exit after finding the latest non-null value
      }
    }

    // Remove parameters with empty lists (i.e., all values were null)
    parametersData.removeWhere((key, value) => value.isEmpty);
    print('Parsed CF Parameters: ${parametersData.keys.join(', ')}'); // Debug

    return parametersData;
  }

  Map<String, List<ChartData>> _parseSVParametersData(
      Map<String, dynamic> data) {
    final List<dynamic> items = data['items'] ?? [];
    Map<String, List<ChartData>> parametersData = {};
    print('SV API Items Count: ${items.length}'); // Debug

    if (items.isEmpty) {
      print('No items in SV API response');
      return parametersData;
    }

    // Collect all possible parameter keys from the first item, excluding non-numeric fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      // Exclude non-numeric fields like TimeStamp, Topic, IMEINumber, DeviceId, Latitude, Longitude
      return ![
        'TimeStamp',
        'Topic',
        'IMEINumber',
        'DeviceId',
        'Latitude',
        'Longitude'
      ].contains(key);
    }).toList();

    // Initialize ChartData lists for each parameter
    for (var key in parameterKeys) {
      parametersData[key] = [];
    }

    // Parse data for each item
    for (var item in items) {
      if (item == null) continue;
      DateTime timestamp = _parseSVDate(item['TimeStamp']);
      for (var key in parameterKeys) {
        if (item[key] != null) {
          // Only include non-null values
          double value = double.tryParse(item[key].toString()) ?? 0.0;
          parametersData[key]!
              .add(ChartData(timestamp: timestamp, value: value));
        }
      }
    }

    // Update _lastsvBattery with the latest BatteryVoltage (from the last item)
    for (var item in items.reversed) {
      if (item != null && item['BatteryVoltage'] != null) {
        _lastsvBattery =
            double.tryParse(item['BatteryVoltage'].toString()) ?? 0.0;
        print('Updated _lastsvBattery: $_lastsvBattery V'); // Debug
        break; // Exit after finding the latest non-null value
      }
    }

    // Remove parameters with empty lists (i.e., all values were null)
    parametersData.removeWhere((key, value) => value.isEmpty);
    print('Parsed SV Parameters: ${parametersData.keys.join(', ')}'); // Debug

    return parametersData;
  }

  List<ChartData> _parsesensorChartData(
      Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['sensor_data_items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parsesensorDate(item['HumanTime']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parsewindChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parsewindDate(item['human_time']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parsedoChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parsedoDate(item['HumanTime']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parsethChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parsethDate(item['HumanTime']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parseammoniaChartData(
      Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parseammoniaDate(item['HumanTime']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parseWaterChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parseWaterDate(item['time_stamp']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parseCBChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parseCBDate(item['human_time']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parserainChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parserainDate(item['human_time']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

// Calculate average, min, and max values
  Map<String, List<double?>> _calculateStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        // 'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    // double sum = 0.0;
    double? current = data.last.value;
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }

    return {
      'current': [current],
      'min': [min],
      'max': [max],
    };
  }

  // Create a table displaying statistics
  Widget buildStatisticsTable() {
    final tempStats = _calculateStatistics(tempData);
    final tdsStats = _calculateStatistics(tdsData);
    final codStats = _calculateStatistics(codData);
    final bodStats = _calculateStatistics(bodData);
    final pHStats = _calculateStatistics(pHData);
    final doStats = _calculateStatistics(doData);
    final ecStats = _calculateStatistics(ecData);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 16 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
            ),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Text(
                    'Parameter',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Current',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Min',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Max',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                buildDataRow('Temp', tempStats, fontSize),
                buildDataRow('TDS', tdsStats, fontSize),
                buildDataRow('COD', codStats, fontSize),
                buildDataRow('BOD', bodStats, fontSize),
                buildDataRow('pH', pHStats, fontSize),
                buildDataRow('DO', doStats, fontSize),
                buildDataRow('EC', ecStats, fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow buildDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['min']?[0] != null ? stats['min']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['max']?[0] != null ? stats['max']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

// Calculate average, min, and max values
  Map<String, List<double?>> _calculateCBStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        // 'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    // double sum = 0.0;
    double? current = data.last.value;
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }

    return {
      'current': [current],
      'min': [min],
      'max': [max],
    };
  }

  // Create a table displaying statistics
  Widget buildCBStatisticsTable() {
    final temp2Stats = _calculateCBStatistics(temp2Data);

    final cod2Stats = _calculateCBStatistics(cod2Data);
    final bod2Stats = _calculateCBStatistics(bod2Data);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 16 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
            ),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Text(
                    'Parameter',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Current',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Min',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Max',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                buildCBDataRow('Temp', temp2Stats, fontSize),
                buildCBDataRow('COD', cod2Stats, fontSize),
                buildCBDataRow('BOD', bod2Stats, fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow buildCBDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['min']?[0] != null ? stats['min']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['max']?[0] != null ? stats['max']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

// Calculate average, min, and max values
  Map<String, List<double?>> _calculateDOStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        // 'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    // double sum = 0.0;
    double? current = data.last.value; // Get the most recent (current) value
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      // sum += entry.value;
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }

    // double avg = data.isNotEmpty ? sum / data.length : 0.0;
    return {
      // 'average': [avg],
      'current': [current], // Return the last (current) value
      'min': [min],
      'max': [max],
    };
  }

  // Create a table displaying statistics
  Widget buildDOStatisticsTable() {
    final ttempStats = _calculateDOStatistics(ttempData);
    final dovalueStats = _calculateDOStatistics(dovaluedata);
    final dopercentageStats = _calculateDOStatistics(dopercentagedata);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 16 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
            ),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Text(
                    'Parameter',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Recent Value',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Min',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Max',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                buildDataRow('Temperature', ttempStats, fontSize),
                buildDataRow('DO Value', dovalueStats, fontSize),
                buildDataRow('DO Percentage', dopercentageStats, fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow buildDODataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['min']?[0] != null ? stats['min']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['max']?[0] != null ? stats['max']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

  Map<String, List<double?>> _calculateWeatherStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        'current': [null],
      };
    }

    double? current = data.last.value; // Get the most recent (current) value

    return {
      'current': [current], // Return the last (current) value
    };
  }

  Widget buildWeatherStatisticsTable() {
    final temperatureStats = _calculateWeatherStatistics(temperatureData);
    final humidityStats = _calculateWeatherStatistics(humidityData);
    final lightIntensityStats = _calculateWeatherStatistics(lightIntensityData);
    final solarIrradianceStats =
        _calculateWeatherStatistics(solarIrradianceData);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 18 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Centered heading for the table
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Center(
                child: Text(
                  'Data',
                  style: TextStyle(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
                ),
                child: DataTable(
                  horizontalMargin: 16,
                  // columnSpacing: screenWidth < 700 ? 70 : 30,

                  columnSpacing: screenWidth < 362
                      ? 50
                      : screenWidth < 392
                          ? 80
                          : screenWidth < 500
                              ? 120
                              : screenWidth < 800
                                  ? 180
                                  : 70,

                  columns: [
                    DataColumn(
                      label: Text(
                        'Parameter',
                        style: TextStyle(
                            fontSize: headerFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue),
                      ),
                    ),
                    DataColumn(
                      label: Padding(
                        padding: EdgeInsets.only(
                          right: MediaQuery.of(context).size.width *
                              0.04, // Adjust padding based on screen width
                        ), // Adjust the value as needed
                        child: Text(
                          'Recent Value',
                          style: TextStyle(
                              fontSize: headerFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                  rows: [
                    buildWeatherDataRow(
                        'Temperature', temperatureStats, fontSize),
                    buildWeatherDataRow('Humidity', humidityStats, fontSize),
                    buildWeatherDataRow(
                        'Light Intensity', lightIntensityStats, fontSize),
                    buildWeatherDataRow(
                        'Solar Irradiance', solarIrradianceStats, fontSize),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow buildWeatherDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

  Widget buildRainDataTable() {
    // Use the string values directly from the API
    String currentRain = _mostRecentHourRain ?? "-"; // If null, show "-"
    String totalRainLast24Hours =
        _totalRainLast24Hours ?? "-"; // If null, show "-"

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 18 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6), // Semi-transparent background
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Rain Data',
                style: TextStyle(
                  fontSize: headerFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 16),
            DataTable(
              columnSpacing: screenWidth < 380
                  ? 70
                  : screenWidth < 500
                      ? 120
                      : screenWidth < 800
                          ? 200
                          : 50,
              columns: [
                DataColumn(
                  label: Text(
                    'Timeframe',
                    style: TextStyle(
                        fontSize: screenWidth < 800 ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Value',
                    style: TextStyle(
                        fontSize: screenWidth < 800 ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                DataRow(
                  cells: [
                    DataCell(Text(
                      'Recent Hour',
                      style: TextStyle(fontSize: fontSize, color: Colors.white),
                    )),
                    DataCell(Text(
                      currentRain,
                      style: TextStyle(fontSize: fontSize, color: Colors.white),
                    )),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text(
                      'Last 24 Hours',
                      style: TextStyle(fontSize: fontSize, color: Colors.white),
                    )),
                    DataCell(Text(
                      totalRainLast24Hours,
                      style: TextStyle(fontSize: fontSize, color: Colors.white),
                    )),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Calculate average, min, and max values
  Map<String, List<double?>> _calculateNHStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        // 'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    // double sum = 0.0;
    double? current = data.last.value;
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }

    return {
      'current': [current],
      'min': [min],
      'max': [max],
    };
  }

  // Create a table displaying statistics
  Widget buildNHStatisticsTable() {
    final ammoniaStats = _calculateNHStatistics(ammoniaData);
    final temppStats = _calculateNHStatistics(temperaturedata);
    final humStats = _calculateNHStatistics(humiditydata);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 16 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
            ),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Text(
                    'Parameter',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Current',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Min',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Max',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                buildDataRow('AMMONIA', ammoniaStats, fontSize),
                buildDataRow('TEMP', temppStats, fontSize),
                buildDataRow('HUMIDITY', humStats, fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow buildNHDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['min']?[0] != null ? stats['min']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['max']?[0] != null ? stats['max']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

  // Calculate average, min, and max values
  Map<String, List<double?>> _calculateITStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        // 'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    // double sum = 0.0;
    double? current = data.last.value;
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }

    return {
      'current': [current],
      'min': [min],
      'max': [max],
    };
  }

  // Create a table displaying statistics
  Widget buildITStatisticsTable() {
    final ittempStats = _calculateITStatistics(ittempData);
    final itpressureStats = _calculateITStatistics(itpressureData);
    final ithumStats = _calculateITStatistics(ithumidityData);
    final itrainStats = _calculateITStatistics(itrainData);
    final itradiationStats = _calculateITStatistics(itradiationData);
    final itvisibilityStats = _calculateITStatistics(itvisibilityData);
    final itwindspeedStats = _calculateITStatistics(itwindspeedData);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 16 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
            ),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Text(
                    'Parameter',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Current',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Min',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Max',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                buildDataRow('TEMP', ittempStats, fontSize),
                buildDataRow('PRESSURE', itpressureStats, fontSize),
                buildDataRow('HUMIDITY', ithumStats, fontSize),
                buildDataRow('RAIN', itrainStats, fontSize),
                buildDataRow('RADIATION', itradiationStats, fontSize),
                buildDataRow('VISIBILITY', itvisibilityStats, fontSize),
                buildDataRow('WIND SPEED', itwindspeedStats, fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow buildITDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['min']?[0] != null ? stats['min']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['max']?[0] != null ? stats['max']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

  // Calculate average, min, and max values
  Map<String, List<double?>> _calculatefsStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    double sum = 0.0;
    double? current = data.last.value;
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      sum += entry.value;
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }
    double avg = sum / data.length;
    return {
      'average': [avg],
      'current': [current],
      'min': [min],
      'max': [max],
    };
  }

  // Create a table displaying statistics
  Widget buildfsStatisticsTable() {
    final fstempStats = _calculatefsStatistics(fstempData);
    final fspressureStats = _calculatefsStatistics(fspressureData);
    final fshumStats = _calculatefsStatistics(fshumidityData);
    final fsrainStats = _calculatefsStatistics(fsrainData);
    final fsradiationStats = _calculatefsStatistics(fsradiationData);

    final fswindspeedStats = _calculatefsStatistics(fswindspeedData);
    final fswinddirectionStats = _calculatefsStatistics(fswinddirectionData);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 27;
    double headerFontSize = screenWidth < 800 ? 16 : 33;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 900,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth < 800 ? screenWidth - 32 : 900,
            ),
            child: DataTable(
              horizontalMargin: 20,
              columnSpacing: 25,
              columns: [
                DataColumn(
                  label: Text(
                    'Parameter',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Current',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Min',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Max',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                // DataColumn(
                //   label: Text(
                //     'Avg',
                //     style: TextStyle(
                //         fontSize: headerFontSize,
                //         fontWeight: FontWeight.bold,
                //         color: Colors.blue),
                //   ),
                // ),
              ],
              rows: [
                buildfsDataRow('TEMPERATURE (°C)', fstempStats, fontSize),
                buildfsDataRow('PRESSURE (hPa)', fspressureStats, fontSize),
                buildfsDataRow('RELATIVE HUMIDITY (%)', fshumStats, fontSize),
                buildfsDataRow('RAIN LEVEL (mm)', fsrainStats, fontSize),
                buildfsDataRow('RADIATION (W/m²)', fsradiationStats, fontSize),
                buildfsDataRow('WIND SPEED (m/s)', fswindspeedStats, fontSize),
                buildfsDataRow(
                    'WIND DIRECTION (°)', fswinddirectionStats, fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow buildfsDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['min']?[0] != null ? stats['min']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['max']?[0] != null ? stats['max']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      // DataCell(Text(
      //     stats['average']?[0] != null
      //         ? stats['average']![0]!.toStringAsFixed(2)
      //         : '-',
      //     style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

  DateTime _parseBDDate(String dateString) {
    final dateFormat = DateFormat(
        'yyyy-MM-dd hh:mm a'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parseDate(String dateString) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parsewindDate(String dateString) {
    final dateFormat = DateFormat(
        'yyyy-MM-dd hh:mm a'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parseWaterDate(String dateString) {
    final dateFormat = DateFormat(
        'yyyy-MM-dd HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parseCBDate(String dateString) {
    final dateFormat = DateFormat(
        'dd-MM-yyyy HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parseITDate(String dateString) {
    final dateFormat = DateFormat(
        'dd-MM-yyyy HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parsefsDate(String dateString) {
    final dateFormat = DateFormat(
        'dd-MM-yyyy HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parseSMDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    try {
      // Parse the timestamp format: YYYYMMDDTHHMMSS (e.g., 20250614T162130)
      return DateTime.parse(
          dateStr.replaceFirst('T', ' ')); // Convert to YYYYMMDD HHMMSS
    } catch (e) {
      print('Error parsing SM date: $e');
      return DateTime.now();
    }
  }

  DateTime _parseCFDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    try {
      // Parse the timestamp format: YYYY-MM-DD HH:MM:SS (e.g., 2025-06-15 01:01:02)
      return DateTime.parse(dateStr);
    } catch (e) {
      print('Error parsing CF date: $e');
      return DateTime.now();
    }
  }

  DateTime _parseSVDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    try {
      // Parse the timestamp format: YYYY-MM-DD HH:MM:SS (e.g., 2025-06-15 01:01:02)
      return DateTime.parse(dateStr);
    } catch (e) {
      print('Error parsing SV date: $e');
      return DateTime.now();
    }
  }

  DateTime _parsedoDate(String dateString) {
    final dateFormat = DateFormat(
        'yyyy-MM-dd HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parseammoniaDate(String dateString) {
    final dateFormat = DateFormat(
        'dd-MM-yyyy HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parserainDate(String dateString) {
    final dateFormat = DateFormat(
        'dd-MM-yyyy HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parsethDate(String dateString) {
    if (dateString.isEmpty) {
      return DateTime.now();
    }

    final dateFormat = DateFormat('dd-MM-yyyy HH:mm:ss');
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      print('Date parsing error: $e');
      return DateTime.now();
    }
  }

  DateTime _parsesensorDate(String dateString) {
    final dateFormat = DateFormat(
        'yyyy-MM-dd HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parsewaterDate(String dateString) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      print('Error parsing date $dateString: $e');
      return DateTime.now();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _getDeviceStatus(String lastReceivedTime) {
    if (lastReceivedTime == 'Unknown') return 'Unknown';
    try {
      // Adjust this format to match the actual format of lastReceivedTime
      final dateFormat = DateFormat(
          'yyyy-MM-dd hh:mm a'); // Change to 'HH:mm' for 24-hour format

      final lastReceivedDate = dateFormat.parse(lastReceivedTime);
      final currentTime = DateTime.now();
      final difference = currentTime.difference(lastReceivedDate);

      if (difference.inMinutes <= 62) {
        return 'Active';
      } else {
        return 'Inactive';
      }
    } catch (e) {
      print('Error parsing date: $e');
      return 'Inactive'; // Fallback status in case of error
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(1970),
      lastDate: DateTime(2027),
    );

    if (picked != null) {
      setState(() {
        _selectedDay = picked;

        _fetchDataForRange('single'); // Fetch data for the selected date
      });
    }
  }

  void _reloadData({DateTime? selectedDate}) async {
    setState(() {
      _isLoading = true; // Start loading
    });

    if (selectedDate != null) {
      // If a single date is selected, pass 'single' to fetch data for that day
      _lastSelectedRange = 'single'; // Update last selected range
      await _fetchDataForRange('single', selectedDate);
    } else {
      // If no date is selected, reload the last selected range
      await _fetchDataForRange(_lastSelectedRange);
    }

    setState(() {
      _isLoading = false; // Stop loading once data is fetched
    });
  }

  // Updated _buildWindCompass
  Widget _buildWindCompass(String? winddirection) {
    print('Building wind compass with windDirection: "$winddirection"');

    // Convert wind direction to double, default to 0 if invalid
    double angle = 0;
    try {
      angle = double.parse(winddirection ?? '0');
      print('Parsed wind direction angle: $angle degrees');
    } catch (e) {
      print('Error parsing wind direction: $e');
      angle = 0;
    }

    // Convert degrees to radians for rotation
    final angleRad = angle * math.pi / 180;
    print('Angle in radians: $angleRad');

    return Column(
      children: [
        Container(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Compass background with ticks
              CustomPaint(
                painter: CompassBackgroundPainter(),
                child: Container(width: 150, height: 150),
              ),
              // Compass cardinal directions (N, NE, E, SE, S, SW, W, NW)
              Positioned(
                top: 10,
                child: Text(
                  'N',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: Text(
                  'NE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                right: 10,
                child: Text(
                  'E',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: Text(
                  'SE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                child: Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                child: Text(
                  'SW',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                left: 10,
                child: Text(
                  'W',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                top: 20,
                left: 20,
                child: Text(
                  'NW',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Rotated needle for wind direction
              Transform.rotate(
                angle: angleRad,
                child: CustomPaint(
                  painter: CompassNeedlePainter(), // No angle parameter
                  child: Container(width: 150, height: 150),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Wind Direction: ${winddirection ?? 'N/A'}°',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

// Helper function to map parameter keys to display names and units
  Map<String, dynamic> _getParameterDisplayInfo(String paramName) {
    String displayName = paramName
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match[1]}')
        .trim();
    String unit = '';

    if (paramName.contains('Rainfall'))
      unit = 'mm';
    else if (paramName.contains('Voltage'))
      unit = 'V';
    else if (paramName.contains('SignalStrength'))
      unit = 'dBm';
    else if (paramName.contains('Latitude') || paramName.contains('Longitude'))
      unit = 'deg';
    else if (paramName.contains('Temperature'))
      unit = '°C';
    else if (paramName.contains('Humidity'))
      unit = '%';
    else if (paramName.contains('Pressure'))
      unit = 'hPa';
    else if (paramName.contains('LightIntensity'))
      unit = 'Lux';
    else if (paramName.contains('WindSpeed'))
      unit = 'm/s';
    else if (paramName.contains('WindDirection'))
      unit = 'degrees'; // Added for CF WindDirection
    else if (paramName.contains('Irradiance') ||
        paramName.contains('Radiation'))
      unit = 'W/m²';
    else if (paramName.contains('Chlorine') ||
        paramName.contains('COD') ||
        paramName.contains('BOD') ||
        paramName.contains('DO'))
      unit = 'mg/L';
    else if (paramName.contains('TDS'))
      unit = 'ppm';
    else if (paramName.contains('EC'))
      unit = 'mS/cm';
    else if (paramName.contains('pH'))
      unit = '';
    else if (paramName.contains('Ammonia'))
      unit = 'PPM';
    else if (paramName.contains('Visibility'))
      unit = 'm';
    else if (paramName.contains('ElectrodeSignal')) unit = 'mV';

    return {'displayName': displayName, 'unit': unit};
  }

  @override
  Widget build(BuildContext context) {
    // Determine the background image based on the device type
    String backgroundImagePath;

    // Check the device name and assign the appropriate image
    if (widget.deviceName.startsWith('WD')) {
      backgroundImagePath = 'assets/tree.jpg';
    } else if (widget.deviceName.startsWith('CL')) {
      backgroundImagePath = 'assets/Chloritronn.png';
    } else if (widget.deviceName.startsWith('TE')) {
      backgroundImagePath = 'assets/tree.jpg';
    } else if (widget.deviceName.startsWith('LU')) {
      backgroundImagePath = 'assets/tree.jpg';
    } else if (widget.deviceName.startsWith('TH')) {
      backgroundImagePath = 'assets/tree.jpg';
    } else if (widget.deviceName.startsWith('WQ') ||
        (widget.deviceName.startsWith('WS'))) {
      backgroundImagePath = 'assets/water_quality.jpg';
    } else {
      // For water quality sensor
      backgroundImagePath = 'assets/tree.jpg';
    }
    String _selectedRange = 'ee';
    // : 'assets/soil.jpg';

    return Scaffold(
      backgroundColor: const Color.fromARGB(
          255, 202, 213, 223), // Blue background color for the entire page
      body: Stack(
        children: [
          // Background image with blur effect
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(backgroundImagePath),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black
                        .withOpacity(0.3), // Add a semi-transparent overlay
                    BlendMode.darken,
                  ),
                ),
              ),
              width: double.infinity,
              height: MediaQuery.of(context).size.width < 800 ? 400 : 500,
            ),
          ),
          // AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text.rich(
                TextSpan(
                  text: widget.sequentialName, // Main title
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: MediaQuery.of(context).size.width < 800 ? 14 : 32,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: " (${widget.deviceName})", // Device ID in brackets
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width < 800
                            ? 14
                            : 30, // Smaller font
                        fontWeight: FontWeight.bold,
                        color: Colors.white70, // Slightly dim color
                      ),
                    ),
                  ],
                ),
              ),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              actions: [
                if (widget.deviceName.startsWith('WD'))
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getBatteryIcon(
                            _parseBatteryPercentage(_lastBatteryPercentage),
                          ),
                          size: 26,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          ': $_lastBatteryPercentage',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.deviceName.startsWith('FS'))
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getfsBatteryIcon(_lastfsBattery),
                              color: _getBatteryColor(_lastfsBattery),
                              size: 28,
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${_lastfsBattery.toStringAsFixed(2)} V',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (widget.deviceName.startsWith('SM'))
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getfsBatteryIcon(_lastsmBattery),
                              color: _getBatteryColor(_lastsmBattery),
                              size: 28,
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${_lastsmBattery.toStringAsFixed(2)} V',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (widget.deviceName.startsWith('CF'))
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getfsBatteryIcon(_lastcfBattery),
                              color: _getBatteryColor(_lastcfBattery),
                              size: 28,
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${_lastcfBattery.toStringAsFixed(2)} V',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (widget.deviceName.startsWith('SV'))
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getfsBatteryIcon(_lastsvBattery),
                              color: _getBatteryColor(_lastsvBattery),
                              size: 28,
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${_lastsvBattery.toStringAsFixed(2)} V',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white, size: 26),
                    onPressed: () {
                      _reloadData();
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Positioned(
            top: AppBar()
                .preferredSize
                .height, // Position content below the AppBar
            left: 0,
            right: 0,
            bottom: 0,
            child: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.only(top: 16), // Adjust padding as needed
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            children: [
                              // Display Device ID, Status, and Received time
                              // Row(
                              //   mainAxisAlignment:
                              //       MainAxisAlignment.spaceBetween,
                              //   children: [
                              //     Text(
                              //       'Status: $_currentStatus',
                              //       style: TextStyle(
                              //         fontWeight: FontWeight.bold,
                              //         fontSize:
                              //             MediaQuery.of(context).size.width *
                              //                 0.011,
                              //         color: Colors.white,
                              //       ),
                              //     ),
                              //   ],
                              // ),

                              // Space between status and buttons
                              SizedBox(height: 20),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: MediaQuery.of(context).size.width < 800
                                    ? Container(
                                        width: 200,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          color: const Color.fromARGB(
                                              150, 0, 0, 0),
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: DropdownButton<String>(
                                                isExpanded: true,
                                                hint: Text(
                                                    'Select a time period'),
                                                dropdownColor: Colors.black
                                                    .withOpacity(0.5),
                                                value: _selectedRange,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _selectedRange = value!;
                                                    if (value == 'date') {
                                                      _selectDate(); // Your date picker function
                                                    } else if (value ==
                                                        '7days') {
                                                      _fetchDataForRange(
                                                          '7days'); // Fetch data for 7 days
                                                    } else if (value ==
                                                        '30days') {
                                                      _fetchDataForRange(
                                                          '30days'); // Fetch data for 30 days
                                                    } else if (value ==
                                                        '3months') {
                                                      _fetchDataForRange(
                                                          '3months'); // Fetch data for 3 months
                                                    } else if (value ==
                                                        '6months') {
                                                      _fetchDataForRange(
                                                          '6months'); // Fetch data for 6 months
                                                    }
                                                  });
                                                },
                                                items: [
                                                  DropdownMenuItem(
                                                    child: Text(
                                                      'Select Time Period',
                                                      style: TextStyle(
                                                          fontSize: 15,
                                                          color: Colors.white),
                                                    ),
                                                    value: 'ee',
                                                  ),
                                                  DropdownMenuItem(
                                                    child: Text(
                                                      'Select One Day',
                                                      style: TextStyle(
                                                          fontSize: 20,
                                                          color: Colors.white),
                                                    ),
                                                    value: 'date',
                                                  ),
                                                  DropdownMenuItem(
                                                    child: Text(
                                                      'Last 7 Days',
                                                      style: TextStyle(
                                                          fontSize: 20,
                                                          color: Colors.white),
                                                    ),
                                                    value: '7days',
                                                  ),
                                                  DropdownMenuItem(
                                                    child: Text(
                                                      'Last 30 Days',
                                                      style: TextStyle(
                                                          fontSize: 20,
                                                          color: Colors.white),
                                                    ),
                                                    value: '30days',
                                                  ),
                                                  DropdownMenuItem(
                                                    child: Text(
                                                      'Last 3 months',
                                                      style: TextStyle(
                                                          fontSize: 20,
                                                          color: Colors.white),
                                                    ),
                                                    value: '3months',
                                                  ),
                                                  DropdownMenuItem(
                                                    child: Text(
                                                      'Last 6 months',
                                                      style: TextStyle(
                                                          fontSize: 20,
                                                          color: Colors.white),
                                                    ),
                                                    value: '6months',
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            color: const Color.fromARGB(
                                                150, 0, 0, 0),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Date Picker button
                                              Expanded(
                                                child: TextButton(
                                                  onPressed: () {
                                                    _selectDate(); // Your date picker function
                                                    setState(() {
                                                      // _selectedRange =
                                                      //     'date'; // Mark this button as selected
                                                      _activeButton =
                                                          'date'; // Set the active button
                                                    });
                                                  },
                                                  style: TextButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 36,
                                                            vertical: 28),
                                                    side: _activeButton ==
                                                            'date'
                                                        ? BorderSide(
                                                            color: Colors.white,
                                                            width: 2)
                                                        : BorderSide.none,
                                                  ),
                                                  child: Text(
                                                    'Select Date: ${DateFormat('yyyy-MM-dd').format(_selectedDay)}',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: _activeButton ==
                                                              'date'
                                                          ? Colors.blue
                                                          : Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              // 7 Days button
                                              Expanded(
                                                child: TextButton(
                                                  onPressed: () {
                                                    _fetchDataForRange(
                                                        '7days'); // Fetch data for 7 days range
                                                    setState(() {
                                                      _activeButton = '7days';
                                                    });
                                                  },
                                                  style: TextButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 36,
                                                            vertical: 28),
                                                    side: _activeButton ==
                                                            '7days'
                                                        ? BorderSide(
                                                            color: Colors.white,
                                                            width: 2)
                                                        : BorderSide.none,
                                                  ),
                                                  child: Text(
                                                    'Last 7 Days',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: _activeButton ==
                                                              '7days'
                                                          ? Colors.blue
                                                          : Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              // 30 Days button
                                              Expanded(
                                                child: TextButton(
                                                  onPressed: () {
                                                    _fetchDataForRange(
                                                        '30days'); // Fetch data for 30 days range
                                                    setState(() {
                                                      _activeButton = '30days';
                                                    });
                                                  },
                                                  style: TextButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 36,
                                                            vertical: 28),
                                                    side: _activeButton ==
                                                            '30days'
                                                        ? BorderSide(
                                                            color: Colors.white,
                                                            width: 2)
                                                        : BorderSide.none,
                                                  ),
                                                  child: Text(
                                                    'Last 30 Days',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: _activeButton ==
                                                              '30days'
                                                          ? Colors.blue
                                                          : Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              // 3 Months button
                                              Expanded(
                                                child: TextButton(
                                                  onPressed: () {
                                                    _fetchDataForRange(
                                                        '3months'); // Fetch data for 3 months range
                                                    setState(() {
                                                      _activeButton = '3months';
                                                    });
                                                  },
                                                  style: TextButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 36,
                                                            vertical: 28),
                                                    side: _activeButton ==
                                                            '3months'
                                                        ? BorderSide(
                                                            color: Colors.white,
                                                            width: 2)
                                                        : BorderSide.none,
                                                  ),
                                                  child: Text(
                                                    'Last 3 months',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: _activeButton ==
                                                              '3months'
                                                          ? Colors.blue
                                                          : Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              // 3 Months button
                                              Expanded(
                                                child: TextButton(
                                                  onPressed: () {
                                                    _fetchDataForRange(
                                                        '6months'); // Fetch data for 6 months range
                                                    setState(() {
                                                      _activeButton = '6months';
                                                    });
                                                  },
                                                  style: TextButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 36,
                                                            vertical: 28),
                                                    side: _activeButton ==
                                                            '6months'
                                                        ? BorderSide(
                                                            color: Colors.white,
                                                            width: 2)
                                                        : BorderSide.none,
                                                  ),
                                                  child: Text(
                                                    'Last 6 months',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: _activeButton ==
                                                              '6months'
                                                          ? Colors.blue
                                                          : Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),

                              SizedBox(
                                  height:
                                      20), // Space between buttons and the next section
// Wind Direction widget in the center
                              // if (widget.deviceName.startsWith('WD') &&
                              //     isWindDirectionValid(_lastWindDirection))
                              if (widget.deviceName.startsWith('WD') &&
                                  isWindDirectionValid(_lastWindDirection) &&
                                  _lastWindDirection != null &&
                                  _lastWindDirection.isNotEmpty)
                                Column(
                                  children: [
                                    Icon(
                                      Icons.wind_power,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Wind Direction : $_lastWindDirection',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),

                              SizedBox(height: 20),
                              if (widget.deviceName.startsWith('TE'))
                                Text(
                                  'RSSI Value : $_lastRSSI_Value',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Check if the device is a chlorine sensor device
                          if (widget.deviceName.startsWith('CL'))
                            _buildCurrentValue('Chlorine Level',
                                _currentChlorineValue, 'mg/L'),
                          // if (widget.deviceName.startsWith('NH'))
                          //   _buildCurrentValue(
                          //       'Ammonia Value', _currentAmmoniaValue, 'PPM'),
                          if (widget.deviceName.startsWith('20'))
                            _buildCurrentValue(
                                'Rain Level ', _currentrfdValue, 'mm'),

                          // Add compass for IT devices with debugging
                          () {
                            print(
                                'Checking compass display conditions for device: ${widget.deviceName}');
                            print(
                                'Device starts with IT: ${widget.deviceName.startsWith('IT')}');
                            print(
                                'Wind direction valid: ${isWindDirectionValid(_lastwinddirection)}');
                            print(
                                'Wind direction not null: ${_lastwinddirection != null}');
                            print(
                                'Wind direction not empty: ${_lastwinddirection?.isNotEmpty ?? false}');

                            if (widget.deviceName.startsWith('IT') &&
                                iswinddirectionValid(_lastwinddirection) &&
                                _lastwinddirection != null &&
                                _lastwinddirection.isNotEmpty) {
                              print('All conditions met, displaying compass');
                              return _buildWindCompass(_lastwinddirection);
                            } else {
                              print(
                                  'Compass not displayed due to failed conditions');
                              return SizedBox
                                  .shrink(); // Return empty widget if conditions fail
                            }
                          }(),

                          // // Add compass for FS devices with debugging
                          // () {
                          //   print(
                          //       'Checking compass display conditions for device: ${widget.deviceName}');
                          //   print(
                          //       'Device starts with FS: ${widget.deviceName.startsWith('FS')}');
                          //   print(
                          //       'Wind direction valid: ${isWindDirectionValid(_lastfswinddirection)}');
                          //   print(
                          //       'Wind direction not null: ${_lastfswinddirection != null}');
                          //   print(
                          //       'Wind direction not empty: ${_lastfswinddirection?.isNotEmpty ?? false}');

                          //   if (widget.deviceName.startsWith('FS') &&
                          //       iswinddirectionValid(_lastfswinddirection) &&
                          //       _lastfswinddirection != null &&
                          //       _lastfswinddirection.isNotEmpty) {
                          //     print('All conditions met, displaying compass');
                          //     return _buildWindCompass(_lastfswinddirection);
                          //   } else {
                          //     print(
                          //         'Compass not displayed due to failed conditions');
                          //     return SizedBox
                          //         .shrink(); // Return empty widget if conditions fail
                          //   }
                          // }(),
                        ],
                      ),
                    ),
                    if (widget.deviceName.startsWith('WQ'))
                      buildStatisticsTable(),
                    if (widget.deviceName.startsWith('CB'))
                      buildCBStatisticsTable(),
                    if (widget.deviceName.startsWith('NH'))
                      buildNHStatisticsTable(),
                    if (widget.deviceName.startsWith('DO'))
                      buildDOStatisticsTable(),
                    if (widget.deviceName.startsWith('IT'))
                      buildITStatisticsTable(),
                    if (widget.deviceName.startsWith('FS'))
                      buildfsStatisticsTable(),
                    if (widget.deviceName.startsWith('WD211') ||
                        (widget.deviceName.startsWith('WD511')))
                      SingleChildScrollView(
                        // Make the whole layout scrollable
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              double screenWidth = constraints.maxWidth;

                              // Check if the screen width is large enough to show the tables side by side
                              bool isLargeScreen = screenWidth > 800;

                              return isLargeScreen
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        buildWeatherStatisticsTable(), // Weather Statistics Table
                                        SizedBox(
                                            width: 5), // Space between tables
                                        buildRainDataTable(), // Rain Data Table
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        buildWeatherStatisticsTable(), // Weather Statistics Table
                                        SizedBox(
                                            height: 5), // Space between tables
                                        buildRainDataTable(), // Rain Data Table
                                      ],
                                    );
                            },
                          ),
                        ),
                      ),
                    Column(
                      children: [
                        // SM sensor parameters (dynamic)
                        if (widget.deviceName.startsWith('SM'))
                          ...smParametersData.entries.map((entry) {
                            String paramName = entry.key;
                            List<ChartData> data = entry.value;

                            // Exclude specified Parameters
                            List<String> excludedParams = [
                              'Longitude',
                              'Latitude',
                              'SignalStrength',
                              'BatteryVoltage',
                            ];

                            if (!excludedParams.contains(paramName) &&
                                data.isNotEmpty) {
                              final displayInfo =
                                  _getParameterDisplayInfo(paramName);
                              String displayName = displayInfo['displayName'];
                              String unit = displayInfo['unit'];
                              return _buildChartContainer(
                                displayName,
                                data,
                                unit.isNotEmpty
                                    ? '$displayName ($unit)'
                                    : displayName,
                                ChartType.line,
                              );
                            }
                            return const SizedBox.shrink();
                          }).toList(),
                        if (widget.deviceName.startsWith('CF'))
                          ...cfParametersData.entries.map((entry) {
                            String paramName = entry.key;
                            List<ChartData> data = entry.value;

                            // Exclude specified parameters
                            List<String> excludedParams = [
                              'Longitude',
                              'Latitude',
                              'SignalStrength',
                              'BatteryVoltage',
                              'MaximumTemperature',
                              'MinimumTemperature',
                              'AverageTemperature',
                              'RainfallDaily',
                              'RainfallWeekly',
                              'AverageHumidity',
                              'MinimumHumidity',
                              'MaximumHumidity',
                            ];

                            if (!excludedParams.contains(paramName) &&
                                data.isNotEmpty) {
                              print(
                                  'Processing CF Parameter: $paramName, Data Length: ${data.length}');

                              final displayInfo =
                                  _getParameterDisplayInfo(paramName);
                              String displayName = displayInfo['displayName'];
                              String unit = displayInfo['unit'];
                              print(
                                  'Display Info for $paramName: displayName=$displayName, unit=$unit');

                              // Customize chart title for specific parameters
                              String chartTitle;
                              if (paramName.toLowerCase() ==
                                  'currenthumidity') {
                                chartTitle = 'Humidity Graph ($unit)';
                              } else if (paramName.toLowerCase() ==
                                  'currenttemperature') {
                                chartTitle = 'Temperature Graph ($unit)';
                              } else {
                                chartTitle = unit.isNotEmpty
                                    ? '$displayName ($unit)'
                                    : displayName;
                              }
                              print('Chart Title for $paramName: $chartTitle');

                              return _buildChartContainer(
                                displayName,
                                data,
                                chartTitle,
                                ChartType.line,
                              );
                            } else {
                              print(
                                  'Skipping CF Parameter: $paramName, Excluded: ${excludedParams.contains(paramName)}, Data Empty: ${data.isEmpty}');
                            }
                            return const SizedBox.shrink();
                          }).toList(),

                        if (widget.deviceName.startsWith('SV'))
                          ...svParametersData.entries.map((entry) {
                            String paramName = entry.key;
                            List<ChartData> data = entry.value;

                            // Exclude specified parameters
                            List<String> excludedParams = [
                              'Longitude',
                              'Latitude',
                              'SignalStrength',
                              'BatteryVoltage',
                              'MaximumTemperature',
                              'MinimumTemperature',
                              'AverageTemperature',
                              'RainfallDaily',
                              'RainfallWeekly',
                              'AverageHumidity',
                              'MinimumHumidity',
                              'MaximumHumidity',
                            ];

                            if (!excludedParams.contains(paramName) &&
                                data.isNotEmpty) {
                              print(
                                  'Processing SV Parameter: $paramName, Data Length: ${data.length}');

                              final displayInfo =
                                  _getParameterDisplayInfo(paramName);
                              String displayName = displayInfo['displayName'];
                              String unit = displayInfo['unit'];
                              print(
                                  'Display Info for $paramName: displayName=$displayName, unit=$unit');

                              // Customize chart title for specific parameters
                              String chartTitle;
                              if (paramName.toLowerCase() ==
                                  'currenthumidity') {
                                chartTitle = 'Humidity Graph ($unit)';
                              } else if (paramName.toLowerCase() ==
                                  'currenttemperature') {
                                chartTitle = 'Temperature Graph ($unit)';
                              } else {
                                chartTitle = unit.isNotEmpty
                                    ? '$displayName ($unit)'
                                    : displayName;
                              }
                              print('Chart Title for $paramName: $chartTitle');

                              return _buildChartContainer(
                                displayName,
                                data,
                                chartTitle,
                                ChartType.line,
                              );
                            } else {
                              print(
                                  'Skipping SV Parameter: $paramName, Excluded: ${excludedParams.contains(paramName)}, Data Empty: ${data.isEmpty}');
                            }
                            return const SizedBox.shrink();
                          }).toList(),
                        // Non-SM sensor parameters
                        if (!widget.deviceName.startsWith('SM') &&
                            !widget.deviceName.startsWith('CM') &&
                            !widget.deviceName.startsWith('SV')) ...[
                          if (hasNonZeroValues(chlorineData))
                            _buildChartContainer('Chlorine', chlorineData,
                                'Chlorine (mg/L)', ChartType.line),
                          if (hasNonZeroValues(temperatureData))
                            _buildChartContainer('Temperature', temperatureData,
                                'Temperature (°C)', ChartType.line),
                          if (hasNonZeroValues(humidityData))
                            _buildChartContainer('Humidity', humidityData,
                                'Humidity (%)', ChartType.line),
                          if (hasNonZeroValues(lightIntensityData))
                            _buildChartContainer(
                                'Light Intensity',
                                lightIntensityData,
                                'Light Intensity (Lux)',
                                ChartType.line),
                          if (hasNonZeroValues(windSpeedData))
                            _buildChartContainer('Wind Speed', windSpeedData,
                                'Wind Speed (m/s)', ChartType.line),
                          if (hasNonZeroValues(solarIrradianceData))
                            _buildChartContainer(
                                'Solar Irradiance',
                                solarIrradianceData,
                                'Solar Irradiance (W/M^2)',
                                ChartType.line),
                          if (hasNonZeroValues(tempData))
                            _buildChartContainer('Temperature', tempData,
                                'Temperature (°C)', ChartType.line),
                          if (hasNonZeroValues(tdsData))
                            _buildChartContainer(
                                'TDS', tdsData, 'TDS (ppm)', ChartType.line),
                          if (hasNonZeroValues(codData))
                            _buildChartContainer(
                                'COD', codData, 'COD (mg/L)', ChartType.line),
                          if (hasNonZeroValues(bodData))
                            _buildChartContainer(
                                'BOD', bodData, 'BOD (mg/L)', ChartType.line),
                          if (hasNonZeroValues(pHData))
                            _buildChartContainer(
                                'pH', pHData, 'pH', ChartType.line),
                          if (hasNonZeroValues(doData))
                            _buildChartContainer(
                                'DO', doData, 'DO (mg/L)', ChartType.line),
                          if (hasNonZeroValues(ecData))
                            _buildChartContainer(
                                'EC', ecData, 'EC (mS/cm)', ChartType.line),
                          if (hasNonZeroValues(temppData))
                            _buildChartContainer('Temperature', temppData,
                                'Temperature (°C)', ChartType.line),
                          if (hasNonZeroValues(electrodeSignalData))
                            _buildChartContainer(
                                'Electrode Signal',
                                electrodeSignalData,
                                'Electrode Signal (mV)',
                                ChartType.line),
                          if (hasNonZeroValues(residualchlorineData))
                            _buildChartContainer(
                                'Chlorine',
                                residualchlorineData,
                                'Chlorine (mg/L)',
                                ChartType.line),
                          if (hasNonZeroValues(hypochlorousData))
                            _buildChartContainer(
                                'Hypochlorous',
                                hypochlorousData,
                                'Hypochlorous (mg/L)',
                                ChartType.line),
                          if (hasNonZeroValues(temmppData))
                            _buildChartContainer('Temperature', temmppData,
                                'Temperature (°C)', ChartType.line),
                          if (hasNonZeroValues(humidityyData))
                            _buildChartContainer('Humidity', humidityyData,
                                'Humidity (%)', ChartType.line),
                          if (hasNonZeroValues(lightIntensityyData))
                            _buildChartContainer(
                                'Light Intensity',
                                lightIntensityyData,
                                'Light Intensity (Lux)',
                                ChartType.line),
                          if (hasNonZeroValues(windSpeeddData))
                            _buildChartContainer('Wind Speed', windSpeeddData,
                                'Wind Speed (m/s)', ChartType.line),
                          if (hasNonZeroValues(ttempData))
                            _buildChartContainer('Temperature', ttempData,
                                'Temperature (°C)', ChartType.line),
                          if (hasNonZeroValues(dovaluedata))
                            _buildChartContainer('DO Value', dovaluedata,
                                'DO (mg/L)', ChartType.line),
                          if (hasNonZeroValues(dopercentagedata))
                            _buildChartContainer(
                                'DO Percentage',
                                dopercentagedata,
                                'DO Percentage (%)',
                                ChartType.line),
                          if (hasNonZeroValues(temperaturData))
                            _buildChartContainer('Temperature', temperaturData,
                                'Temperature (°C)', ChartType.line),
                          if (hasNonZeroValues(humData))
                            _buildChartContainer('Humidity', humData,
                                'Humidity (%)', ChartType.line),
                          if (hasNonZeroValues(luxData))
                            _buildChartContainer('Light Intensity', luxData,
                                'Lux (Lux)', ChartType.line),
                          if (hasNonZeroValues(coddata))
                            _buildChartContainer(
                                'COD', coddata, 'COD (mg/L)', ChartType.line),
                          if (hasNonZeroValues(boddata))
                            _buildChartContainer(
                                'BOD', boddata, 'BOD (mg/L)', ChartType.line),
                          if (hasNonZeroValues(phdata))
                            _buildChartContainer(
                                'pH', luxData, 'pH', ChartType.line),
                          if (hasNonZeroValues(temperattureData))
                            _buildChartContainer(
                                'Temperature',
                                temperattureData,
                                'Temperature (°C)',
                                ChartType.line),
                          if (hasNonZeroValues(humidittyData))
                            _buildChartContainer('Humidity', humidittyData,
                                'Humidity (%)', ChartType.line),
                          if (hasNonZeroValues(ammoniaData))
                            _buildChartContainer('Ammonia', ammoniaData,
                                'Ammonia (PPM)', ChartType.line),
                          if (hasNonZeroValues(temperaturedata))
                            _buildChartContainer('Temperature', temperaturedata,
                                'Temperature (°C)', ChartType.line),
                          if (hasNonZeroValues(humiditydata))
                            _buildChartContainer('Humidity', humiditydata,
                                'Humidity (%)', ChartType.line),
                          // if (hasNonZeroValues(rfdData))
                          // _buildChartContainer(
                          //     'RFD', rfdData, 'RFD (mm)', ChartType.line),
                          // if (hasNonZeroValues(rfsData))
                          _buildChartContainer(
                              'RFS', rfsData, 'RFS (mm)', ChartType.line),
                          if (hasNonZeroValues(ittempData))
                            _buildChartContainer('Temperature', ittempData,
                                'Temperature (°C)', ChartType.line),
                          if (hasNonZeroValues(itpressureData))
                            _buildChartContainer('Pressure', itpressureData,
                                'Pressure (hPa)', ChartType.line),
                          if (hasNonZeroValues(ithumidityData))
                            _buildChartContainer('Humidity', ithumidityData,
                                'Humidity (%)', ChartType.line),
                          // if (hasNonZeroValues(itrainData))
                          _buildChartContainer('Rain Level', itrainData,
                              'Rain Level (mm)', ChartType.line),
                          if (hasNonZeroValues(itvisibilityData))
                            _buildChartContainer('Wind Speed', itwindspeedData,
                                'Wind Speed (m/s)', ChartType.line),
                          if (hasNonZeroValues(itradiationData))
                            _buildChartContainer('Radiation', itradiationData,
                                'Radiation (W/m²)', ChartType.line),
                          if (hasNonZeroValues(itvisibilityData))
                            _buildChartContainer('Visibilty', itvisibilityData,
                                'Visibility (m)', ChartType.line),
                          if (hasNonZeroValues(fstempData))
                            _buildChartContainer('Temperature', fstempData,
                                'Temperature (°C)', ChartType.line),
                          if (hasNonZeroValues(fspressureData))
                            _buildChartContainer('Pressure', fspressureData,
                                'Pressure (hPa)', ChartType.line),
                          if (hasNonZeroValues(fshumidityData))
                            _buildChartContainer('Relative Humidity',
                                fshumidityData, 'Humidity (%)', ChartType.line),
                          // if (hasNonZeroValues(itrainData))
                          _buildChartContainer('Rain Level', fsrainData,
                              'Rain Level (mm)', ChartType.line),
                          if (hasNonZeroValues(fsradiationData))
                            _buildChartContainer('Radiation', fsradiationData,
                                'Radiation (W/m²)', ChartType.line),

                          if (hasNonZeroValues(fswindspeedData))
                            _buildChartContainer('Wind Speed', fswindspeedData,
                                'Wind Speed (m/s)', ChartType.line),

                          if (hasNonZeroValues(temp2Data))
                            _buildChartContainer('Temperature', temp2Data,
                                'Temperature (°C)', ChartType.line),

                          if (hasNonZeroValues(cod2Data))
                            _buildChartContainer(
                                'COD', cod2Data, 'COD (mg/L)', ChartType.line),
                          if (hasNonZeroValues(bod2Data))
                            _buildChartContainer(
                                'BOD', bod2Data, 'BOD (mg/L)', ChartType.line),

                          // // if (hasNonZeroValues(fsrfdData))
                          // _buildChartContainer(
                          //     'RFD', fsrfdData, 'RFD (mm)', ChartType.line),
                          // if (hasNonZeroValues(rfsData))
                        ],
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),

          // Loader overlay
          if (_isLoading) // Show loader only when _isLoading is true
            Positioned.fill(
              child: Container(
                color: Colors.black
                    .withOpacity(0.5), // Dark semi-transparent background
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 16,
            right: 16,
            child: MouseRegion(
              onEnter: (_) =>
                  setState(() => _isHovering = true), // Change hover state
              onExit: (_) => setState(() => _isHovering = false),
              child: ElevatedButton(
                onPressed: () {
                  //downloadCSV(context);
                  // downloadRainCSV(context);
                  _showDownloadOptionsDialog(context); // Show popup
                },
                style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color.fromARGB(
                        255, 40, 41, 41) // Button background color
                    ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.download,
                      color: _isHovering ? Colors.blue : Colors.white,
                    ), // Download icon
                    SizedBox(width: 8),
                    Text(
                      'Download CSV',
                      style: TextStyle(
                        color: _isHovering
                            ? Colors.blue
                            : Colors.white, // Change color on hover
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentValue(
      String parameterName, String currentValue, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align text to the top
        children: [
          // Display both parameter and value together in a single text widget
          Text(
            '$parameterName: $currentValue $unit',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

// This method will parse the percentage string (e.g., "84%") and return the numeric value
  int _parseBatteryPercentage(String batteryPercentage) {
    try {
      // Remove the '%' symbol and parse the number
      return int.parse(batteryPercentage.replaceAll('%', ''));
    } catch (e) {
      // If parsing fails, return a default value (e.g., 0)
      return 0;
    }
  }

  IconData _getBatteryIcon(int batteryPercentage) {
    if (batteryPercentage <= 0) {
      return Icons.battery_0_bar; // Empty battery
    } else if (batteryPercentage > 0 && batteryPercentage <= 20) {
      return Icons.battery_1_bar; // 20% battery
    } else if (batteryPercentage > 20 && batteryPercentage <= 40) {
      return Icons.battery_2_bar; // 40% battery
    } else if (batteryPercentage > 40 && batteryPercentage <= 60) {
      return Icons.battery_3_bar; // 60% battery
    } else if (batteryPercentage > 60 && batteryPercentage <= 80) {
      return Icons.battery_4_bar; // 80% battery
    } else if (batteryPercentage > 80 && batteryPercentage < 100) {
      return Icons.battery_5_bar; // 90% battery
    } else {
      return Icons.battery_full; // Full battery
    }
  }

  Color _getBatteryColor(double voltage) {
    if (voltage < 3.3) {
      return Colors.red;
    } else if (voltage < 4.0) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  IconData _getfsBatteryIcon(double voltage) {
    if (voltage < 3.3) {
      return Icons.battery_2_bar; // Low battery
    } else if (voltage < 4.0) {
      return Icons.battery_5_bar; // Medium battery
    } else {
      return Icons.battery_full; // Full battery
    }
  }

  Widget _buildChartContainer(
    String title,
    List<ChartData> data,
    String yAxisTitle,
    ChartType chartType,
  ) {
    return data.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.width < 800 ? 400 : 500,
              margin: EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                color: const Color.fromARGB(150, 0, 0, 0),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Text(
                      '$title Graph',
                      style: TextStyle(
                          fontSize:
                              MediaQuery.of(context).size.width < 800 ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  if (widget.deviceName.startsWith('CL'))
                    Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Builder(
                        builder: (BuildContext context) {
                          final screenWidth = MediaQuery.of(context).size.width;

                          // Define common properties
                          double boxSize;
                          double textSize;
                          double spacing;

                          if (screenWidth < 800) {
                            // For smaller screens (e.g., mobile devices)
                            boxSize = 15.0;
                            textSize = 15.0;
                            spacing = 12.0;

                            // Row layout for small screens
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildColorBox(Colors.white, '< 0.01 ',
                                      boxSize, textSize),
                                  SizedBox(width: spacing),
                                  _buildColorBox(Colors.green, '> 0.01 - 0.5',
                                      boxSize, textSize),
                                  SizedBox(width: spacing),
                                  _buildColorBox(Colors.yellow, '> 0.5 - 1.0',
                                      boxSize, textSize),
                                  SizedBox(width: spacing),
                                  _buildColorBox(Colors.orange, '> 1.0 - 4.0',
                                      boxSize, textSize),
                                  SizedBox(width: spacing),
                                  _buildColorBox(Colors.red, ' Above 4.0',
                                      boxSize, textSize),
                                ],
                              ),
                            );
                          } else {
                            // For larger screens (e.g., PCs and laptops)
                            boxSize = 20.0;
                            textSize = 16.0;
                            spacing = 45.0;

                            // Row layout for larger screens
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildColorBox(Colors.white, '< 0.01 ',
                                      boxSize, textSize),
                                  SizedBox(width: spacing),
                                  _buildColorBox(Colors.green, '> 0.01 - 0.5',
                                      boxSize, textSize),
                                  SizedBox(width: spacing),
                                  _buildColorBox(Colors.yellow, '> 0.5 - 1.0',
                                      boxSize, textSize),
                                  SizedBox(width: spacing),
                                  _buildColorBox(Colors.orange, '> 1.0 - 4.0',
                                      boxSize, textSize),
                                  SizedBox(width: spacing),
                                  _buildColorBox(Colors.red, ' Above 4.0',
                                      boxSize, textSize),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  Expanded(
                    child: Focus(
                      autofocus: true,
                      child: RawKeyboardListener(
                        focusNode: _focusNode,
                        autofocus: true,
                        onKey: (RawKeyEvent event) {
                          if (event is RawKeyDownEvent &&
                              (event.logicalKey ==
                                      LogicalKeyboardKey.shiftLeft ||
                                  event.logicalKey ==
                                      LogicalKeyboardKey.shiftRight)) {
                            setState(() {
                              isShiftPressed = true;
                            });
                          } else if (event is RawKeyUpEvent &&
                              (event.logicalKey ==
                                      LogicalKeyboardKey.shiftLeft ||
                                  event.logicalKey ==
                                      LogicalKeyboardKey.shiftRight)) {
                            setState(() {
                              isShiftPressed = false;
                            });
                          }
                        },
                        child: MouseRegion(
                          onEnter: (_) => _focusNode.requestFocus(),
                          child: Listener(
                            onPointerSignal: (PointerSignalEvent event) {
                              print(
                                  "Pointer Signal Event: $event | Shift Pressed: $isShiftPressed");
                              if (event is PointerScrollEvent &&
                                  isShiftPressed) {
                                print("Zooming...");
                                // No need to return early; let ZoomPanBehavior handle it
                              }
                            },
                            child: SfCartesianChart(
                              plotAreaBackgroundColor:
                                  const Color.fromARGB(100, 0, 0, 0),
                              primaryXAxis: DateTimeAxis(
                                dateFormat: DateFormat('MM/dd hh:mm a'),
                                title: AxisTitle(
                                  text: 'Time',
                                  textStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                                labelStyle: TextStyle(color: Colors.white),
                                labelRotation: 70,
                                edgeLabelPlacement: EdgeLabelPlacement.shift,
                                intervalType: DateTimeIntervalType.auto,
                                autoScrollingDelta: 100,
                                autoScrollingMode: AutoScrollingMode.end,
                                enableAutoIntervalOnZooming: true,
                                majorGridLines: MajorGridLines(width: 1.0),
                              ),
                              primaryYAxis: NumericAxis(
                                labelStyle: TextStyle(color: Colors.white),
                                title: AxisTitle(
                                  text: yAxisTitle,
                                  textStyle: TextStyle(
                                      fontWeight: FontWeight.w200,
                                      color: Colors.white),
                                ),
                                axisLine: AxisLine(width: 1),
                                majorGridLines: MajorGridLines(width: 0),
                              ),
                              tooltipBehavior: TooltipBehavior(
                                enable: true,
                                duration: 4000,
                                builder: (dynamic data,
                                    dynamic point,
                                    dynamic series,
                                    int pointIndex,
                                    int seriesIndex) {
                                  final ChartData chartData = data as ChartData;
                                  return Container(
                                    padding: EdgeInsets.all(8),
                                    color: const Color.fromARGB(127, 0, 0, 0),
                                    constraints: BoxConstraints(
                                      maxWidth: 200,
                                      maxHeight: 60,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${chartData.timestamp}',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Value: ${chartData.value}',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              zoomPanBehavior: ZoomPanBehavior(
                                zoomMode: ZoomMode.x,
                                enablePanning: true,
                                enablePinching: true,
                                enableMouseWheelZooming: isShiftPressed,
                              ),
                              series: <CartesianSeries<ChartData, DateTime>>[
                                _getChartSeries(chartType, data, title),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : Container();
  }

  Widget _buildColorBox(
      Color color, String range, double boxSize, double textSize) {
    return Row(
      children: [
        Container(
          width: boxSize,
          height: boxSize,
          color: color,
        ),
        SizedBox(width: 8), // Fixed width between box and text
        Text(
          range,
          style: TextStyle(
            color: Colors.white,
            fontSize: textSize,
          ),
        ),
      ],
    );
  }

  CartesianSeries<ChartData, DateTime> _getChartSeries(
      ChartType chartType, List<ChartData> data, String title) {
    switch (chartType) {
      case ChartType.line:
        if (widget.deviceName.startsWith('CL')) {
          // Chlorine sensor
          return LineSeries<ChartData, DateTime>(
            markerSettings: const MarkerSettings(
              height: 6.0,
              width: 6.0,
              isVisible: true,
            ),
            dataSource: data,
            xValueMapper: (ChartData data, _) => data.timestamp,
            yValueMapper: (ChartData data, _) => data.value,
            name: title,
            color: Colors.blue,
            pointColorMapper: (ChartData data, _) {
              // Color range for chlorine sensor
              if (data.value >= 0.01 && data.value <= 0.5) {
                return Colors.green;
              } else if (data.value > 0.5 && data.value <= 1.0) {
                return Colors.yellow;
              } else if (data.value > 1.0 && data.value <= 4.0) {
                return Colors.orange;
              } else if (data.value > 4.0) {
                return Colors.red;
              }
              return Colors.white; // Default color
            },
          );
        } else {
          // Other devices
          return LineSeries<ChartData, DateTime>(
            markerSettings: const MarkerSettings(
              height: 6.0,
              width: 6.0,
              isVisible: true,
            ),
            dataSource: data,
            xValueMapper: (ChartData data, _) => data.timestamp,
            yValueMapper: (ChartData data, _) => data.value,
            name: title,
            color: Colors.blue, // Single color for non-chlorine sensors
          );
        }

      default:
        return LineSeries<ChartData, DateTime>(
          dataSource: data,
          xValueMapper: (ChartData data, _) => data.timestamp,
          yValueMapper: (ChartData data, _) => data.value,
          name: title,
          color: Colors.blue,
        );
    }
  }
}

enum ChartType {
  line,
}

class ChartData {
  final DateTime timestamp;
  final double value;

  ChartData({required this.timestamp, required this.value});
}
