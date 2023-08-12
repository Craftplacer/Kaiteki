import "package:flutter/material.dart";
import "package:kaiteki/di.dart";
import "package:kaiteki/utils/extensions/build_context.dart";
import "package:kaiteki_core/model.dart";

class FallbackAttachmentWidget extends StatelessWidget {
  const FallbackAttachmentWidget({
    required this.attachment,
    super.key,
  });

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Semantics(
      button: true,
      enabled: true,
      tooltip: l10n.viewOnlineButtonLabel,
      child: InkWell(
        child: Icon(
          Icons.open_in_new_rounded,
          size: 48,
          color: Theme.of(context).disabledColor,
        ),
        onTap: () => context.launchUrl(attachment.url.toString()),
      ),
    );
  }
}
