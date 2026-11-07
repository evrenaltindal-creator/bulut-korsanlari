import 'package:flutter/material.dart';

import 'new_pilot_screen.dart';
import 'paper.dart';
import 'scope.dart';
import 'sky_backdrop.dart';

class EpilogueScreen extends StatelessWidget {
  const EpilogueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.store.campaign!;
    return Scaffold(
      body: SkyBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: PaperCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('epilogue.title'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('epilogue.body'),
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('epilogue.stats', {
                          'days': c.log.length,
                          'kills': c.totalKills,
                          'pilots': c.pilots.length,
                        }),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      for (final p in c.pilots)
                        Text('• ${p.name} — ${context.tr(p.rankKey)}'),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                            ),
                            onPressed: () =>
                                Navigator.of(context)
                                    .popUntil((r) => r.isFirst),
                            child: Text(context.tr('common.close')),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(context)
                                .pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const NewPilotScreen(),
                                  ),
                                ),
                            child: Text(context.tr('menu.new')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
