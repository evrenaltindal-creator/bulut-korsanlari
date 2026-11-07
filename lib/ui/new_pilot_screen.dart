import 'package:flutter/material.dart';

import '../audio/music.dart';

import 'music_cue.dart';

import '../campaign/campaign.dart';
import 'logbook_screen.dart';
import 'paper.dart';
import 'scope.dart';
import 'sky_backdrop.dart';
import 'theme.dart';

class NewPilotScreen extends StatefulWidget {
  const NewPilotScreen({super.key});

  @override
  State<NewPilotScreen> createState() => _NewPilotScreenState();
}

class _NewPilotScreenState extends State<NewPilotScreen> {
  final _name = TextEditingController();
  bool _starting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name.text.isEmpty) {
      _name.text = randomPilotName(StoreScope.read(context).rng);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    final store = StoreScope.read(context);
    await store.startCampaign(_name.text);
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LogbookScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MusicCue(
      track: MusicTrack.menu,
      child: Scaffold(
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
                          context.tr('intro.title'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('intro.body'),
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _name,
                                maxLength: 24,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: InputDecoration(
                                  labelText: context.tr('newPilot.name'),
                                  labelStyle: const TextStyle(
                                    color: AppColors.inkSoft,
                                  ),
                                  counterStyle: const TextStyle(
                                    color: AppColors.inkSoft,
                                  ),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _start(),
                              ),
                            ),
                            IconButton(
                              tooltip: context.tr('newPilot.random'),
                              color: AppColors.ink,
                              icon: const Icon(Icons.casino_outlined),
                              onPressed: () => setState(
                                () => _name.text = randomPilotName(
                                  StoreScope.read(context).rng,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton(
                            onPressed: _starting ? null : _start,
                            child: Text(context.tr('newPilot.start')),
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
      ),
    );
  }
}
