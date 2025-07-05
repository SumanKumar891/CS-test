import 'dart:async';
import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:cloud_sense_webapp/HomePage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart' show Distance;
import 'package:provider/provider.dart';
import 'package:cloud_sense_webapp/main.dart';

enum MapType { defaultMap, satellite, terrain }

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng centerCoordinates = LatLng(0, 0);
  double zoomLevel = 5.0;
  late MapController mapController;
  bool isLoading = false;

  List<Map<String, dynamic>> deviceLocations = [];
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  List<Map<String, dynamic>> filteredDevices = [];
  List<Map<String, dynamic>> suggestions = [];
  Marker? searchPin;

  List<String> deviceIds = [];
  String? selectedDeviceId;
  DateTime? startDate;
  DateTime? endDate;
  final DateFormat dateFormatter = DateFormat('dd-MM-yyyy');

  Map<String, Map<String, dynamic>> previousPositions = {};
  final double displacementThreshold = 100.0;
  final Distance distance = Distance();
  final int stationaryTimeThreshold = 24 * 60 * 60 * 1000;

  static const String POSITIONS_KEY = 'device_previous_positions';

  MapType currentMapType = MapType.defaultMap;

  Timer? _autoReloadTimer;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _loadPreviousPositions();
    // Start auto-reload timer to refresh every 60 seconds
    _startAutoReload();
  }

  void _startAutoReload() {
    _autoReloadTimer = Timer.periodic(Duration(seconds: 60), (timer) {
      if (mounted) {
        _fetchDeviceLocations();
      }
    });
  }

  @override
  void dispose() {
    // Cancel the auto-reload timer to prevent memory leaks
    _autoReloadTimer?.cancel();
    searchController.dispose();
    mapController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    try {
      // First, unsubscribe from all notification topics before logout

      // Then proceed with logout
      await Amplify.Auth.signOut();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs
          .clear(); // Clear all stored preferences including subscription flags

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Error during logout: $e');
      // Even if there's an error, proceed with logout
      try {
        await Amplify.Auth.signOut();
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(),
          ),
          (Route<dynamic> route) => false,
        );
      } catch (logoutError) {
        print('Error during fallback logout: $logoutError');
      }
    }
  }

  Future<void> _loadPreviousPositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedData = prefs.getString(POSITIONS_KEY);

      if (storedData != null) {
        final Map<String, dynamic> decodedData = json.decode(storedData);
        previousPositions = decodedData.map((key, value) => MapEntry(
              key,
              Map<String, dynamic>.from(value),
            ));
        print(
            'Loaded ${previousPositions.length} previous positions from storage');
      }
    } catch (e) {
      print('Error loading previous positions: $e');
      previousPositions = {};
    }

    _fetchDeviceLocations();
  }

  Future<void> _savePreviousPositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedData = json.encode(previousPositions);
      await prefs.setString(POSITIONS_KEY, encodedData);
      print('Saved ${previousPositions.length} positions to storage');
    } catch (e) {
      print('Error saving previous positions: $e');
    }
  }

  double _truncateToThreeDecimals(double value) {
    String valueStr = value.toString();
    List<String> parts = valueStr.split('.');
    if (parts.length < 2) return value;
    String integerPart = parts[0];
    String decimalPart =
        parts[1].length > 3 ? parts[1].substring(0, 3) : parts[1];
    return double.parse('$integerPart.$decimalPart');
  }

  Future<void> _fetchDeviceLocations(
      {String? deviceId, DateTime? start, DateTime? end}) async {
    setState(() {
      isLoading = true;
      searchPin = null;
    });

    try {
      String url =
          'https://nv9spsjdpe.execute-api.us-east-1.amazonaws.com/default/GPS_API_Data_func';
      if (deviceId != null && start != null && end != null) {
        final String startStr = dateFormatter.format(start);
        final String endStr = dateFormatter.format(end);
        url += '?Device_id=$deviceId&startdate=$startStr&enddate=$endStr';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isEmpty) {
          print('No new data returned from API');
          _updateDeviceStatusesForInactivity();
          setState(() {
            isLoading = false;
          });
          return;
        }

        Map<String, Map<String, dynamic>> latestDevices = {};

        for (var device in data) {
          String deviceId = device['Device_id'].toString();
          String timestamp = device['Timestamp'].toString();
          bool hasNote =
              device.containsKey('Note') && device['Note'].isNotEmpty;

          if (!latestDevices.containsKey(deviceId)) {
            latestDevices[deviceId] = device;
          } else {
            String existingTimestamp = latestDevices[deviceId]!['Timestamp'];
            bool existingHasNote =
                latestDevices[deviceId]!.containsKey('Note') &&
                    latestDevices[deviceId]!['Note'].isNotEmpty;

            DateTime currentTime = DateTime.parse(timestamp);
            DateTime existingTime = DateTime.parse(existingTimestamp);

            if (currentTime.isAfter(existingTime)) {
              latestDevices[deviceId] = device;
            } else if (currentTime.isAtSameMomentAs(existingTime)) {
              if (hasNote && !existingHasNote) {
                latestDevices[deviceId] = device;
              }
            }
          }
        }

        if (deviceId == null) {
          deviceIds = latestDevices.keys.toList();
          deviceIds.sort();
          if (!deviceIds.contains('None')) {
            deviceIds.insert(0, 'None');
          }
        }

        List<Map<String, dynamic>> fetchedDevices = [];
        bool positionsUpdated = false;

        for (var device in latestDevices.values) {
          String deviceId = device['Device_id'].toString();
          double lat = device['Latitude'] is String
              ? _truncateToThreeDecimals(double.parse(device['Latitude']))
              : _truncateToThreeDecimals(device['Latitude']);
          double lon = device['Longitude'] is String
              ? _truncateToThreeDecimals(double.parse(device['Longitude']))
              : _truncateToThreeDecimals(device['Longitude']);
          LatLng currentPosition = LatLng(lat, lon);
          String currentTimestamp = device['Timestamp'].toString();

          bool hasMoved = false;
          String? initialMovedTimestamp;

          if (previousPositions.containsKey(deviceId)) {
            final prevData = previousPositions[deviceId]!;
            final LatLng prevPosition =
                LatLng(prevData['latitude'], prevData['longitude']);
            final String prevTimestamp = prevData['timestamp'];
            initialMovedTimestamp = prevData['initial_moved_timestamp'];

            if (currentTimestamp == prevTimestamp) {
              print('No new timestamp for device $deviceId, skipping update');
              fetchedDevices.add({
                'name': 'Device: $deviceId',
                'latitude': lat,
                'longitude': lon,
                'place': prevData['place'] ?? 'Unknown',
                'state': prevData['state'] ?? 'Unknown',
                'country': prevData['country'] ?? 'Unknown',
                'last_active': currentTimestamp,
                'has_moved': prevData['has_moved'] ?? false,
                'note': device['Note'] ?? '',
              });
              continue;
            }

            double dist =
                distance.as(LengthUnit.Meter, prevPosition, currentPosition);

            if (dist >= displacementThreshold) {
              hasMoved = true;
              initialMovedTimestamp = currentTimestamp;
              print(
                  'Device $deviceId moved ${dist.toStringAsFixed(2)}m (>100m), setting to red');
            } else {
              hasMoved = prevData['has_moved'] ?? false;
              print('Device $deviceId stationary (<100m), retaining color');
            }
          } else {
            hasMoved = false;
            initialMovedTimestamp = currentTimestamp;
            print('First time tracking device $deviceId, setting to green');
          }

          final geoData = await _reverseGeocode(lat, lon);
          previousPositions[deviceId] = {
            'latitude': lat,
            'longitude': lon,
            'timestamp': currentTimestamp,
            'initial_moved_timestamp':
                initialMovedTimestamp ?? currentTimestamp,
            'has_moved': hasMoved,
            'place': geoData['place'],
            'state': geoData['state'],
            'country': geoData['country'],
          };
          positionsUpdated = true;

          fetchedDevices.add({
            'name': 'Device: $deviceId',
            'latitude': lat,
            'longitude': lon,
            'place': geoData['place'] ?? 'Unknown',
            'state': geoData['state'] ?? 'Unknown',
            'country': geoData['country'] ?? 'Unknown',
            'last_active': currentTimestamp,
            'has_moved': hasMoved,
            'note': device['Note'] ?? '',
          });
        }

        if (positionsUpdated) {
          await _savePreviousPositions();
        }

        setState(() {
          deviceLocations = fetchedDevices;
          filteredDevices = fetchedDevices;
          _updateDeviceStatusesForInactivity();
          if (fetchedDevices.isNotEmpty) {
            centerCoordinates = LatLng(
                fetchedDevices[0]['latitude'], fetchedDevices[0]['longitude']);
            zoomLevel = 12.0;
            mapController.move(centerCoordinates, zoomLevel);
          } else {
            centerCoordinates = LatLng(0, 0);
            zoomLevel = 5.0;
            mapController.move(centerCoordinates, zoomLevel);
          }
        });
      } else {
        _showError('Failed to fetch devices: ${response.statusCode}');
        _updateDeviceStatusesForInactivity();
      }
    } catch (e) {
      _showError('Error fetching devices: $e');
      _updateDeviceStatusesForInactivity();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _updateDeviceStatusesForInactivity() {
    final currentTime = DateTime.now();
    final istOffset = Duration(hours: 5, minutes: 30);
    final currentTimeUtc = currentTime.subtract(istOffset);

    setState(() {
      for (var device in deviceLocations) {
        String deviceId = device['name'].replaceFirst('Device: ', '');
        if (!previousPositions.containsKey(deviceId)) continue;

        final prevData = previousPositions[deviceId]!;
        final String? initialMovedTimestamp =
            prevData['initial_moved_timestamp'];

        if (initialMovedTimestamp == null) {
          device['has_moved'] = false;
          prevData['has_moved'] = false;
          print(
              'No initial moved timestamp for device $deviceId, setting to green');
          continue;
        }

        try {
          DateTime initialMovedTime = DateTime.parse(initialMovedTimestamp);
          final timeSinceInitialMove =
              currentTimeUtc.difference(initialMovedTime).inMilliseconds;
          if (timeSinceInitialMove >= stationaryTimeThreshold &&
              device['has_moved'] == true) {
            print(
                'Device $deviceId initial movement over 24hrs ago, changing to green');
            device['has_moved'] = false;
            prevData['has_moved'] = false;
          }
        } catch (e) {
          print(
              'Error parsing initial moved timestamp for device $deviceId: $e');
        }
      }
      filteredDevices = List.from(deviceLocations);
    });
    _savePreviousPositions();
  }

  Future<void> _clearStoredPositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(POSITIONS_KEY);
      previousPositions.clear();
      print('Cleared all stored positions');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleared stored device positions')),
      );
      _fetchDeviceLocations();
    } catch (e) {
      print('Error clearing positions: $e');
    }
  }

  Future<Map<String, String>> _reverseGeocode(double lat, double lon) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&zoom=18&addressdetails=1';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'CloudSenseApp/1.0 (contact@example.com)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        String place = address['amenity'] ??
            address['building'] ??
            address['shop'] ??
            address['office'] ??
            address['tourism'] ??
            address['leisure'] ??
            address['suburb'] ??
            address['neighbourhood'] ??
            address['hamlet'] ??
            address['city'] ??
            address['town'] ??
            address['village'] ??
            address['county'] ??
            data['display_name']?.split(',')[0] ??
            'Unknown';
        return {
          'place': place,
          'state': address['state'] ?? 'Unknown',
          'country': address['country'] ?? 'Unknown',
        };
      } else {
        print('Reverse geocoding failed: ${response.statusCode}');
        return {'place': 'Unknown', 'state': 'Unknown', 'country': 'Unknown'};
      }
    } catch (e) {
      print('Error during reverse geocoding: $e');
      return {'place': 'Unknown', 'state': 'Unknown', 'country': 'Unknown'};
    }
  }

  Future<void> _geocode(String query) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'CloudSenseApp/1.0 (contact@example.com)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty &&
            data[0]['lat'] != null &&
            data[0]['lon'] != null) {
          double lat = double.parse(data[0]['lat']);
          double lon = double.parse(data[0]['lon']);
          LatLng searchCoordinates = LatLng(lat, lon);
          setState(() {
            centerCoordinates = searchCoordinates;
            zoomLevel = 12.0;
            searchPin = Marker(
              width: 80.0,
              height: 80.0,
              point: searchCoordinates,
              child: Icon(
                Icons.location_pin,
                size: 40,
                color: Colors.red,
              ),
            );
          });
          mapController.move(searchCoordinates, zoomLevel);
        } else {
          _showError("No results found for '$query'.");
        }
      } else {
        _showError("Failed to fetch location: ${response.statusCode}");
      }
    } catch (e) {
      _showError('Error during geocoding: $e');
    }
  }

  void _searchDevices(String query) async {
    setState(() {
      searchQuery = query.toLowerCase();
      filteredDevices = deviceLocations.where((device) {
        return device['place']?.toLowerCase().contains(searchQuery) == true ||
            device['state']?.toLowerCase().contains(searchQuery) == true ||
            device['country']?.toLowerCase().contains(searchQuery) == true ||
            device['name']?.toLowerCase().contains(searchQuery) == true;
      }).toList();
      if (query.isEmpty) {
        searchPin = null;
      }
    });

    if (filteredDevices.isEmpty && query.isNotEmpty) {
      await _geocode(query);
    } else if (filteredDevices.isNotEmpty) {
      final device = filteredDevices.first;
      setState(() {
        centerCoordinates = LatLng(device['latitude'], device['longitude']);
        zoomLevel = 12.0;
        searchPin = null;
      });
      mapController.move(centerCoordinates, zoomLevel);
    }
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        suggestions = [];
        searchPin = null;
      });
      return;
    }

    setState(() {
      suggestions = deviceLocations
          .where((device) =>
              device['name'].toLowerCase().contains(query.toLowerCase()) ||
              device['place'].toLowerCase().contains(query.toLowerCase()) ||
              device['state'].toLowerCase().contains(query.toLowerCase()) ||
              device['country'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    searchController.text = suggestion['place'];
    _searchDevices(suggestion['place']);
    setState(() {
      suggestions = [];
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
        if (selectedDeviceId != null && startDate != null && endDate != null) {
          _fetchDeviceLocations(
              deviceId: selectedDeviceId, start: startDate, end: endDate);
        }
      });
    }
  }

  void _showDeviceInfoDialog(
    BuildContext context,
    String name,
    double latitude,
    double longitude,
    String place,
    String state,
    String country,
    String lastActive,
    bool hasMoved, [
    String? note,
  ]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: EdgeInsets.all(16),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 300,
              maxHeight: 400,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Latitude: ${latitude.toStringAsFixed(3)}'),
                  Text('Longitude: ${longitude.toStringAsFixed(3)}'),
                  Text('Place: $place'),
                  Text('State: $state'),
                  Text('Country: $country'),
                  Text('Last Active: $lastActive'),
                  Text(
                    'Status: ${hasMoved ? "Moved (>100m)" : "Stationary (<100m or >24 hrs)"}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: hasMoved ? Colors.red : Colors.green,
                    ),
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    SizedBox(height: 12),
                    Text(
                      "Note: $note",
                      style: TextStyle(
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  TileLayer _getTileLayer() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    String urlTemplate;
    Color backgroundColor;

    switch (currentMapType) {
      case MapType.defaultMap:
        urlTemplate = isDarkMode
            ? 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png'
            : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
        backgroundColor = isDarkMode
            ? const Color(0xFF1A2A44)
            : const Color.fromARGB(255, 173, 216, 230);
        break;
      case MapType.satellite:
        urlTemplate =
            'https://tiles.stadiamaps.com/tiles/alidade_satellite/{z}/{x}/{y}{r}.png';
        backgroundColor = isDarkMode
            ? const Color(0xFF1A2A44)
            : const Color.fromARGB(255, 173, 216, 230);
        break;
      case MapType.terrain:
        urlTemplate =
            'https://tiles.stadiamaps.com/tiles/stamen_terrain/{z}/{x}/{y}{r}.png';
        backgroundColor = isDarkMode
            ? const Color(0xFF1A2A44)
            : const Color.fromARGB(255, 173, 216, 230);
        break;
    }

    return TileLayer(
      urlTemplate: urlTemplate,
      subdomains: currentMapType == MapType.defaultMap && !isDarkMode
          ? ['a', 'b', 'c']
          : [],
      // backgroundColor: backgroundColor,
      maxZoom: 19.0,
      minZoom: 2.0,
      errorTileCallback: (tile, error, stackTrace) {
        print('Tile failed to load: $error');
      },
    );
  }

  void _toggleMapType(MapType type) {
    setState(() {
      currentMapType = type;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      body: Container(
        color: isDarkMode ? const Color(0xFF1A2A44) : Colors.lightBlue[100],
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: centerCoordinates,
                initialZoom: zoomLevel,
                minZoom: 2.0,
                maxZoom: 19.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                keepAlive: true,
              ),
              children: [
                _getTileLayer(),
                MarkerLayer(
                  markers: [
                    if (searchPin != null) searchPin!,
                    ...deviceLocations.map((device) {
                      return Marker(
                        point: LatLng(
                          device['latitude'],
                          device['longitude'],
                        ),
                        width: 80.0,
                        height: 80.0,
                        child: GestureDetector(
                          onTap: () {
                            _showDeviceInfoDialog(
                              context,
                              device['name'],
                              device['latitude'],
                              device['longitude'],
                              device['place'],
                              device['state'],
                              device['country'],
                              device['last_active'],
                              device['has_moved'] == true,
                              device['note'],
                            );
                          },
                          child: Icon(
                            Icons.location_pin,
                            size: 40,
                            color: device['has_moved'] == true
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    color: Colors.transparent,
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back),
                          color: isDarkMode ? Colors.white : Colors.black,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          'Device Map',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: isLoading
                              ? CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black),
                                )
                              : IconButton(
                                  icon:
                                      Icon(Icons.refresh, color: Colors.black),
                                  onPressed: isLoading
                                      ? null
                                      : () => _fetchDeviceLocations(),
                                  tooltip: 'Reload Map',
                                ),
                        ),
                        SizedBox(width: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(Icons.logout, color: Colors.black),
                            onPressed: _handleLogout,
                            tooltip: 'Logout',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                onChanged: _updateSuggestions,
                                onSubmitted: _searchDevices,
                                decoration: InputDecoration(
                                  hintText: 'Search Location',
                                  hintStyle: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: isDarkMode
                                      ? Colors.black.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.2),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedDeviceId,
                                hint: Text(
                                  'Select Device ID',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                items: deviceIds.map((String id) {
                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(id),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    selectedDeviceId = newValue;
                                    if (selectedDeviceId != null &&
                                        startDate != null &&
                                        endDate != null) {
                                      _fetchDeviceLocations(
                                          deviceId: selectedDeviceId,
                                          start: startDate,
                                          end: endDate);
                                    }
                                  });
                                },
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: isDarkMode
                                      ? Colors.black.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                readOnly: true,
                                onTap: () => _selectDate(context, true),
                                style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: isDarkMode
                                      ? Colors.black.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.2),
                                  hintText: startDate == null
                                      ? 'Select Start Date'
                                      : dateFormatter.format(startDate!),
                                  hintStyle: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                readOnly: true,
                                onTap: () => _selectDate(context, false),
                                style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: isDarkMode
                                      ? Colors.black.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.2),
                                  hintText: endDate == null
                                      ? 'Select End Date'
                                      : dateFormatter.format(endDate!),
                                  hintStyle: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        if (suggestions.isNotEmpty)
                          Container(
                            color: isDarkMode ? Colors.grey[850] : Colors.white,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: suggestions.length,
                              itemBuilder: (context, index) {
                                final suggestion = suggestions[index];
                                return ListTile(
                                  title: Text(suggestion['place']),
                                  subtitle: Text(
                                      '${suggestion['state']}, ${suggestion['country']} - ${suggestion['name']}'),
                                  onTap: () => _selectSuggestion(suggestion),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
