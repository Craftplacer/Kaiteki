import "dart:async";
import "dart:convert";
import "dart:developer";

import "package:http/http.dart" as http show Response;
import "package:kaiteki/exceptions/http_exception.dart";
import "package:kaiteki/fediverse/backends/twitter/v2/model/media.dart";
import "package:kaiteki/fediverse/backends/twitter/v2/model/tweet.dart";
import "package:kaiteki/fediverse/backends/twitter/v2/model/user.dart";
import "package:kaiteki/fediverse/backends/twitter/v2/responses/bookmark_response.dart";
import "package:kaiteki/fediverse/backends/twitter/v2/responses/like_response.dart";
import "package:kaiteki/fediverse/backends/twitter/v2/responses/response.dart";
import "package:kaiteki/fediverse/backends/twitter/v2/responses/timeline_response.dart";
import "package:kaiteki/fediverse/backends/twitter/v2/responses/token_response.dart";
import "package:kaiteki/fediverse/backends/twitter/v2/responses/user_response.dart";
import "package:kaiteki/http/http.dart";
import "package:kaiteki/utils/extensions.dart";
import "package:kaiteki/utils/utils.dart";

class TwitterClient {
  late final KaitekiClient client;

  String? _userId;
  String get userId {
    final id = _userId;
    if (id == null) {
      throw StateError("Tried to access user id when it was null");
    }
    return id;
  }

  set userId(String? userId) {
    _userId = userId;
  }

  String? token;

  TwitterClient() {
    client = KaitekiClient(
      baseUri: Uri(scheme: "https", host: "api.twitter.com"),
      checkResponse: _checkResponse,
      intercept: (request) {
        if (token != null) request.headers["Authorization"] = "Bearer $token";
      },
    );
  }

  Future<User> getMe({UserFields userFields = const {}}) async {
    return client.sendRequest(
      HttpMethod.get,
      "2/users/me",
      query: {
        if (userFields.isNotEmpty) "user.fields": userFields.join(","),
      },
    ).then(
      ((json) {
        final map = json as JsonMap;
        return User.fromJson(map["data"] as JsonMap);
      }).fromResponse,
    );
  }

  Future<TweetResponse> getTweet(
    String id, {
    Set<String> expansions = const {},
    TweetFields tweetFields = const {},
    UserFields userFields = const {},
    MediaFields mediaFields = const {},
  }) async {
    return client.sendRequest(
      HttpMethod.get,
      "2/tweets/$userId",
      query: {
        if (expansions.isNotEmpty) "expansions": expansions.join(","),
        if (tweetFields.isNotEmpty) "tweet.fields": tweetFields.join(","),
        if (userFields.isNotEmpty) "user.fields": userFields.join(","),
        if (mediaFields.isNotEmpty) "media.fields": mediaFields.join(","),
      },
    ).then(
      ((j) {
        return TweetResponse.fromJson(
          j as JsonMap,
          Tweet.fromJson.generic,
        );
      }).fromResponse,
    );
  }

  Future<Tweet> createTweet({
    String? text,
    String? inReplyToTweetId,
    Set<String> excludeReplyUserIds = const {},
    String? quoteTweetId,
    TweetReplySettings replySettings = TweetReplySettings.everyone,
  }) async {
    return client
        .sendRequest(
          HttpMethod.post,
          "2/tweets",
          body: {
            if (text != null) "text": text,
            if (replySettings != TweetReplySettings.everyone)
              "reply_settings": replySettings.name,
            if (inReplyToTweetId != null)
              "reply": {
                "in_reply_to_tweet_id": inReplyToTweetId,
                "exclude_reply_user_ids": excludeReplyUserIds.toList(
                  growable: false,
                ),
              },
            if (quoteTweetId != null) "quote_tweet_id": quoteTweetId,
            // "direct_message_deep_link":
            //     "https://twitter.com/messages/compose?recipient_id=$userId"
          }.jsonBody,
        )
        .then(
          ((json) {
            final map = json as JsonMap;
            return Tweet.fromJson(map["data"] as JsonMap);
          }).fromResponse,
        );
  }

  Future<TimelineResponse> getReverseChronologicalTimeline({
    Set<String> expansions = const {},
    TweetFields tweetFields = const {},
    UserFields userFields = const {},
    MediaFields mediaFields = const {},
    String? untilId,
    String? sinceId,
  }) async {
    return client.sendRequest(
      HttpMethod.get,
      "2/users/$userId/timelines/reverse_chronological",
      query: {
        if (expansions.isNotEmpty) "expansions": expansions.join(","),
        if (tweetFields.isNotEmpty) "tweet.fields": tweetFields.join(","),
        if (userFields.isNotEmpty) "user.fields": userFields.join(","),
        if (mediaFields.isNotEmpty) "media.fields": mediaFields.join(","),
        if (untilId != null) "until_id": untilId,
        if (sinceId != null) "since_id": sinceId,
      },
    ).then(TimelineResponse.fromJson.fromResponse);
  }

  Future<TimelineResponse> getUserTweets(
    String id, {
    Set<String> expansions = const {},
    TweetFields tweetFields = const {},
    UserFields userFields = const {},
    MediaFields mediaFields = const {},
    String? untilId,
    String? sinceId,
  }) async {
    return client.sendRequest(
      HttpMethod.get,
      "2/users/$id/tweets",
      query: {
        if (expansions.isNotEmpty) "expansions": expansions.join(","),
        if (tweetFields.isNotEmpty) "tweet.fields": tweetFields.join(","),
        if (userFields.isNotEmpty) "user.fields": userFields.join(","),
        if (mediaFields.isNotEmpty) "media.fields": mediaFields.join(","),
        if (untilId != null) "until_id": untilId,
        if (sinceId != null) "since_id": sinceId,
      },
    ).then(TimelineResponse.fromJson.fromResponse);
  }

