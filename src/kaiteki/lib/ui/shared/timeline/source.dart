import "package:kaiteki_core/kaiteki_core.dart";

sealed class TimelineSource {
  Future<Iterable<Post>> fetch(
    BackendAdapter adapter,
    TimelineQuery<String>? query,
  );
}

class UserTimelineSource implements TimelineSource {
  final String userId;

  const UserTimelineSource(this.userId);

  @override
  Future<Iterable<Post>> fetch(
    BackendAdapter adapter,
    TimelineQuery<String>? query,
  ) {
    return adapter.getStatusesOfUserById(userId, query: query);
  }

  @override
  int get hashCode => userId.hashCode;

  @override
  bool operator ==(covariant UserTimelineSource other) =>
      userId == other.userId;
}

class StandardTimelineSource implements TimelineSource {
  final TimelineType type;

  const StandardTimelineSource(this.type);

  @override
  Future<Iterable<Post>> fetch(
    BackendAdapter adapter,
    TimelineQuery<String>? query,
  ) {
    return adapter.getTimeline(type, query: query);
  }

  @override
  int get hashCode => type.hashCode;

  @override
  bool operator ==(covariant StandardTimelineSource other) =>
      type == other.type;
}

class ListTimelineSource implements TimelineSource {
  final String listId;

  const ListTimelineSource(this.listId);

  @override
  Future<Iterable<Post>> fetch(
    BackendAdapter adapter,
    TimelineQuery<String>? query,
  ) {
    if (adapter is! ListSupport) {
      throw ArgumentError.value(
        adapter,
        "adapter",
        "Adapter needs to support lists in order to fetch them.",
      );
    }

    final lists = adapter as ListSupport;
    return lists.getListPosts(listId, query: query);
  }

  @override
  int get hashCode => listId.hashCode;

  @override
  bool operator ==(covariant ListTimelineSource other) =>
      listId == other.listId;
}
