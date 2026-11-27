import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../models/review.dart';
import '../models/review_draft.dart';
import 'auth_service.dart';

// TYPE ADAPTER (Hive): tells Hive how to write/read a ReviewDraft as binary

class ReviewDraftAdapter extends TypeAdapter<ReviewDraft> {
  static const int kTypeId = 1; // unique in the whole app; never change it once drafts are stored
  static const int _formatVersion = 1;

  @override
  final int typeId = kTypeId;

  @override
  ReviewDraft read(BinaryReader reader) {
    final version = reader.readByte();
    if (version != _formatVersion) {
      throw HiveError('Unknown ReviewDraft format version $version (expected $_formatVersion)');
    }
    // Same order as write()
    return ReviewDraft(
      userId: reader.readInt(),
      restaurantId: reader.readString(),
      ratings: ReviewRatings(
        taste: reader.readInt(),
        attention: reader.readInt(),
        price: reader.readInt(),
        options: reader.readInt(),
      ),
      dietaryOptions: reader.readStringList(),
      comment: reader.readString(),
      savedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, ReviewDraft obj) {
    writer
      ..writeByte(_formatVersion)
      ..writeInt(obj.userId)
      ..writeString(obj.restaurantId)
      ..writeInt(obj.ratings.taste)
      ..writeInt(obj.ratings.attention)
      ..writeInt(obj.ratings.price)
      ..writeInt(obj.ratings.options)
      ..writeStringList(obj.dietaryOptions)
      ..writeString(obj.comment)
      ..writeInt(obj.savedAt.millisecondsSinceEpoch);
  }
}

// LOCAL STORAGE (Hive, typed box): one review draft per restaurant, key = restaurantId.
class ReviewDraftStore {
  static const _boxName = 'review_drafts';
  static bool _initialized = false;

  static Future<Box<ReviewDraft>> _box() async {
    if (!_initialized) {
      await Hive.initFlutter();
      _initialized = true;
    }
    if (!Hive.isAdapterRegistered(ReviewDraftAdapter.kTypeId)) {
      Hive.registerAdapter(ReviewDraftAdapter());
    }
    return Hive.openBox<ReviewDraft>(_boxName);
  }

  // null if there is no draft OR it belongs to another account (same protection as Kotlin's ensureDataOwner)
  static Future<ReviewDraft?> load(String restaurantId) async {
    try {
      final draft = (await _box()).get(restaurantId);
      if (draft == null || draft.userId != AuthService.currentUser.value?.id) return null;
      return draft;
    } catch (e) {
      debugPrint('Could not read the review draft of $restaurantId: $e');
      return null;
    }
  }

  // A new draft replaces the previous one of the same restaurant; an empty form deletes it (like Kotlin)
  static Future<void> save(ReviewDraft draft) async {
    try {
      final box = await _box();
      if (draft.hasContent) {
        await box.put(draft.restaurantId, draft);
      } else {
        await box.delete(draft.restaurantId);
      }
    } catch (e) {
      debugPrint('Could not save the review draft of ${draft.restaurantId}: $e');
    }
  }

  static Future<void> delete(String restaurantId) async {
    try {
      await (await _box()).delete(restaurantId);
    } catch (e) {
      debugPrint('Could not delete the review draft of $restaurantId: $e');
    }
  }

  // Logout: drafts are this user's unsent answers
  static Future<void> clearAll() async {
    try {
      await (await _box()).clear();
    } catch (e) {
      debugPrint('Could not clear the review drafts: $e');
    }
  }
}
