import "package:flutter/material.dart";

const double _maxDialogSize = 560.0;

typedef ResponsiveDialogBuilder = Widget Function(
  BuildContext context,
  Axis? axis,
);

class ResponsiveDialog extends StatelessWidget {
  const ResponsiveDialog({
    super.key,
    required this.builder,
  });

  final ResponsiveDialogBuilder builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Axis? getAxis() {
          if (constraints.maxHeight < 300.0) return Axis.vertical;
          if (constraints.maxWidth < _maxDialogSize) return Axis.horizontal;
          return null;
        }

        final axis = getAxis();
        final child = builder.call(context, axis);

        if (axis != null) return Dialog.fullscreen(child: child);

        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _maxDialogSize,
              maxHeight: _maxDialogSize,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
