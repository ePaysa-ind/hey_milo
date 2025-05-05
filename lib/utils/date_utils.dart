/*
* file path: lib/services/date_utils.dart
* file name: date_utils.dart
* file description: Date and Time Utility for the Milo App
* file author: Milo App Development Team
* file last updated: May 4, 2025
*/
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

/// Utility class for handling date and time formatting and calculations.
///
/// This provides consistent date handling throughout the app with
/// considerations for accessibility and readability for the target
/// audience of users aged 55+.
class DateUtils {
  /// Private constructor to prevent instantiation
  DateUtils._();

  /// Formats a DateTime to be used in IDs and filenames
  ///
  /// Example: "20250101143000" for Jan 1, 2025, 2:30 PM
  static String formatDateTimeForId(DateTime dateTime) {
    final DateFormat formatter = DateFormat('yyyyMMddHHmmss');
    return formatter.format(dateTime);
  }

  /// Formats a date in a user-friendly way showing the full date.
  ///
  /// Example: "Monday, January 1, 2025"
  static String formatFullDate(DateTime date) {
    final DateFormat formatter = DateFormat('EEEE, MMMM d, yyyy');
    return formatter.format(date);
  }

  /// Formats a date in a shorter, more compact format.
  ///
  /// Example: "Jan 1, 2025"
  static String formatShortDate(DateTime date) {
    final DateFormat formatter = DateFormat('MMM d, yyyy');
    return formatter.format(date);
  }

  /// Formats a time in a 12-hour format with AM/PM.
  ///
  /// Example: "2:30 PM"
  static String formatTime(DateTime date) {
    final DateFormat formatter = DateFormat('h:mm a');
    return formatter.format(date);
  }

  /// Formats a date and time together.
  ///
  /// Example: "Jan 1, 2025 at 2:30 PM"
  static String formatDateAndTime(DateTime date) {
    final DateFormat formatter = DateFormat('MMM d, yyyy \'at\' h:mm a');
    return formatter.format(date);
  }

  /// Formats a relative time that's easy to understand.
  ///
  /// Returns different formats based on how recent the date is:
  /// - Today: "Today at 2:30 PM"
  /// - Yesterday: "Yesterday at 2:30 PM"
  /// - Within the last week: "Monday at 2:30 PM"
  /// - Within the current year: "January 1 at 2:30 PM"
  /// - Older: "January 1, 2025 at 2:30 PM"
  static String formatRelativeDate(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final DateTime dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return 'Today at ${DateFormat('h:mm a').format(date)}';
    } else if (dateDay == yesterday) {
      return 'Yesterday at ${DateFormat('h:mm a').format(date)}';
    } else if (today.difference(dateDay).inDays < 7) {
      return '${DateFormat('EEEE').format(date)} at ${DateFormat('h:mm a').format(date)}';
    } else if (date.year == now.year) {
      return '${DateFormat('MMMM d').format(date)} at ${DateFormat('h:mm a').format(date)}';
    } else {
      return '${DateFormat('MMMM d, yyyy').format(date)} at ${DateFormat('h:mm a').format(date)}';
    }
  }

  /// Returns a short, accessible description of how long ago a date was.
  ///
  /// Example: "2 minutes ago", "3 hours ago", "5 days ago"
  static String getTimeAgo(DateTime date) {
    final Duration difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final int minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final int hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 30) {
      final int days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 365) {
      final int months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final int years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  /// Returns just the time portion in AM/PM format from a DateTime.
  ///
  /// Example: "2:30 PM"
  static String getTimeOnly(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  /// Returns just the date portion from a DateTime.
  ///
  /// Example: "January 1, 2025"
  static String getDateOnly(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  /// Returns a string representation of a day of week.
  ///
  /// Example: "Monday", "Tuesday", etc.
  static String getDayOfWeek(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  /// Returns a shortened day of week.
  ///
  /// Example: "Mon", "Tue", etc.
  static String getShortDayOfWeek(DateTime date) {
    return DateFormat('E').format(date);
  }

  /// Returns a string representation of a month.
  ///
  /// Example: "January", "February", etc.
  static String getMonth(DateTime date) {
    return DateFormat('MMMM').format(date);
  }

  /// Returns a shortened month name.
  ///
  /// Example: "Jan", "Feb", etc.
  static String getShortMonth(DateTime date) {
    return DateFormat('MMM').format(date);
  }

  /// Formats a duration in a human-readable way.
  ///
  /// Example: "2h 30m" or "45m 20s"
  static String formatDuration(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = (duration.inMinutes % 60);
    final int seconds = (duration.inSeconds % 60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Formats a timestamp specifically for audio recording display.
  ///
  /// Example: "02:30" for 2 minutes 30 seconds or "1:15:30" for 1 hour 15 minutes 30 seconds
  static String formatTimestamp(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = (duration.inMinutes % 60);
    final int seconds = (duration.inSeconds % 60);

    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutesStr:$secondsStr';
    } else {
      return '$minutesStr:$secondsStr';
    }
  }

  /// Creates a DateTime for a specific time today.
  ///
  /// Useful for creating reminder times for the current day.
  static DateTime timeToday(TimeOfDay time) {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, time.hour, time.minute);
  }

  /// Creates a DateTime for a specific time tomorrow.
  ///
  /// Useful for creating reminder times for the next day.
  static DateTime timeTomorrow(TimeOfDay time) {
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, time.hour, time.minute);
  }

  /// Determines if a date is in the past.
  static bool isPast(DateTime date) {
    return date.isBefore(DateTime.now());
  }

  /// Determines if a date is in the future.
  static bool isFuture(DateTime date) {
    return date.isAfter(DateTime.now());
  }

  /// Determines if a date is today.
  static bool isToday(DateTime date) {
    final DateTime now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Determines if a date is yesterday.
  static bool isYesterday(DateTime date) {
    final DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }

  /// Determines if a date is tomorrow.
  static bool isTomorrow(DateTime date) {
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day;
  }

  /// Converts a TimeOfDay to a formatted string.
  ///
  /// Example: "2:30 PM"
  static String formatTimeOfDay(TimeOfDay timeOfDay) {
    final DateTime now = DateTime.now();
    final DateTime dateTime = DateTime(
        now.year,
        now.month,
        now.day,
        timeOfDay.hour,
        timeOfDay.minute
    );
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Returns a list of the next 7 days as DateTime objects, including today.
  ///
  /// Useful for showing date selection for upcoming reminders.
  static List<DateTime> getNextSevenDays() {
    final List<DateTime> days = [];
    final DateTime now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      days.add(DateTime(now.year, now.month, now.day + i));
    }

    return days;
  }

  /// Returns a friendly name for a day.
  ///
  /// Example: "Today", "Tomorrow", "Monday", etc.
  static String getFriendlyDayName(DateTime date) {
    if (isToday(date)) {
      return 'Today';
    } else if (isTomorrow(date)) {
      return 'Tomorrow';
    } else {
      return getDayOfWeek(date);
    }
  }
}