import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart' as constants;
import '../../game/game_controller.dart';
import 'game_screen.dart';
import 'lan_multiplayer_screens.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A2119), Color(0xFF050E0A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Pokerly',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzelDecorative(
                        fontSize: isCompact ? 38 : 52,
                        fontWeight: FontWeight.w700,
                        color: constants.pokerGold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Play Texas Hold\'em your way.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    GridView(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isCompact ? 1 : 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isCompact ? 2.55 : 1.35,
                      ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _ModeCard(
                          icon: Icons.smart_toy_rounded,
                          title: 'Start Bot Game',
                          subtitle: 'Offline vs AI',
                          actionLabel: 'Start',
                          onPressed: () => _showBotSetupDialog(context, ref),
                        ),
                        _ModeCard(
                          icon: Icons.wifi_tethering_rounded,
                          title: 'Host LAN Game',
                          subtitle: 'Create local lobby',
                          actionLabel: 'Host',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const LanHostLobbyScreen()),
                            );
                          },
                        ),
                        _ModeCard(
                          icon: Icons.group_add_rounded,
                          title: 'Join LAN Game',
                          subtitle: 'Enter join code',
                          actionLabel: 'Join',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const LanJoinScreen()),
                            );
                          },
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
    );
  }

  Future<void> _showBotSetupDialog(BuildContext context, WidgetRef ref) async {
    var selectedBots = constants.maxBots;
    var selectedStartingChips = constants.startingChips;
    var selectedSmallBlind = constants.smallBlind;
    var selectedBigBlind = constants.bigBlind;
    var tournamentMode = false;
    var handsPerLevel = 5;
    final setup = await showModalBottomSheet<({int bots, int chips, int sb, int bb, bool tournament, int handsPerLevel})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 22 + MediaQuery.viewInsetsOf(context).bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  const Text('Start Bot Game', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Choose bots, chips, and blinds for this game.'),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: selectedBots,
                    decoration: const InputDecoration(labelText: 'Bot count'),
                    items: List<int>.generate(
                      constants.maxBots - constants.minBots + 1,
                      (i) => constants.minBots + i,
                    )
                        .map((count) => DropdownMenuItem(value: count, child: Text('$count bots')))
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedBots = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: selectedStartingChips,
                    decoration: const InputDecoration(labelText: 'Starting chips'),
                    items: const [
                      DropdownMenuItem(value: 1000, child: Text('1000')),
                      DropdownMenuItem(value: 1500, child: Text('1500')),
                      DropdownMenuItem(value: 2000, child: Text('2000')),
                      DropdownMenuItem(value: 3000, child: Text('3000')),
                      DropdownMenuItem(value: 5000, child: Text('5000')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedStartingChips = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: selectedSmallBlind,
                    decoration: const InputDecoration(labelText: 'Small blind'),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 25, child: Text('25')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                      DropdownMenuItem(value: 100, child: Text('100')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedSmallBlind = value;
                          if (selectedBigBlind <= selectedSmallBlind) {
                            selectedBigBlind = selectedSmallBlind * 2;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: selectedBigBlind,
                    decoration: const InputDecoration(labelText: 'Big blind'),
                    items: const [
                      DropdownMenuItem(value: 20, child: Text('20')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                      DropdownMenuItem(value: 100, child: Text('100')),
                      DropdownMenuItem(value: 200, child: Text('200')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedBigBlind = value > selectedSmallBlind ? value : (selectedSmallBlind * 2));
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    value: tournamentMode,
                    title: const Text('Tournament mode'),
                    subtitle: const Text('Blinds increase by level'),
                    onChanged: (value) => setState(() => tournamentMode = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (tournamentMode) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: handsPerLevel,
                      decoration: const InputDecoration(labelText: 'Hands per blind level'),
                      items: const [
                        DropdownMenuItem(value: 2, child: Text('2 hands')),
                        DropdownMenuItem(value: 3, child: Text('3 hands')),
                        DropdownMenuItem(value: 5, child: Text('5 hands')),
                        DropdownMenuItem(value: 8, child: Text('8 hands')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => handsPerLevel = value);
                        }
                      },
                    ),
                  ],
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop((
                        bots: selectedBots,
                        chips: selectedStartingChips,
                        sb: selectedSmallBlind,
                        bb: selectedBigBlind,
                        tournament: tournamentMode,
                        handsPerLevel: handsPerLevel,
                      )),
                      child: const Text('Start Bot Game'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (setup == null || !context.mounted) return;
    ref.read(gameControllerProvider.notifier).startGame(
          botCount: setup.bots,
          startingChips: setup.chips,
          smallBlind: setup.sb,
          bigBlind: setup.bb,
          tournamentMode: setup.tournament,
          handsPerLevel: setup.handsPerLevel,
        );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScreen()));
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: constants.pokerGold.withValues(alpha: 0.2),
                    border: Border.all(color: constants.pokerGold.withValues(alpha: 0.65)),
                  ),
                  child: Icon(icon, color: constants.pokerGold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onPressed,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
