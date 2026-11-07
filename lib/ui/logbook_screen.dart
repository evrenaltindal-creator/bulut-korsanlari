import 'package:flutter/material.dart';

import '../audio/music.dart';
import '../campaign/campaign.dart';
import '../campaign/missions.dart';
import 'art.dart';
import 'epilogue_screen.dart';
import 'mission_screen.dart';
import 'music_cue.dart';
import 'paper.dart';
import 'scope.dart';
import 'sky_backdrop.dart';
import 'theme.dart';

/// The briefing spread: the mission's painting and the pilot on the left
/// page, the diary entry with the speaker's portrait on the right.
class LogbookScreen extends StatelessWidget {
  const LogbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final campaign = context.store.campaign;
    if (campaign == null) return const SizedBox.shrink();
    if (campaign.finished) return const EpilogueScreen();
    final mission = campaign.currentMission;
    final pilot = campaign.activePilot;
    final retrying =
        campaign.log.isNotEmpty && campaign.log.last.missionId == mission.id;

    final pilotCard = PaperCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: PilotSummary(pilot: pilot, compact: true),
    );
    final briefCard = PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${context.tr('log.day', {'n': campaign.day})} · '
            '${context.tr('log.chapter', {'n': mission.chapter, 'title': context.tr('chapter.${mission.chapter}')})}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(mission.titleKey),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(_kindIcon(mission.kind), size: 16, color: AppColors.sail),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${context.tr('log.kind.${mission.kind.name}')} · '
                  '${context.tr('log.mission', {'n': campaign.missionIndex + 1, 'total': campaignMissions.length})}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.sail,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  context.tr(mission.briefKey),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(width: 12),
              PortraitBadge(character: mission.briefBy),
            ],
          ),
          if (retrying) ...[
            const SizedBox(height: 10),
            Text(
              context.tr('log.retry'),
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.inkSoft,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MissionScreen(mission: mission),
                ),
              ),
              icon: const Icon(Icons.flight_takeoff),
              label: Text(context.tr('log.fly')),
            ),
          ),
        ],
      ),
    );
    final painting = Illustration(asset: mission.image);

    return MusicCue(
      track: MusicTrack.logbook,
      child: Scaffold(
        body: SkyBackdrop(
          child: SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth > 700;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: (c.maxWidth * 0.36).clamp(
                                        260,
                                        440,
                                      ),
                                      child: Column(
                                        children: [
                                          painting,
                                          const SizedBox(height: 16),
                                          pilotCard,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(child: briefCard),
                                  ],
                                )
                              : Column(
                                  children: [
                                    painting,
                                    const SizedBox(height: 16),
                                    briefCard,
                                    const SizedBox(height: 12),
                                    pilotCard,
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
                PositionedDirectional(
                  top: 4,
                  start: 4,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _kindIcon(MissionKind k) => switch (k) {
    MissionKind.dogfight => Icons.my_location,
    MissionKind.raid => Icons.landscape,
    MissionKind.bombing => Icons.south,
  };
}

class PilotSummary extends StatelessWidget {
  const PilotSummary({super.key, required this.pilot, this.compact = false});

  final Pilot pilot;

  /// One line for name and rank, tighter spacing.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr('log.pilot').toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            color: AppColors.inkSoft,
          ),
        ),
        if (compact)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: pilot.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: '  ${context.tr(pilot.rankKey)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A7C7E),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Text(
            pilot.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            context.tr(pilot.rankKey),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF2A7C7E),
            ),
          ),
        ],
        SizedBox(height: compact ? 4 : 10),
        InkMeter(label: context.tr('skill.gunnery'), value: pilot.gunnery),
        InkMeter(label: context.tr('skill.handling'), value: pilot.handling),
        SizedBox(height: compact ? 2 : 8),
        Text(
          '${context.tr('stat.kills')}: ${pilot.kills}   ${context.tr('stat.missions')}: ${pilot.missions}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
