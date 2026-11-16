import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/formatters/age_formatter.dart';

void main() {
  final now = DateTime(2026, 11, 14, 12);

  test('under an hour reads as "moins d’une heure"', () {
    expect(
      formatAge(now.subtract(const Duration(minutes: 20)), now: now),
      'il y a moins d’une heure',
    );
    // A clock a little ahead of the server never shows a negative age.
    expect(
      formatAge(now.add(const Duration(minutes: 5)), now: now),
      'il y a moins d’une heure',
    );
  });

  test('under a day counts the hours', () {
    expect(
      formatAge(now.subtract(const Duration(hours: 2)), now: now),
      'il y a 2 h',
    );
  });

  test('yesterday, then days up to a week', () {
    expect(
      formatAge(now.subtract(const Duration(hours: 30)), now: now),
      'hier',
    );
    expect(
      formatAge(now.subtract(const Duration(days: 3)), now: now),
      'il y a 3 j',
    );
  });

  test('a week or more gives the date', () {
    expect(formatAge(DateTime(2026, 11, 3, 9), now: now), 'le 3 nov.');
    expect(formatAge(DateTime(2026, 1, 20, 9), now: now), 'le 20 janv.');
  });
}
