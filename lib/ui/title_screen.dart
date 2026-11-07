import 'package:flutter/material.dart';

import 'logbook_screen.dart';
import 'new_pilot_screen.dart';
import 'roster_screen.dart';
import 'scope.dart';
import 'sky_backdrop.dart';
import 'theme.dart';

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Scaffold(
      body: SkyBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('app.title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: Color(0xAA000000),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('app.subtitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(color: Color(0xCC000000), blurRadius: 6),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (store.hasCampaign) ...[
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LogbookScreen(),
                        ),
                      ),
                      child: Text(context.tr('menu.continue')),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _MenuButton(
                    label: context.tr('menu.new'),
                    filled: !store.hasCampaign,
                    onPressed: () => _newCampaign(context),
                  ),
                  const SizedBox(height: 10),
                  if (store.hasCampaign) ...[
                    _MenuButton(
                      label: context.tr('menu.roster'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RosterScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () => showHowTo(context),
                        icon: const Icon(
                          Icons.help_outline,
                          color: Colors.white70,
                        ),
                        label: Text(
                          context.tr('menu.howto'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _settings(context),
                        icon: const Icon(Icons.tune, color: Colors.white70),
                        label: Text(
                          context.tr('menu.settings'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _newCampaign(BuildContext context) async {
    final store = StoreScope.read(context);
    if (store.hasCampaign) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(ctx.tr('menu.newConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('common.yes')),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!context.mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const NewPilotScreen()));
  }

  void _settings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final store = ctx.store;
        return AlertDialog(
          title: Text(ctx.tr('settings.title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ctx.tr('settings.language'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'tr', label: Text('Türkçe')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {store.lang},
                onSelectionChanged: (s) => store.setLang(s.first),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: store.invertY,
                onChanged: store.setInvertY,
                title: Text(ctx.tr('settings.invert')),
                subtitle: Text(ctx.tr('settings.invertHint')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.tr('common.close')),
            ),
          ],
        );
      },
    );
  }
}

void showHowTo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('howto.title')),
      content: SingleChildScrollView(child: Text(ctx.tr('howto.body'))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.tr('common.close')),
        ),
      ],
    ),
  );
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) => filled
      ? FilledButton(onPressed: onPressed, child: Text(label))
      : OutlinedButton(onPressed: onPressed, child: Text(label));
}
