import '../models/streak.dart';
import 'supabase_service.dart';

/// Supabase-backed friend connections and opt-in shared streak lookup.
class FriendService {
  FriendService._();
  static final FriendService instance = FriendService._();

  final List<StreakFriend> _friends = [];
  List<StreakFriend> get friends => List.unmodifiable(_friends);

  Future<String> getOrCreateMyInviteCode() async {
    if (SupabaseService.currentUser == null) {
      throw Exception('Sign in to invite friends.');
    }
    return SupabaseService.createFriendInvite();
  }

  Future<String> createStreakInvite(Streak streak) {
    return SupabaseService.createStreakInvite(
      streakName: streak.name,
      cadence: streak.cadence.name,
    );
  }

  Future<List<StreakFriend>> loadFriends() async {
    if (SupabaseService.currentUser == null) {
      _friends.clear();
      return friends;
    }
    final rows = await SupabaseService.fetchFriends();
    _friends
      ..clear()
      ..addAll(
        rows.map(
          (row) => StreakFriend(
            id: row['friend_user_id'] as String,
            name: row['display_name'] as String? ?? 'Kloudy friend',
            sharedStreakNames: const [],
          ),
        ),
      );
    return friends;
  }

  Future<StreakFriend?> connectWithCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.length != 6) return null;
    final connectionId = await SupabaseService.acceptFriendInvite(trimmed);
    await loadFriends();
    return _friends.cast<StreakFriend?>().firstWhere(
      (friend) => friend != null && friend.id == connectionId,
      orElse: () => null,
    );
  }

  Future<Map<String, dynamic>?> sharedHabit(
    String friendId,
    String habitName,
  ) => SupabaseService.fetchSharedHabit(friendId, habitName);

  Future<void> removeFriend(String friendId) async {
    await SupabaseService.removeFriend(friendId);
    _friends.removeWhere((friend) => friend.id == friendId);
  }
}
