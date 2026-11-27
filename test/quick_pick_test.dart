import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/models/quick_pick.dart';
import 'package:app_flutter/models/restaurant.dart';

final _savedAt = DateTime(2026, 11, 27, 12, 5);
final _noon = DateTime(2026, 11, 27, 12, 30); // Lunch

Restaurant _restaurant(String id, {String hours = '7:00am - 9:00pm'}) => Restaurant(
      id: id,
      name: 'Place $id',
      location: 'Building $id',
      category: 'Café',
      image: '',
      isOpen: true,
      rating: 4,
      reviews: 10,
      price: r'$',
      waitTime: '5 min',
      tags: const [],
      hours: hours,
    );

Map<String, dynamic> _json({String? kind = 'your_usual', List<String> candidates = const ['3', '1'],
        double? mine = 184.2, double? campus = 95.0}) =>
    {
      'meal_slot': 'Lunch',
      'kind': kind,
      'candidates': candidates,
      'times_chosen': 5,
      'my_avg_seconds': mine,
      'campus_avg_seconds': campus,
      'my_selections': 7,
    };

QuickPick _pick({String? kind = 'your_usual', List<String> candidates = const ['3', '1'], double? mine = 184,
        double? campus = 95}) =>
    QuickPick.fromJson(_json(kind: kind, candidates: candidates, mine: mine, campus: campus), savedAt: _savedAt);

void main() {
  group('QuickPick.fromJson', () {
    test('your_usual', () {
      final p = _pick();
      expect(p.kind, QuickPickKind.yourUsual);
      expect(p.mealSlot, 'Lunch');
      expect(p.candidates, ['3', '1']);
      expect(p.timesChosen, 5);
      expect(p.myAvgSeconds, 184);
      expect(p.campusAvgSeconds, 95);
      expect(p.mySelections, 7);
      expect(p.fromCache, isFalse);
    });

    test('campus_favorite', () {
      expect(_pick(kind: 'campus_favorite', mine: null).kind, QuickPickKind.campusFavorite);
    });

    test('null kind = nothing to suggest', () {
      expect(_pick(kind: null).kind, isNull);
    });

    test('toJson / fromStored round trip keeps every field and marks it as cached', () {
      for (final kind in ['your_usual', 'campus_favorite', null]) {
        final original = _pick(kind: kind);
        final copy = QuickPick.fromStored(original.toJson());
        expect(copy.kind, original.kind);
        expect(copy.mealSlot, original.mealSlot);
        expect(copy.candidates, original.candidates);
        expect(copy.timesChosen, original.timesChosen);
        expect(copy.myAvgSeconds, original.myAvgSeconds);
        expect(copy.campusAvgSeconds, original.campusAvgSeconds);
        expect(copy.mySelections, original.mySelections);
        expect(copy.savedAt, original.savedAt);
        expect(copy.fromCache, isTrue);
      }
    });
  });

  group('resolveQuickPick', () {
    final catalog = [_restaurant('1'), _restaurant('2'), _restaurant('3')];

    test('returns the first open candidate', () {
      expect(resolveQuickPick(_pick(candidates: ['3', '1']), catalog, _noon)!.id, '3');
    });

    test('skips a closed candidate and one missing from the catalog', () {
      final withClosed = [_restaurant('1'), _restaurant('2'), _restaurant('9', hours: '6:00am - 7:00am')];
      // '9' is closed at noon, '7' does not exist -> '2'
      expect(resolveQuickPick(_pick(candidates: ['9', '7', '2']), withClosed, _noon)!.id, '2');
    });

    test('null when kind is null, when nothing is open, or when there is no pick', () {
      expect(resolveQuickPick(_pick(kind: null), catalog, _noon), isNull);
      final allClosed = [_restaurant('3', hours: '6:00am - 7:00am')];
      expect(resolveQuickPick(_pick(candidates: ['3']), allClosed, _noon), isNull);
      expect(resolveQuickPick(null, catalog, _noon), isNull);
    });
  });

  group('quickPickFeedback', () {
    test('faster than the own average -> seconds vs. "about 3 min at lunch"', () {
      final text = quickPickFeedback(const Duration(seconds: 12), _pick(mine: 184));
      expect(text, contains('12 s'));
      expect(text, contains('about 3 min at lunch'));
      expect(text, contains('you usually take'));
    });

    test('slower than usual -> null (no fake improvement)', () {
      expect(quickPickFeedback(const Duration(seconds: 200), _pick(mine: 184)), isNull);
    });

    test('no own average -> the campus one', () {
      final text = quickPickFeedback(const Duration(seconds: 30), _pick(mine: null, campus: 150));
      expect(text, contains('students usually take about 3 min at lunch'));
    });

    test('more than a minute -> "about N min"', () {
      final text = quickPickFeedback(const Duration(seconds: 125), _pick(mine: 400));
      expect(text, contains('Picked in about 2 min'));
    });

    test('no reference at all -> null', () {
      expect(quickPickFeedback(const Duration(seconds: 5), _pick(mine: null, campus: null)), isNull);
    });
  });
}
