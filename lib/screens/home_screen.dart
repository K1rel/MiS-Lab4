import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:lab4/screens/calendar_screen.dart';
import 'package:lab4/services/location_reminder_notification.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/exam_event.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late Box<ExamEvent> _eventsBox;
  List<Marker> _markers = [];
  final PopupController _popupController = PopupController();
  late MapController _mapController;
  List<LatLng> _routePoints = [];
  LatLng? _userLocation;
  bool _isLoadingRoute = false;
  LatLng? _selectedLocation;
  late LocationReminderService _locationService;
  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _mapController = MapController();
    _eventsBox = Hive.box<ExamEvent>('events');
    _locationService = LocationReminderService();
    _locationService.initialize();
    _getCurrentLocation();
    _loadMarkers();
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _getRoute(ExamEvent event) async {
    if (_userLocation == null) return;

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final response = await http.get(Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_userLocation!.longitude},${_userLocation!.latitude};'
        '${event.longitude},${event.latitude}?overview=full&geometries=polyline',
      ));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final routes = decoded['routes'] as List;
        if (routes.isNotEmpty) {
          final String polyline = routes[0]['geometry'];
          final points = _decodePolyline(polyline);

          setState(() {
            _routePoints = points;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No route found.')),
          );
        }
      } else {
        throw Exception('Failed to load route');
      }
    } catch (e) {
      print('Error getting route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error retrieving route')),
      );
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  void _loadMarkers() {
    _markers = _eventsBox.values.map((event) {
      return Marker(
        point: LatLng(event.latitude, event.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            _showEventPopup(event);
          },
          child: Icon(
            Icons.location_on,
            color: Colors.red,
            size: 30.0,
          ),
        ),
      );
    }).toList();
    setState(() {});
  }

  void _showEventPopup(ExamEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${event.dateTime}'),
            Text('Location: ${event.location}'),
            Text('Lat: ${event.latitude}, Lon: ${event.longitude}'),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _getRoute(event),
              child: Text('Show Route'),
            )
          ],
        ),
        actions: [
          TextButton(
            child: Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam Schedule'),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_active),
            onPressed: () async {
              print("Testing notifications...");
              await _locationService.checkLocationNow();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Location check triggered - check debug console'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CalendarScreen(eventsBox: _eventsBox),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: LatLng(41.9981, 21.4254),
              zoom: 13.0,
              onTap: (tapPosition, latLng) {
                setState(() {
                  _selectedLocation = latLng;
                });
                _showAddOrEditEventDialog();
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty)
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                ],
              ),
              MarkerLayer(markers: [
                ..._markers,
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 30.0,
                    ),
                  ),
              ]),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: () {
                    LocationReminderService().checkLocationNow();
                  },
                  child: Icon(Icons.notifications),
                ),
                FloatingActionButton(
                  heroTag: "zoom_in",
                  child: Icon(Icons.add),
                  mini: true,
                  onPressed: () {
                    _mapController.move(
                      _mapController.center,
                      _mapController.zoom + 1,
                    );
                  },
                ),
                SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "zoom_out",
                  child: Icon(Icons.remove),
                  mini: true,
                  onPressed: () {
                    _mapController.move(
                      _mapController.center,
                      _mapController.zoom - 1,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditEventDialog({ExamEvent? eventToEdit}) {
    final TextEditingController titleController = TextEditingController(
      text: eventToEdit?.title ?? '',
    );
    DateTime? selectedDateTime = eventToEdit?.dateTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(eventToEdit == null ? 'Add Event' : 'Edit Event'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: 'Event Title'),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  child: Text(
                    selectedDateTime == null
                        ? 'Select Date & Time'
                        : 'Selected: ${selectedDateTime!.toLocal()}'
                            .split('.')
                            .first,
                  ),
                  onPressed: () async {
                    final DateTime? date = await showDatePicker(
                      context: context,
                      initialDate: selectedDateTime ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: selectedDateTime != null
                            ? TimeOfDay.fromDateTime(selectedDateTime!)
                            : TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          selectedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: Text(eventToEdit == null ? 'Add' : 'Update'),
                onPressed: () {
                  if (titleController.text.isNotEmpty &&
                      selectedDateTime != null) {
                    if (eventToEdit == null) {
                      if (_selectedLocation == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Please select a location on the map')),
                        );
                        return;
                      }
                      _eventsBox.add(ExamEvent(
                        title: titleController.text,
                        dateTime: selectedDateTime!,
                        location:
                            'Lat: ${_selectedLocation!.latitude}, Lon: ${_selectedLocation!.longitude}',
                        latitude: _selectedLocation!.latitude,
                        longitude: _selectedLocation!.longitude,
                      ));
                    } else {
                      eventToEdit.title = titleController.text;
                      eventToEdit.dateTime = selectedDateTime!;
                      eventToEdit.save();
                    }
                    Navigator.pop(context);
                    _loadMarkers(); // Refresh markers
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please fill all fields')),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEventsForDay(DateTime day) {
    final events = _eventsBox.values
        .where(
          (event) => isSameDay(event.dateTime, day),
        )
        .toList();

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return ListTile(
            title: Text(event.title),
            subtitle: Text('${event.dateTime.toString()} - ${event.location}'),
          );
        },
      ),
    );
  }
}
