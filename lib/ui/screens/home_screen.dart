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
                      'Play Texas Hold\'em your way: solo with bots or local LAN co-op.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    GridView(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isCompact ? 1 : 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isCompact ? 3.2 : 1.55,
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
                    const SizedBox(height: 10),
                    Text(
                      'Blinds ${constants.smallBlind}/${constants.bigBlind} • ${constants.startingChips} chips each',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
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
    final count = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Start Bot Game', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Choose how many bots to add at the table.'),
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
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(selectedBots),
                    child: const Text('Start Bot Game'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (count == null || !context.mounted) return;
    ref.read(gameControllerProvider.notifier).startGame(botCount: count);
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
