import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();  // Initialize timezone data
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  
  runApp(MyApp(flutterLocalNotificationsPlugin));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EventProvider(),
      child: MaterialApp(
        home: HomeScreen(),
        theme: ThemeData(
          primarySwatch: Colors.green,
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Event Tracker'),
      ),
      body: Column(
        children: [
          CalendarWidget(),
          Expanded(
            child: EventList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showEventDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEventDialog(BuildContext context) {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Event'),
          content: TextField(
            onChanged: (value) {
              eventProvider.newEvent = value;
            },
            decoration: const InputDecoration(hintText: 'Event Description'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                eventProvider.addEvent();
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class CalendarWidget extends StatelessWidget {
  const CalendarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: DateTime.now(),
      calendarFormat: CalendarFormat.month,
      eventLoader: (day) {
        return Provider.of<EventProvider>(context).getEventsForDay(day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        Provider.of<EventProvider>(context, listen: false).setSelectedDay(selectedDay);
      },
    );
  }
}

class EventList extends StatelessWidget {
  const EventList({super.key});

  @override
  Widget build(BuildContext context) {
    final events = Provider.of<EventProvider>(context).getEventsForDay(Provider.of<EventProvider>(context).selectedDay);
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(events[index]),
        );
      },
    );
  }
}

class EventProvider extends ChangeNotifier {
  final Map<DateTime, List<String>> _events = {};
  DateTime selectedDay = DateTime.now();
  String _newEvent = '';

  String get newEvent => _newEvent;
  set newEvent(String value) {
    _newEvent = value;
  }

  void addEvent() {
    if (_newEvent.isEmpty) return;

    if (_events[selectedDay] != null) {
      _events[selectedDay]?.add(_newEvent);
    } else {
      _events[selectedDay] = [_newEvent];
    }
    _scheduleNotification(selectedDay);
    _newEvent = '';
    notifyListeners();
  }

  List<String> getEventsForDay(DateTime day) {
    return _events[day] ?? [];
  }

  void setSelectedDay(DateTime day) {
    selectedDay = day;
    notifyListeners();
  }

  Future<void> _scheduleNotification(DateTime day) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'your_channel_id', 'your_channel_name',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Event Reminder',
      'You have an event scheduled for today.',
      tz.TZDateTime.from(day, tz.local),
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }
}
