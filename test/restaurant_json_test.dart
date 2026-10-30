import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/models/restaurant.dart';

void main() {
  test('parses the backend restaurant JSON', () {
    final data = jsonDecode(File('test/fixtures/restaurants_api.json').readAsStringSync()) as Map<String, dynamic>;
    final list = (data['restaurants'] as List).cast<Map<String, dynamic>>().map(Restaurant.fromJson).toList();
    expect(list, isNotEmpty);
    final starbucks = list.firstWhere((r) => r.id == '1');
    expect(starbucks.name, 'Starbucks');
    expect(starbucks.image, 'web/icons/starbucks.jpeg');
    expect(starbucks.menu, isNotEmpty);
    expect(starbucks.menu.first.items.first.desc, isNotEmpty);
  });
}
