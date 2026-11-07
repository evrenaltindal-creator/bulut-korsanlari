import 'package:flutter/material.dart';

import '../campaign/campaign.dart';
import '../campaign/missions.dart';
import '../game/mission_result.dart';
import 'logbook_screen.dart';
import 'paper.dart';
import 'scope.dart';
import 'sky_backdrop.dart';
import 'theme.dart';

class DebriefScreen extends StatelessWidget {
  const DebriefScreen({super.key, required this.debrief});

  final Debrief debrief;

  @override
  Widget build(BuildContext context) {
    final d = debrief;
    final r = d.result;
    final story = switch (r.outcome) {
      MissionOutcome.success => context.tr(d.mission.winKey),
      _ => context.tr(d.mission.loseKey),
    };
    final color = switch (r.outcome) {
      MissionOutcome.success => const Color(0xFF2E7D32),
      MissionOutcome.objectiveFailed => const Color(0xFF9A6A00),
      MissionOutcome.shotDown => AppColors.sail,
    };
    final lines = <String>[
      if (d.mission.kind == MissionKind.dogfight)
        context.tr('debrief.kills', {'n': r.kills}),
      if (d.mission.kind != MissionKind.dogfight)
        context.tr('debrief.targets', {
          'a': r.targetsDestroyed,
          'b': r.targetsTotal,
        }),
      if (r.shotsFired > 0)
        context.tr('debrief.accuracy', {'n': (r.accuracy * 100).round()}),
    ];
    String pct(double v) => '${(v * 100).round()}';

    return Scaffold(
      body: SkyBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr(d.mission.titleKey),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        context.tr('debrief.title.${r.outcome.name}'),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(story, style: const TextStyle(fontSize: 15)),
                      if (d.rescued) ...[
                        const SizedBox(height: 10),
                        Text(
                          context.tr('debrief.rescued'),
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                      if (d.pilotLost) ...[
                        const SizedBox(height: 10),
                        Text(
                          context.tr('debrief.lost', {'name': d.pilotName}),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.sail,
                          ),
                        ),
                        if (d.newPilotName != null)
                          Text(
                            context.tr('debrief.newPilot', {
                              'name': d.newPilotName!,
                            }),
                          ),
                      ],
                      const Divider(height: 28, color: AppColors.paperEdge),
                      Wrap(
                        spacing: 18,
                        runSpacing: 6,
                        children: [
                          for (final l in lines)
                            Text(
                              l,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (d.gunneryGain > 0.0001)
                            Text(
                              context.tr('debrief.gain', {
                                'skill': context.tr('skill.gunnery'),
                                'n': pct(d.gunneryGain),
                              }),
                            ),
                          if (d.handlingGain > 0.0001)
                            Text(
                              context.tr('debrief.gain', {
                                'skill': context.tr('skill.handling'),
                                'n': pct(d.handlingGain),
                              }),
                            ),
                        ],
                      ),
                      if (d.promotedTo != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          context.tr('debrief.promoted', {
                            'rank': context.tr(d.promotedTo!),
                          }),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2A7C7E),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context)
                              .pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (_) => const LogbookScreen(),
                                ),
                              ),
                          child: Text(context.tr('debrief.continue')),
                        ),
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
