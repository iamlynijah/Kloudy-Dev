import 'dart:math';
import '../models/streak.dart';

/// Manages friend connections and invite codes for streak competition.
///
/// This is in-memory only for now (resets on app restart) — it exists so
/// the UI and flow can be fully built and tested before the real
/// Supabase tables (`friend_connections`, `streak_shares`) are designed.
/// Swapping this for real persistence later means replacing the bodies
/// of these methods; the call sites in the UI don't need to change.
class FriendService {
  FriendService._();
  static final FriendService instance = FriendService._();

  final List<StreakFriend> _friends = [];
  String? _myInviteCode;

  List<StreakFriend> get friends => List.unmodifiable(_friends);

  /// Generates (or returns the existing) invite code for the current
  /// user to share with a friend. Codes are short and uppercase so
  /// they're easy to read aloud or text — e.g. "KX7QPL".
  String getOrCreateMyInviteCode() {
    _myInviteCode ??= _generateCode();
    return _myInviteCode!;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1 confusion
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Connects to a friend using a code they shared. Returns the new
  /// friend on success, or null if the code looks invalid.
  ///
  /// Mock implementation: any well-formed 6-character code "succeeds"
  /// and creates a placeholder friend, since there's no backend lookup
  /// yet. Replace with a real Supabase lookup by invite code later.
  StreakFriend? connectWithCode(String code) {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.length != 6) return null;

    final friend = StreakFriend(
      id: 'friend-${_friends.length + 1}',
      name: 'Friend $trimmed',
      sharedStreakNames: [],
    );
    _friends.add(friend);
    return friend;
  }

  void removeFriend(String friendId) {
    _friends.removeWhere((f) => f.id == friendId);
  }
}