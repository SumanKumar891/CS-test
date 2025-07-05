import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

class CsvDownloader extends StatefulWidget {
  final String deviceName;

  CsvDownloader({
    required this.deviceName,
  });

  @override
  _CsvDownloaderState createState() => _CsvDownloaderState();
}

class _CsvDownloaderState extends State<CsvDownloader> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<List<dynamic>> _csvRows = [];
  final DateFormat formatter = DateFormat('dd-MM-yyyy HH:mm:ss');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCustomDateRangeDialog(context);
    });
  }

  Future<void> _downloadCsv() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return;
    }
    _csvRows.clear();
    // Format dates for most APIs (DD-MM-YYYY)
    final dateFormatter = DateFormat('dd-MM-yyyy');
    final startdate = dateFormatter.format(_startDate!);
    final enddate = dateFormatter.format(_endDate!);
    // Format dates for SM API (YYYYMMDD)
    final smDateFormatter = DateFormat('yyyyMMdd');
    final smStartDate = smDateFormatter.format(_startDate!);
    final smEndDate = smDateFormatter.format(_endDate!);
    int deviceId =
        int.parse(widget.deviceName.replaceAll(RegExp(r'[^0-9]'), ''));

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
        widget.deviceName.startsWith('BD')) {
      apiUrl =
          'https://b0e4z6nczh.execute-api.us-east-1.amazonaws.com/CloudSense_Chloritrone_api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('WQ')) {
      apiUrl =
          'https://63jeajtwf8.execute-api.us-west-2.amazonaws.com/default/wqm_csv_dwnld_api?deviceId=${widget.deviceName}&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('IT')) {
      apiUrl =
          'https://7a3bcew3y2.execute-api.us-east-1.amazonaws.com/default/IIT_Bombay_API_func?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('WS')) {
      apiUrl =
          'https://xjbnnqcup4.execute-api.us-east-1.amazonaws.com/default/CloudSense_Water_quality_api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('FS')) {
      apiUrl =
          'https://w7w21t8s23.execute-api.us-east-1.amazonaws.com/default/SSMet_Forest_API_func?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('DO')) {
      apiUrl =
          'https://br2s08as9f.execute-api.us-east-1.amazonaws.com/default/CloudSense_Water_quality_api_2_function?deviceId=$deviceId&startdate=$startdate&enddate=$enddate';
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsupported device type')),
      );
      return;
    }

    print('Fetching data from: $apiUrl'); // Debug
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('API Response: ${response.body}'); // Debug

      if (widget.deviceName.startsWith('SM')) {
        _parseSMData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('CF')) {
        _parseCFData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('SV')) {
        _parseSVData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('CL') ||
          widget.deviceName.startsWith('BD')) {
        _csvRows.add(['Timestamp', 'Chlorine']);
        data['items'].forEach((item) {
          _csvRows.add([item['human_time'], item['chlorine']]);
        });
      } else if (widget.deviceName.startsWith('WQ')) {
        _csvRows.add([
          'Timestamp',
          'Temperature',
          'TDS',
          'COD',
          'BOD',
          'pH',
          'DO',
          'EC'
        ]);
        data.forEach((item) {
          _csvRows.add([
            item['time_stamp'],
            item['temperature'],
            item['TDS'],
            item['COD'],
            item['BOD'],
            item['pH'],
            item['DO'],
            item['EC'],
          ]);
        });
      } else if (widget.deviceName.startsWith('CB')) {
        _csvRows.add([
          'Timestamp',
          'Temperature',
          'COD',
          'BOD',
        ]);
        data.forEach((item) {
          _csvRows.add([
            item['time_stamp'],
            item['temperature'],
            item['COD'],
            item['BOD'],
          ]);
        });
      } else if (widget.deviceName.startsWith('IT')) {
        _csvRows.add([
          'Timestamp',
          'Temperature',
          'Pressure',
          'Humidity',
          'Radiation',
          'Visibility',
          'Wind Direction',
          'Wind Speed'
        ]);
        data['items'].forEach((item) {
          _csvRows.add([
            item['timestamp'],
            item['temperature'],
            item['pressure'],
            item['humidity'],
            item['radiation'],
            item['visibility'],
            item['wind_direction'],
            item['wind_speed'],
          ]);
        });
      } else if (widget.deviceName.startsWith('FS')) {
        _csvRows.add([
          'Timestamp',
          'Temperature',
          'Pressure',
          'Relative Humidity',
          'Radiation',
          'Wind Speed',
          'Wind Direction',
        ]);
        data['items'].forEach((item) {
          _csvRows.add([
            item['timestamp'],
            item['temperature'],
            item['pressure'],
            item['humidity'],
            item['radiation'],
            item['wind_speed'],
            item['wind_direction'],
          ]);
        });
      } else if (widget.deviceName.startsWith('WS')) {
        _csvRows.add([
          'Timestamp',
          'Temperature',
          'Electrode_signal',
          'Chlorine_value',
          'Hypochlorous_value'
        ]);
        data['items'].forEach((item) {
          _csvRows.add([
            item['HumanTime'],
            item['temperature'],
            item['Electrode_signal'],
            item['Chlorine_value'],
            item['Hypochlorous_value'],
          ]);
        });
      } else if (widget.deviceName.startsWith('DO')) {
        _csvRows.add(['Timestamp', 'Temperature', 'DO Value', 'DO Percentage']);
        data['items'].forEach((item) {
          _csvRows.add([
            item['HumanTime'],
            item['Temperature'],
            item['DO Value'],
            item['DO Percentage'],
          ]);
        });
      } else if (widget.deviceName.startsWith('TH')) {
        _csvRows.add(['Timestamp', 'Temperature', 'Humidity']);
        data['items'].forEach((item) {
          _csvRows
              .add([item['HumanTime'], item['Temperature'], item['Humidity']]);
        });
      } else if (widget.deviceName.startsWith('NH')) {
        _csvRows.add(['Timestamp', 'Ammonia', 'Temperature', 'Humidity']);
        data['items'].forEach((item) {
          _csvRows.add([
            item['HumanTime'],
            item['AmmoniaPPM'],
            item['Temperature'],
            item['Humidity'],
          ]);
        });
      } else if (widget.deviceName.startsWith('LU')) {
        _csvRows.add(['Timestamp', 'Lux']);
        data['sensor_data_items'].forEach((item) {
          _csvRows.add([item['HumanTime'], item['Lux']]);
        });
      } else if (widget.deviceName.startsWith('TE')) {
        _csvRows.add(['Timestamp', 'Temperature', 'Humidity']);
        data['sensor_data_items'].forEach((item) {
          _csvRows
              .add([item['HumanTime'], item['Temperature'], item['Humidity']]);
        });
      } else {
        _csvRows.add([
          'Timestamp',
          'Temperature',
          'Humidity',
          'LightIntensity',
          'SolarIrradiance'
        ]);
        data['weather_items'].forEach((item) {
          _csvRows.add([
            item['HumanTime'],
            item['Temperature'],
            item['Humidity'],
            item['LightIntensity'],
            item['SolarIrradiance'],
          ]);
        });
      }

      if (_csvRows.isEmpty ||
          (_csvRows.length == 1 && _csvRows[0][0] == 'Timestamp')) {
        _csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available for selected time range']
        ];
        print('No valid data found, setting fallback CSV');
      }
      print('CSV Rows Prepared: ${_csvRows.length} rows'); // Debug
      if (_csvRows.length > 1) print('Sample Row: ${_csvRows[1]}'); // Debug

      await _generateCsvFile();
    } else {
      print('API Error: ${response.statusCode} ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch data: ${response.statusCode}')),
      );
    }
  }

  void _parseSMData(List<dynamic> items) {
    print('SM API Items Count: ${items.length}'); // Debug
    if (items.isEmpty) {
      _csvRows = [
        ['Timestamp', 'Message'],
        ['', 'No data available']
      ];
      print('No items in SM API response');
      return;
    }

    // Collect non-null parameter keys, excluding non-data fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      return ![
            'TimeStamp',
            'TimeStampFormatted',
            'Topic',
            'IMEINumber',
            'DeviceId'
          ].contains(key) &&
          sampleItem[key] != null;
    }).toList();

    if (parameterKeys.isEmpty) {
      _csvRows = [
        ['Timestamp', 'Message'],
        ['', 'No data available']
      ];
      print('No valid SM parameters found');
      return;
    }

    // Build headers
    List<String> headers = ['Timestamp'];
    headers.addAll(parameterKeys);
    _csvRows.add(headers);

    // Build data rows
    for (var item in items) {
      if (item == null) continue;
      List<dynamic> row = [item['TimeStampFormatted'] ?? ''];
      for (var key in parameterKeys) {
        var value = item[key] != null ? item[key].toString() : '';
        row.add(value);
      }
      _csvRows.add(row);
    }
  }

  void _parseCFData(List<dynamic> items) {
    print('CF API Items Count: ${items.length}'); // Debug
    if (items.isEmpty) {
      _csvRows = [
        ['Timestamp', 'Message'],
        ['', 'No data available']
      ];
      print('No items in CF API response');
      return;
    }

    // Collect non-null parameter keys, excluding non-data fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      return !['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId'].contains(key) &&
          sampleItem[key] != null;
    }).toList();

    if (parameterKeys.isEmpty) {
      _csvRows = [
        ['Timestamp', 'Message'],
        ['', 'No data available']
      ];
      print('No valid CF parameters found');
      return;
    }

    // Build headers
    List<String> headers = ['TimeStamp'];
    headers.addAll(parameterKeys);
    _csvRows.add(headers);

    // Build data rows
    for (var item in items) {
      if (item == null) continue;
      List<dynamic> row = [item['TimeStamp'] ?? ''];
      for (var key in parameterKeys) {
        var value = item[key] != null ? item[key].toString() : '';
        row.add(value);
      }
      _csvRows.add(row);
    }
  }

  void _parseSVData(List<dynamic> items) {
    print('SV API Items Count: ${items.length}'); // Debug
    if (items.isEmpty) {
      _csvRows = [
        ['Timestamp', 'Message'],
        ['', 'No data available']
      ];
      print('No items in SV API response');
      return;
    }

    // Collect non-null parameter keys, excluding non-data fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      return !['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId'].contains(key) &&
          sampleItem[key] != null;
    }).toList();

    if (parameterKeys.isEmpty) {
      _csvRows = [
        ['Timestamp', 'Message'],
        ['', 'No data available']
      ];
      print('No valid SV parameters found');
      return;
    }

    // Build headers
    List<String> headers = ['TimeStamp'];
    headers.addAll(parameterKeys);
    _csvRows.add(headers);

    // Build data rows
    for (var item in items) {
      if (item == null) continue;
      List<dynamic> row = [item['TimeStamp'] ?? ''];
      for (var key in parameterKeys) {
        var value = item[key] != null ? item[key].toString() : '';
        row.add(value);
      }
      _csvRows.add(row);
    }
  }

  String _generateFileName() {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'SensorData_${widget.deviceName}_$timestamp.csv';
  }

  Future<void> _generateCsvFile() async {
    String csvData = const ListToCsvConverter().convert(_csvRows);
    String fileName = _generateFileName();

    if (kIsWeb) {
      final blob = html.Blob([csvData], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Downloading $fileName"),
          duration: Duration(seconds: 1),
        ),
      );
      Future.delayed(Duration(seconds: 1), () {
        Navigator.pop(context);
        Navigator.pop(context);
      });
    } else {
      try {
        await saveCSVFile(csvData, fileName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("File downloaded: $fileName")),
        );
        Future.delayed(Duration(seconds: 1), () {
          Navigator.pop(context);
          Navigator.pop(context);
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error downloading: $e")),
        );
      }
    }
  }

  Future<void> saveCSVFile(String csvData, String fileName) async {
    try {
      final downloadsDirectory = Directory('/storage/emulated/0/Download');
      if (downloadsDirectory.existsSync()) {
        final filePath = '${downloadsDirectory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsString(csvData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("File downloaded to $filePath")),
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

  Future<void> _showCustomDateRangeDialog(BuildContext context) async {
    DateTime? startDate;
    DateTime? endDate;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Date Range'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      'Start Date: ${startDate != null ? startDate!.toLocal().toString().split(' ')[0] : 'Select a start date'}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      DateTime? pickedStartDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (pickedStartDate != null) {
                        setState(() {
                          startDate = pickedStartDate;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: Text(
                      'End Date: ${endDate != null ? endDate!.toLocal().toString().split(' ')[0] : 'Select an end date'}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      DateTime? pickedEndDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: startDate ?? DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (pickedEndDate != null) {
                        setState(() {
                          endDate = pickedEndDate;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                if (startDate != null && endDate != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _startDate = startDate;
                        _endDate = endDate;
                      });
                      Navigator.of(context).pop();
                      _downloadCsv();
                    },
                    child: const Text('Download'),
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 217, 231, 238),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
