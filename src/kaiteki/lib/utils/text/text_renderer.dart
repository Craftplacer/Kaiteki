import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:kaiteki/di.dart';
import 'package:kaiteki/fediverse/model/emoji/emoji.dart';
import 'package:kaiteki/fediverse/model/user/reference.dart';
import 'package:kaiteki/fediverse/model/user/user.dart';
import 'package:kaiteki/theming/kaiteki/text_theme.dart';
import 'package:kaiteki/ui/shared/emoji/emoji_widget.dart';
import 'package:kaiteki/ui/shared/posts/avatar_widget.dart';
import 'package:kaiteki/utils/extensions.dart';
import 'package:kaiteki/utils/text/elements.dart';
import 'package:kaiteki/utils/text/parsers.dart';
import 'package:kaiteki/utils/utils.dart';

typedef RegExpMatchElementBuilder = Element Function(
  RegExpMatch match,
  String text,
);

class TextContext {
  final List<UserReference>? users;
  final List<Emoji>? emojis;
  final List<UserReference>? excludedUsers;

  TextContext({this.users, this.emojis, this.excludedUsers});
}

class TextRenderer {
  // TODO(Craftplacer): Use appropiate parser on specific instances
  final TextParser parser = const MastodonHtmlTextParser();

  const TextRenderer();

  InlineSpan render(
    BuildContext context,
    String text, {
    TextContext? textContext,
    Function()? onTextTap,
    required Function(UserReference reference) onUserClick,
  }) {
    final renderedElements = renderChildren(
      context,
      parser.parse(text).parseWith(const SocialTextParser()),
      textContext ?? TextContext(),
      Theme.of(context).ktkTextTheme,
      onUserClick: onUserClick,
      onTextTap: onTextTap,
    );
    return TextSpan(children: renderedElements.toList(growable: false));
  }

  InlineSpan? _renderElement(
    BuildContext context,
    Element element,
    TextContext textContext,
    KaitekiTextTheme? theme, {
    required Function(UserReference) onUserClick,
    Function()? onTextTap,
  }) {
    final childrenSpans = renderChildren(
      context,
      element.children,
      textContext,
      theme,
      onUserClick: onUserClick,
      onTextTap: onTextTap,
    );

    if (element is TextElement) {
      return renderText(context, element, childrenSpans, onTextTap);
    }
    if (element is LinkElement) {
      return renderLink(
        context,
        element,
        childrenSpans,
        style: theme?.linkTextStyle,
      );
    }
    if (element is HashtagElement) {
      return renderHashtag(
        context,
        textContext,
        element,
        style: theme?.hashtagTextStyle,
      );
    }
    if (element is MentionElement) {
      return renderMention(
        context,
        textContext,
        element,
        onUserClick: onUserClick,
        style: theme?.mentionTextStyle,
      );
    }
    if (element is EmojiElement) {
      return renderEmoji(
        textContext,
        element,
        scale: theme?.emojiScale,
        onTextTap: onTextTap,
      );
    }

    if (childrenSpans.isNotEmpty == true) {
      return TextSpan(children: childrenSpans);
    }

    return renderFallbackSpan(element);
  }

  InlineSpan renderFallbackSpan(Element element) {
    return TextSpan(
      text: "[NIY ${element.runtimeType}]",
      style: const TextStyle(
        backgroundColor: Colors.red,
        color: Colors.white,
      ),
    );
  }

  List<InlineSpan> renderChildren(
    BuildContext context,
    List<Element>? children,
    TextContext textContext,
    KaitekiTextTheme? theme, {
    required Function(UserReference reference) onUserClick,
    Function()? onTextTap,
  }) {
    final spans = <InlineSpan>[];

    if (children != null) {
      for (final child in children) {
        final element = _renderElement(
          context,
          child,
          textContext,
          theme,
          onUserClick: onUserClick,
          onTextTap: onTextTap,
        );

        if (element != null) {
          spans.add(element);
        }
      }
    }

    return spans;
  }

