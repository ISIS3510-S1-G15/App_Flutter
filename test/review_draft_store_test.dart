import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:app_flutter/models/review.dart';
import 'package:app_flutter/models/review_draft.dart';
import 'package:app_flutter/services/review_draft_store.dart';

// Writes a draft exactly like the real adapter but with ANOTHER format version byte, to simulate a draft
// saved by a future (or corrupted) version of the app
class _FutureVersionAdapter extends TypeAdapter<ReviewDraft> {
  @override
  final int typeId = ReviewDraftAdapter.kTypeId;

  @override
  ReviewDraft read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, ReviewDraft obj) {
    writer
      ..writeByte(2)
      ..writeInt(obj.userId)
      ..writeString(obj.restaurantId);
  }
}

ReviewDraft _draft({
  ReviewRatings ratings = const ReviewRatings(),
  List<String> diets = const [],
  String comment = '',
}) =>
    ReviewDraft(
      userId: 7,
      restaurantId: 'r1',
      ratings: ratings,
      dietaryOptions: diets,
      comment: comment,
      savedAt: DateTime(2026, 11, 27, 9, 30, 15, 123),
    );

void main() {
  // Real Hive on a temp folder, without Flutter (Hive.initFlutter needs path_provider)
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('review_drafts_test');
    Hive.init(dir.path);
    // Same guard as ReviewDraftStore._box(): registering twice throws
    if (!Hive.isAdapterRegistered(ReviewDraftAdapter.kTypeId)) Hive.registerAdapter(ReviewDraftAdapter());
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('adapter round trip: every field survives closing and reopening the box', () async {
    final original = _draft(
      ratings: const ReviewRatings(taste: 5, attention: 4, price: 2, options: 1),
      diets: const ['Vegan options', 'Gluten-free'],
      comment: 'Arepa deliciosa, atención rápida 😋🔥 ñandú',
    );
    var box = await Hive.openBox<ReviewDraft>('review_drafts');
    await box.put('r1', original);
    await box.close();

    // Reopened = read back from the binary file on disk, as after an app restart
    box = await Hive.openBox<ReviewDraft>('review_drafts');
    final copy = box.get('r1')!;
    expect(copy.userId, 7);
    expect(copy.restaurantId, 'r1');
    expect(copy.ratings.toJson(), original.ratings.toJson());
    expect(copy.dietaryOptions, ['Vegan options', 'Gluten-free']);
    expect(copy.comment, original.comment);
    expect(copy.savedAt, original.savedAt);
  });

  test('unknown format version: read throws instead of returning wrong data', () async {
    Hive.registerAdapter(_FutureVersionAdapter(), override: true);
    final writer = await Hive.openBox<ReviewDraft>('review_drafts');
    await writer.put('r1', _draft());
    await writer.close();

    // Back to the real adapter. Lazy box: the value is only decoded on get(), where the version is checked
    Hive.registerAdapter(ReviewDraftAdapter(), override: true);
    final box = await Hive.openLazyBox<ReviewDraft>('review_drafts');
    await expectLater(box.get('r1'), throwsA(isA<HiveError>()));
  });

  group('hasContent', () {
    test('empty form -> false', () {
      expect(_draft().hasContent, isFalse);
    });
    test('only spaces in the comment -> false', () {
      expect(_draft(comment: '   \n ').hasContent, isFalse);
    });
    test('one star -> true', () {
      expect(_draft(ratings: const ReviewRatings(price: 1)).hasContent, isTrue);
    });
    test('only one dietary option -> true', () {
      expect(_draft(diets: const ['Halal']).hasContent, isTrue);
    });
  });
}
