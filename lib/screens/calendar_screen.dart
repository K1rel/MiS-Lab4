import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/exam_event.dart';

class CalendarScreen extends StatefulWidget {
  final Box<ExamEvent> eventsBox;

  CalendarScreen({required this.eventsBox});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Map<DateTime, List<ExamEvent>> _events;
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _events = {};
    _loadEvents();
  }

  void _loadEvents() {
    final groupedEvents = <DateTime, List<ExamEvent>>{};
    for (var event in widget.eventsBox.values) {
      final eventDate = DateTime(
        event.dateTime.year,
        event.dateTime.month,
        event.dateTime.day,
      );
      groupedEvents.putIfAbsent(eventDate, () => []).add(event);
    }

    setState(() {
      _events = groupedEvents;
    });
  }

  void _addOrEditEvent({ExamEvent? eventToEdit}) {
    final TextEditingController titleController = TextEditingController(
      text: eventToEdit?.title ?? '',
    );
    DateTime? selectedDateTime = eventToEdit?.dateTime ?? _focusedDay;

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
                        : 'Selected: ${selectedDateTime?.toLocal()}'
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
                        initialTime: TimeOfDay.fromDateTime(selectedDateTime!),
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
                      widget.eventsBox.add(ExamEvent(
                        title: titleController.text,
                        dateTime: selectedDateTime!,
                        location: '',
                        latitude: 0,
                        longitude: 0,
                      ));
                    } else {
                      eventToEdit.title = titleController.text;
                      eventToEdit.dateTime = selectedDateTime!;
                      eventToEdit.save();
                    }
                    Navigator.pop(context);
                    _loadEvents();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Event Calendar')),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            calendarFormat: CalendarFormat.month,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) {
              final dateKey = DateTime(day.year, day.month, day.day);
              return _events[dateKey] ?? [];
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
          ),
          Expanded(
            child: ListView(
              children:
                  (_events[_selectedDay ?? DateTime.now()] ?? []).map((event) {
                return ListTile(
                  title: Text(event.title),
                  subtitle: Text(event.dateTime.toLocal().toString()),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => _addOrEditEvent(eventToEdit: event),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          event.delete();
                          _loadEvents();
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _addOrEditEvent(),
      ),
    );
  }
}
