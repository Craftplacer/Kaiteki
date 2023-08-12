import "package:flutter/material.dart";
import "package:kaiteki/di.dart";
import "package:kaiteki/theming/kaiteki/text_theme.dart";
import "package:kaiteki/ui/shared/common.dart";
import "package:kaiteki/ui/shared/posts/post_widget.dart";
import "package:kaiteki/utils/extensions.dart";
import "package:kaiteki_core/model.dart";

class ReplyBar extends ConsumerWidget {
  const ReplyBar({
    super.key,
    this.textStyle,
    required this.post,
    this.onTap,
  });

  final VoidCallback? onTap;
  final TextStyle? textStyle;
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disabledColor = Theme.of(context).disabledColor;
    final l10n = context.l10n;
    final adapter = ref.watch(adapterProvider);
    final userTextStyle = Theme.of(context).ktkTextTheme?.linkTextStyle ??
        DefaultKaitekiTextTheme(context).linkTextStyle;

    return Padding(
      padding: kPostPadding,
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: onTap,
        child: FutureBuilder<User?>(
          future: UserReference(_getUserId()).resolve(adapter),
          builder: (context, snapshot) {
            final span = snapshot.hasData
                ? snapshot.data!.renderDisplayName(context, ref)
                : TextSpan(text: _getText());

            return Text.rich(
              TextSpan(
                style: userTextStyle,
                children: [
                  // TODO(Craftplacer): refactor the following widget pattern to a future "IconSpan"
                  WidgetSpan(
                    child: Directionality(
                      textDirection: Directionality.of(context).inverted,
                      child: Icon(
                        Icons.reply_rounded,
                        size: getLocalFontSize(context) * 1.25,
                        color: disabledColor,
                      ),
                    ),
                  ),
                  TextSpan(
                    text: " ${l10n.replyTo} ",
                    style: TextStyle(color: disabledColor),
                  ),
                  span,
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _getText() {
    final reference = post.replyToUser;

    if (reference == null) return "unknown user";

    final user = reference.data;
    if (user != null) return "@${user.username}";

    return reference.id;
  }

  String _getUserId() {
    final authorId = post.replyToUser?.id;
    if (authorId != null) return authorId;

    final authorIdFromPost = post.replyTo?.data?.author.id;
    if (authorIdFromPost != null) return authorIdFromPost;

    throw Exception("Can't find user id as reply");
  }
}
