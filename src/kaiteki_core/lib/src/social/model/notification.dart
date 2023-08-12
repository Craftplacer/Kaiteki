import 'post.dart';
import 'user.dart';

class Notification {
  final String id;
  final User? user;
  final Post? post;
  final NotificationType type;
  final bool? unread;
  final DateTime createdAt;

  const Notification({
    required this.id,
    required this.type,
    required this.createdAt,
    this.user,
    this.post,
    this.unread,
  });
}

class GroupedNotification implements Notification {
  final List<Notification> notifications;

  @override
  DateTime get createdAt => notifications.last.createdAt;

  @override
  bool get unread => notifications.any((e) => e.unread == true);

  @override
  Post? get post => notifications.last.post;

  @override
  NotificationType get type => notifications.first.type;

  @override
  User? get user => notifications.last.user;

  const GroupedNotification(this.notifications);

  @override
  String get id => notifications.first.id;
}

enum NotificationType {
  /// Someone has liked the user's post
  liked,

  /// Someone has repeated the user's post
  repeated,

  /// Someone has reacted to the user's post
  reacted,

  /// Someone has followed the user
  followed,

  /// The user has been mentioned in a post
  mentioned,

  /// Someone wants to follow the user
  followRequest,

  /// The user has been invited to a group.
  groupInvite,

  /// A poll that the user participated in or created has ended
  pollEnded,

  /// The user's post has been quoted by someone else
  quoted,

  /// Someone replied to the user's post
  replied,

  /// A post that the user has interacted with has been edited
  updated,

  /// Someone sent a report
  reported,

  /// A new user has joined the instance
  signedUp,

  /// Someone has made a new post
  newPost,

  // Kaiteki received a notification type that it does not support
  unsupported,

  /// Someone has moved to a new account
  userMigrated,
}
