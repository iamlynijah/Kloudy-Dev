/// What kind of appointment this is — drives the icon and which
/// "find care" search query gets suggested above the list.
enum AppointmentType { doctor, therapy, other }

/// A calendar event relevant to health (doctor visits, therapy sessions).
///
/// Field names intentionally echo the shape of a Google Calendar API
/// event (`summary`, `start`, `htmlLink`) so that swapping the mock
/// data source in HealthScreen for a real `calendar_v3.Event` mapping
/// later is a small, mechanical change rather than a rewrite.
class Appointment {
  final String id;
  final String summary;
  final DateTime start;
  final String? location;
  final AppointmentType type;

  /// Link back to the event in Google Calendar, opened when the user
  /// taps the row. Null for mock/local-only entries.
  final String? htmlLink;

  Appointment({
    required this.id,
    required this.summary,
    required this.start,
    required this.type,
    this.location,
    this.htmlLink,
  });

  String get dateLabel {
    const weekdays = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour12 = start.hour % 12 == 0 ? 12 : start.hour % 12;
    final minute = start.minute.toString().padLeft(2, '0');
    final ampm = start.hour < 12 ? 'AM' : 'PM';
    return '${weekdays[start.weekday - 1]}, '
        '${months[start.month - 1]} ${start.day} · '
        '$hour12:$minute $ampm';
  }

  /// The most useful "find care" search query for this appointment's
  /// type — used to seed the search-near-me deep link contextually.
  String get findCareQuery {
    switch (type) {
      case AppointmentType.doctor:
        return 'doctors near me';
      case AppointmentType.therapy:
        return 'therapists near me';
      case AppointmentType.other:
        return 'urgent care near me';
    }
  }
}

/// Mock Google Calendar events, standing in until real OAuth Calendar
/// access is wired up. See SupabaseService / create_account_screen for
/// where the Google sign-in scope would need to be extended to request
/// calendar.readonly before this can be swapped for live data.
List<Appointment> mockUpcomingAppointments() {
  final now = DateTime.now();
  return [
    Appointment(
      id: 'mock-1',
      summary: 'Dr. Patel · Annual physical',
      start: DateTime(now.year, now.month, now.day + 2, 10, 30),
      type: AppointmentType.doctor,
      location: 'Arlington Medical Group',
    ),
    Appointment(
      id: 'mock-2',
      summary: 'Therapy session',
      start: DateTime(now.year, now.month, now.day + 5, 16, 0),
      type: AppointmentType.therapy,
    ),
  ];
}