  InlineSpan renderText(
    BuildContext context,
    TextElement element,
    List<InlineSpan>? childrenSpans,
    Function()? onTextTap,
  ) {
    final InlineSpan span = TextSpan(
      text: element.text,
      style: element.getFlutterTextStyle(context),
      children: childrenSpans,
      recognizer: onTextTap != null
          ? (TapGestureRecognizer()..onTap = onTextTap)
          : null,
    );

    if (element.style?.blur == true) {
      return WidgetSpan(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: 8.0,
            sigmaY: 8.0,
          ),
          child: Text(element.text!),
        ),
      );
    }

    return span;
  }

  InlineSpan? renderMention(
    BuildContext buildContext,
    TextContext textContext,
    MentionElement element, {
    required Function(UserReference reference) onUserClick,
    TextStyle? style,
  }) {
    final i = textContext.users?.indexWhere(element.reference.matches) ?? -1;
    final reference = i == -1 ? element.reference : textContext.users![i];

    final isExcluded = textContext.excludedUsers?.any(reference.matches);

    if (isExcluded == true) {
      return null;
    }

    const useUserChip = false;

    // ignore: dead_code
    if (useUserChip) {
      return WidgetSpan(
        child: UserChip(reference: reference),
        baseline: TextBaseline.alphabetic,
        alignment: PlaceholderAlignment.middle,
      );
    } else {
      return TextSpan(
        recognizer: TapGestureRecognizer()
          ..onTap = () => onUserClick(reference),
        text: reference.toString(),
        style: style,
      );
    }
  }

  TextSpan renderHashtag(
    BuildContext context,
    TextContext textContext,
    HashtagElement element, {
    TextStyle? style,
  }) {
    final inheritedTextStyle = style ?? DefaultTextStyle.of(context).style;
    final color = inheritedTextStyle.color!.withOpacity(.35);
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: '#', style: TextStyle(color: color)),
        TextSpan(text: element.name),
      ],
    );
  }

  TextSpan renderLink(
    BuildContext context,
    LinkElement link,
    List<InlineSpan> children, {
    TextStyle? style,
  }) {
    // FIXME(Craftplacer): We should be passing down the "click-ability" to the children.

    final recognizer = TapGestureRecognizer()
      ..onTap = () => context.launchUrl(link.destination.toString());

    return TextSpan(
      style: style,
      recognizer: recognizer,
      text: link.allText,
    );
  }

  InlineSpan renderEmoji(
    TextContext textContext,
    EmojiElement element, {
    double? scale,
    Function()? onTextTap,
  }) {
    assert(
      textContext.emojis != null,
      "An emoji is about to be rendered, but no emojis were provided.",
    );

    final emoji = textContext.emojis?.firstWhereOrNull((e) {
      return e.short == element.name;
    });

    if (emoji == null) return TextSpan(text: ":${element.name}:");

    // FIXME(Craftplacer): Change this piece widget into an EmojiSpan. Added Builder to fix scaling with inherited font size.
    return WidgetSpan(
      child: Builder(
        builder: (context) {
          final inheritedFontSize = getLocalFontSize(context);
          return EmojiWidget(
            emoji: emoji,
            size: inheritedFontSize * (scale ?? 1.0),
            onTextTap: onTextTap,
          );
        },
      ),
      baseline: TextBaseline.alphabetic,
      alignment: PlaceholderAlignment.middle,
    );
  }
}

extension TextElementExtension on TextElement {
  TextStyle getFlutterTextStyle(BuildContext context) {
    final style = this.style;

    if (style == null) {
      return const TextStyle();
    }

    final inheritedSize = DefaultTextStyle.of(context).style.fontSize;

    return TextStyle(
      fontWeight: style.bold == true ? FontWeight.bold : null,
      fontStyle: style.italic == true ? FontStyle.italic : null,
      fontSize: style.scale != 1.0 ? (inheritedSize! * style.scale) : null,
    );
  }
}

class UserChip extends ConsumerWidget {
  final UserReference reference;
  final User? user;

  const UserChip({
    super.key,
    required this.reference,
    this.user,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adapter = ref.watch(adapterProvider);
    return FutureBuilder<User?>(
      initialData: user,
      future: reference.resolve(adapter),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final user = snapshot.data!;

          return Tooltip(
            message: user.handle.toString(),
            child: ActionChip(
              avatar: AvatarWidget(user, size: 24),
              label: Text.rich(user.renderDisplayName(context, ref)),
              onPressed: () => context.showUser(user, ref),
            ),
          );
        } else {
          return Chip(label: Text(fallbackText));
        }
      },
    );
  }

  String get fallbackText {
    if (reference.username != null) {
      return reference.host != null
          ? "@${reference.username}@${reference.host}"
          : "@${reference.username}";
    }

    if (reference.remoteUrl != null) {
      return reference.remoteUrl!;
    }

    return "Unknown User";
  }
}
