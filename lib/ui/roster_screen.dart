import 'package:flutter/material.dart';

import '../audio/music.dart';

import 'music_cue.dart';

import '../campaign/campaign.dart';
import 'paper.dart';
import 'scope.dart';
import 'sky_backdrop.dart';
import 'theme.dart';

/// Every pilot who flew this campaign, plus the squadron diary.
class RosterScreen extends StatelessWidget {
  const RosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final campaign = context.store.campaign;
    final pilots = campaign?.pilots.reversed.toList() ?? const <Pilot>[];
    final log = campaign?.log.reversed.toList() ?? const <LogEntry>[];
    return MusicCue(
      track: MusicTrack.logbook,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SkyBackdrop(
          animate: false,
          child: SafeArea(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: PaperCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('roster.title'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (pilots.isEmpty)
                                Text(context.tr('roster.empty')),
                              for (final p in pilots) _PilotRow(pilot: p),
                              const Divider(
                                height: 28,
                                color: AppColors.paperEdge,
                              ),
                              Text(
                                context.tr('log.diary'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (log.isEmpty)
                                Text(context.tr('log.diaryEmpty')),
                              for (final e in log)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    '${context.tr('log.day', {'n': e.day})} — '
                                    '${context.tr('log.entry.${e.kind.name}', {'pilot': e.pilotName, 'mission': context.tr('${e.missionId}.title')})}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                PositionedDirectional(
                  top: 4,
                  start: 4,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PilotRow extends StatelessWidget {
  const _PilotRow({required this.pilot});

  final Pilot pilot;

  @override
  Widget build(BuildContext context) {
    final lost = pilot.status == PilotStatus.lost;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            lost ? Icons.local_florist_outlined : Icons.flight,
            color: lost ? AppColors.sail : const Color(0xFF2A7C7E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pilot.name} · ${context.tr(pilot.rankKey)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: lost ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  lost
                      ? context.tr('roster.lost', {
                          'mission': context.tr('${pilot.lostOn}.title'),
                        })
                      : context.tr('roster.active'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${context.tr('stat.kills')}: ${pilot.kills}  ${context.tr('stat.missions')}: ${pilot.missions}',
          ),
        ],
      ),
    );
  }
}
