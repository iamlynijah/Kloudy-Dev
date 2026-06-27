import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../models/appointment.dart';

class CalendarService {
  static const _calendarScope = 'https://www.googleapis.com/auth/calendar';

  static final _googleSignIn = GoogleSignIn(
    clientId:
        '229419201107-ric5vi4g9s0o4l31sbutfstp42q10alk.apps.googleusercontent.com',
    serverClientId:
        '229419201107-lqb8h1oo0mbjip1blfikmbjvdiptibb8.apps.googleusercontent.com',
    scopes: [_calendarScope],
  );

  static const _healthKeywords = [
    'doctor', 'dr.', 'dentist', 'dental', 'appointment', 'therapy',
    'therapist', 'medical', 'clinic', 'hospital', 'obgyn', 'optometrist',
    'dermatologist', 'dermatology', 'checkup', 'check-up', 'physical exam',
    'lab', 'bloodwork', 'prescription', 'urgent care', 'psychiatrist',
    'psychologist', 'counseling', 'counselor',
  ];

  static bool get isConnected => _googleSignIn.currentUser != null;

  /// Try a silent sign-in first; returns true if an account is available.
  static Future<bool> tryConnectSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      return account != null;
    } catch (_) {
      return false;
    }
  }

  /// Prompt the user to sign in with Calendar scope.
  static Future<bool> connect() async {
    try {
      final account = await _googleSignIn.signIn();
      return account != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disconnect() => _googleSignIn.signOut();

  static Future<String?> _accessToken() async {
    try {
      var account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      if (account == null) return null;
      final auth = await account.authentication;
      return auth.accessToken;
    } catch (_) {
      return null;
    }
  }

  static bool _isHealthEvent(String title) {
    final lower = title.toLowerCase();
    return _healthKeywords.any((k) => lower.contains(k));
  }

  static AppointmentType _typeFor(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('therap') ||
        lower.contains('counseling') ||
        lower.contains('psychol') ||
        lower.contains('psychiatr')) {
      return AppointmentType.therapy;
    }
    return AppointmentType.doctor;
  }

  static Appointment _toAppointment(Map<String, dynamic> e) {
    final title = (e['summary'] as String?) ?? 'Appointment';
    final startMap = e['start'] as Map<String, dynamic>?;
    final startStr = startMap?['dateTime'] as String? ??
        startMap?['date'] as String? ??
        DateTime.now().toIso8601String();
    return Appointment(
      id: (e['id'] as String?) ?? '',
      summary: title,
      start: DateTime.parse(startStr).toLocal(),
      type: _typeFor(title),
      location: e['location'] as String?,
      htmlLink: e['htmlLink'] as String?,
    );
  }

  /// Fetches upcoming health-related events from the user's primary calendar.
  static Future<List<Appointment>> fetchHealthAppointments() async {
    final token = await _accessToken();
    if (token == null) return [];

    final now = DateTime.now().toUtc();
    final until = now.add(const Duration(days: 90));
    final url = Uri.parse(
      'https://www.googleapis.com/calendar/v3/calendars/primary/events'
      '?timeMin=${Uri.encodeComponent(now.toIso8601String())}'
      '&timeMax=${Uri.encodeComponent(until.toIso8601String())}'
      '&singleEvents=true'
      '&orderBy=startTime'
      '&maxResults=100',
    );

    final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) return [];

    final items =
        ((jsonDecode(res.body) as Map)['items'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

    return items
        .where((e) => _isHealthEvent((e['summary'] as String?) ?? ''))
        .map(_toAppointment)
        .toList();
  }

  /// Creates a new event on the user's primary calendar.
  static Future<bool> createEvent({
    required String title,
    required DateTime start,
    Duration duration = const Duration(hours: 1),
    String? location,
    String? notes,
  }) async {
    final token = await _accessToken();
    if (token == null) return false;

    final end = start.add(duration);
    final body = {
      'summary': title,
      'start': {
        'dateTime': start.toUtc().toIso8601String(),
        'timeZone': 'UTC',
      },
      'end': {
        'dateTime': end.toUtc().toIso8601String(),
        'timeZone': 'UTC',
      },
      if (location != null && location.isNotEmpty) 'location': location,
      if (notes != null && notes.isNotEmpty) 'description': notes,
    };

    final res = await http.post(
      Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/primary/events'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }
}
