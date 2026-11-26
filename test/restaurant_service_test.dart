import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/services/restaurant_service.dart';

void main() {
  test('age of the saved restaurant list shown while offline', () {
    final now = DateTime(2026, 11, 26, 12);
    String ago(Duration d) => RestaurantService.ago(now.subtract(d), now: now);
    expect(ago(const Duration(seconds: 20)), 'just now');
    expect(ago(const Duration(minutes: 15)), '15 min ago');
    expect(ago(const Duration(hours: 3)), '3 h ago');
    expect(ago(const Duration(days: 1)), '1 day ago');
    expect(ago(const Duration(days: 4)), '4 days ago');
  });
}
