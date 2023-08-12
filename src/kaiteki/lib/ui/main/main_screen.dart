import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:go_router/go_router.dart";
import "package:kaiteki/di.dart";
import "package:kaiteki/fediverse/services/notifications.dart";
import "package:kaiteki/fediverse/services/timeline.dart";
import "package:kaiteki/preferences/app_experiment.dart";
import "package:kaiteki/ui/main/pages/bookmarks.dart";
import "package:kaiteki/ui/main/pages/chats.dart";
import "package:kaiteki/ui/main/pages/explore.dart";
import "package:kaiteki/ui/main/pages/notifications.dart";
import "package:kaiteki/ui/main/pages/placeholder.dart";
import "package:kaiteki/ui/main/pages/timeline.dart";
import "package:kaiteki/ui/main/views/view.dart";
import "package:kaiteki/ui/shared/dialogs/keyboard_shortcuts_dialog.dart";
import "package:kaiteki/ui/shared/dialogs/options_dialog.dart";
import "package:kaiteki/ui/shared/timeline/source.dart";
import "package:kaiteki/ui/shortcuts/intents.dart";
import "package:kaiteki/utils/extensions.dart";
import "package:kaiteki_core/social.dart";

final notificationCountProvider = FutureProvider<int?>(
  (ref) {
    final account = ref.watch(currentAccountProvider);

    if (account == null) return null;
    if (account.adapter is! NotificationSupport) return null;

    final notifications = ref.watch(notificationServiceProvider(account.key));
    return notifications.valueOrNull?.where((n) => n.unread != false).length;
  },
  dependencies: [currentAccountProvider, notificationServiceProvider],
);

class MainScreen extends ConsumerStatefulWidget {
  @visibleForTesting
  final TimelineType? initialTimeline;

  const MainScreen({super.key, this.initialTimeline});

  @override
  ConsumerState<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends ConsumerState<MainScreen> {
  // Why does this exist? In order to refresh the timeline
  final _timelineKey = GlobalKey<TimelinePageState>();
  TabKind _currentTab = TabKind.home;
  MainScreenViewType _view = MainScreenViewType.stream;

  VoidCallback? get _refresh {
    switch (_currentTab) {
      case TabKind.home:
        final timeline = _timelineKey.currentState?.timeline;
        if (timeline == null) return null;
        final account = ref.watch(currentAccountProvider)!.key;
        return ref
            .read(
              timelineServiceProvider(
                account,
                StandardTimelineSource(timeline),
              ).notifier,
            )
            .refresh;

      case TabKind.notifications:
        final account = ref.watch(currentAccountProvider)!.key;
        return ref.read(notificationServiceProvider(account).notifier).refresh;

      default:
        return null;
    }
  }

  VoidCallback? get _search {
    if (ref.watch(adapterProvider) is! SearchSupport) return null;
    return () {
      context.pushNamed("search", pathParameters: ref.accountRouterParams);
    };
  }

  @override
  Widget build(BuildContext context) {
    if (ref.read(AppExperiment.navigationBarTheming.provider)) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          systemNavigationBarColor: ElevationOverlay.applySurfaceTint(
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceTint,
            3,
          ),
          systemNavigationBarDividerColor:
              Theme.of(context).colorScheme.surfaceVariant,
          systemNavigationBarIconBrightness:
              Theme.of(context).colorScheme.brightness.inverted,
        ),
      );
    }

    return FocusableActionDetector(
      autofocus: true,
      actions: {
        NewPostIntent: CallbackAction(
          onInvoke: (_) => context.pushNamed(
            "compose",
            pathParameters: ref.accountRouterParams,
          ),
        ),
        SearchIntent: CallbackAction(
          onInvoke: (_) => _search?.call(),
        ),
        RefreshIntent: CallbackAction(onInvoke: (_) => _refresh?.call()),
        GoToAppLocationIntent: CallbackAction<GoToAppLocationIntent>(
          onInvoke: _changeLocation,
        ),
        ShortcutsHelpIntent: CallbackAction(
          onInvoke: (_) => showKeyboardShortcuts(context),
        ),
      },
      child: buildView(context),
    );
  }

  dynamic _changeLocation(GoToAppLocationIntent i) {
    switch (i.location) {
      case AppLocation.home:
        _changePage(TabKind.home);
        break;
      case AppLocation.notifications:
        _changePage(TabKind.notifications);
        break;
      case AppLocation.bookmarks:
        _changePage(TabKind.bookmarks);
        break;
      case AppLocation.settings:
        context.push("/settings");
        break;
      default:
        return null;
    }
  }

  void _changePage(TabKind tab) => setState(() => _currentTab = tab);

  Widget buildView(BuildContext context) {
    return _view.create(
      getPage: (tab) => buildPage(context, tab),
      onChangeTab: _changePage,
      tab: _currentTab,
      onChangeView: ([view]) async {
        var layout = view;

        layout ??= await showDialog<MainScreenViewType>(
          context: context,
          builder: (_) => OptionsDialog(
            groupValue: _view,
            values: MainScreenViewType.values,
            textBuilder: (context, e) => Text(e.getDisplayName(context.l10n)),
            title: const Text("Switch layout"),
          ),
        );

        if (layout == null) return;

        setState(() => _view = layout!);
      },
    );
  }

  Widget buildPage(BuildContext context, TabKind tab) {
    return switch (tab) {
      TabKind.home => TimelinePage(
          initialTimeline: widget.initialTimeline,
        ),
      TabKind.notifications => const NotificationsPage(),
      TabKind.chats => const ChatsPage(),
      TabKind.bookmarks => const BookmarksPage(),
      TabKind.explore => const ExplorePage(),
      TabKind.directMessages => const PlaceholderPage(),
    };
  }
}

Future<void> showKeyboardShortcuts(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (_) => const KeyboardShortcutsDialog(),
  );
}