  Future<UserResponse> getUser(
    String id, {
    Set<String> expansions = const {},
    TweetFields tweetFields = const {},
    UserFields userFields = const {},
  }) async {
    return client.sendRequest(
      HttpMethod.get,
      "2/users/$id",
      query: {
        if (expansions.isNotEmpty) "expansions": expansions.join(","),
        if (tweetFields.isNotEmpty) "tweet.fields": tweetFields.join(","),
        if (userFields.isNotEmpty) "user.fields": userFields.join(","),
      },
    ).then(UserResponse.fromJson.fromResponse);
  }

  void _checkResponse(http.Response response) {
    if (response.isSuccessful) return;

    String? error;
    String? description;

    try {
      final json = jsonDecode(response.body) as JsonMap;
      error = json["error"] as String;
      description = json["error_description"] as String;
    } catch (e, s) {
      log(
        "Error while parsing error response: ${response.body}",
        name: "TwitterClient",
        error: e,
        stackTrace: s,
      );
    }

    if (error == null || description == null) {
      throw HttpException.fromResponse(response);
    } else {
      throw Exception("$error: $description");
    }
  }

  Future<TweetListResponse> searchRecentTweets(
    String query, {
    Set<String> expansions = const {},
    TweetFields tweetFields = const {},
    UserFields userFields = const {},
    MediaFields mediaFields = const {},
  }) async {
    return client.sendRequest(
      HttpMethod.get,
      "2/tweets/search/recent",
      query: {
        "query": query,
        if (expansions.isNotEmpty) "expansions": expansions.join(","),
        if (tweetFields.isNotEmpty) "tweet.fields": tweetFields.join(","),
        if (userFields.isNotEmpty) "user.fields": userFields.join(","),
        if (mediaFields.isNotEmpty) "media.fields": mediaFields.join(","),
      },
    ).then(
      ((j) {
        return TweetListResponse.fromJson(
          j as JsonMap,
          Tweet.fromJson.genericList,
        );
      }).fromResponse,
    );
  }

  Future<TokenResponse> getToken({
    required String clientId,
    required String grantType,
    String? code,
    String? redirectUri,
    String? codeVerifier,
    String? refreshToken,
  }) async {
    return client.sendRequest(
      HttpMethod.post,
      "2/oauth2/token",
      query: {
        "grant_type": grantType,
        "client_id": clientId,
        if (codeVerifier != null) "code_verifier": codeVerifier,
        if (redirectUri != null) "redirect_uri": redirectUri,
        if (code != null) "code": code,
        if (refreshToken != null) "refresh_token": refreshToken,
      },
    ).then(TokenResponse.fromJson.fromResponse);
  }

  Future<BookmarkResponse> bookmarkTweet(String tweetId) async {
    return client
        .sendRequest(
          HttpMethod.post,
          "2/users/$userId/bookmarks",
          body: {"tweet_id": tweetId}.jsonBody,
        )
        .then(
          ((j) {
            return BookmarkResponse.fromJson(
              j as JsonMap,
              BookmarkResponseData.fromJson.generic,
            );
          }).fromResponse,
        );
  }

  Future<BookmarkResponse> unbookmarkTweet(String tweetId) async {
    return client
        .sendRequest(
          HttpMethod.delete,
          "2/users/$userId/bookmarks/$tweetId",
        )
        .then(
          BookmarkResponse.fromJson.fromResponse(
            BookmarkResponseData.fromJson.generic,
          ),
        );
  }

  Future<TweetListResponse> getBookmarks({
    Set<String> expansions = const {},
    TweetFields tweetFields = const {},
    UserFields userFields = const {},
    MediaFields mediaFields = const {},
  }) async {
    final urlQuery = {
      if (expansions.isNotEmpty) "expansions": expansions.join(","),
      if (tweetFields.isNotEmpty) "tweet.fields": tweetFields.join(","),
      if (userFields.isNotEmpty) "user.fields": userFields.join(","),
      if (mediaFields.isNotEmpty) "media.fields": mediaFields.join(","),
    };

    return client
        .sendRequest(
          HttpMethod.get,
          "2/users/$userId/bookmarks${urlQuery.toQueryString()}",
        )
        .then(
          TweetListResponse.fromJson.fromResponse(Tweet.fromJson.genericList),
        );
  }

  Future<LikeResponse> likeTweet(String tweetId) async {
    return client
        .sendRequest(
          HttpMethod.post,
          "2/users/$userId/likes",
          body: {"tweet_id": tweetId}.jsonBody,
        )
        .then(
          LikeResponse.fromJson.fromResponse(LikeResponseData.fromJson.generic),
        );
  }

  Future<LikeResponse> unlikeTweet(String tweetId) async {
    return client
        .sendRequest(HttpMethod.delete, "2/users/$userId/likes/$tweetId")
        .then(
          LikeResponse.fromJson.fromResponse(LikeResponseData.fromJson.generic),
        );
  }

  Future<LikingUsersResponse> getLikingUsers(
    String id, {
    TweetFields tweetFields = const {},
    UserFields userFields = const {},
  }) async {
    return client.sendRequest(HttpMethod.delete, "2/users/$userId/likes").then(
      LikingUsersResponse.fromJson.fromResponse((obj) {
        return User.fromJson.genericList(obj)!;
      }),
    );
  }
}
