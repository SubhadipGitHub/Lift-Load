import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/tester_log.dart';
import '../game_controller.dart';
import '../platform/save_file.dart';
import '../theme.dart';

/// Gate A tester build only (PRD v1.4): the in-game questions and the
/// "Send results" sheet.

/// "Was that crash fair?" on the crash sheet. Optional: one tap, or ignore it.
class CrashFairRow extends StatelessWidget {
  const CrashFairRow({super.key, required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: LL.steel.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text('Tester question: was that crash fair?',
                textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: LL.ink)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _Choice(label: 'Fair', onPressed: () => c.rateCrash(fair: true))),
                const SizedBox(width: 10),
                Expanded(child: _Choice(label: 'Unfair', onPressed: () => c.rateCrash(fair: false))),
              ],
            ),
          ],
        ),
      );
}

/// "Did the unknown people in the queue feel fair?" on a win sheet (Gate A with powers on). Optional: Fair,
/// Unfair or Skip, once.
class UnknownFairCard extends StatelessWidget {
  const UnknownFairCard({super.key, required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        decoration: BoxDecoration(color: LL.steel.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            const Text('Tester question: did the unknown people in the queue feel fair?',
                textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: LL.ink)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _Choice(label: 'Fair', onPressed: () => c.answerUnknownFair(true))),
                const SizedBox(width: 10),
                Expanded(child: _Choice(label: 'Unfair', onPressed: () => c.answerUnknownFair(false))),
              ],
            ),
            TextButton(
              onPressed: () => c.answerUnknownFair(null),
              child: const Text('Skip', style: TextStyle(color: LL.inkSoft, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: LL.ink,
            side: const BorderSide(color: LL.ink, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
}

/// The unprompted heavy-types question, once, on a win from level 15 on.
/// No choices are shown, so the answer is the tester's own.
class HeavyTypesCard extends StatefulWidget {
  const HeavyTypesCard({super.key, required this.c});

  final GameController c;

  @override
  State<HeavyTypesCard> createState() => _HeavyTypesCardState();
}

class _HeavyTypesCardState extends State<HeavyTypesCard> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        decoration: BoxDecoration(color: LL.steel.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Tester question: which residents do you think are the heaviest?',
                style: TextStyle(fontWeight: FontWeight.w800, color: LL.ink)),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              minLines: 1,
              maxLines: 3,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'In your own words',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            // Wraps instead of overflowing with large text.
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => widget.c.answerHeavyTypes(null),
                  child: const Text('Skip', style: TextStyle(color: LL.inkSoft, fontWeight: FontWeight.w700)),
                ),
                FilledButton(
                  onPressed: () => widget.c.answerHeavyTypes(_text.text),
                  style: FilledButton.styleFrom(backgroundColor: LL.ink, foregroundColor: LL.cream),
                  child: const Text('Save answer', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      );
}

/// "Tester build" chip with the tester's code, for Home.
class TesterChip extends StatelessWidget {
  const TesterChip({super.key, required this.log});

  final TesterLog log;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: LL.lilac.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('Tester build · ${log.code}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LL.lilac)),
      );
}

/// Lets a tester return their results: a file download where the platform
/// can, and a code to paste into a message everywhere.
Future<void> showResultsSheet(BuildContext context, GameController c) {
  final log = c.testerLog;
  if (log == null) return Future.value();
  final messenger = ScaffoldMessenger.maybeOf(context);
  void say(String text) => messenger?.showSnackBar(SnackBar(content: Text(text)));
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: LL.cream,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Send your results',
                  textAlign: TextAlign.center, style: LL.display.copyWith(fontSize: 26, color: LL.ink)),
              const SizedBox(height: 6),
              Text(
                'Thank you for testing. This sends which levels you played, how they went and your answers, '
                'under the code ${log.code}. Nothing else.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.4, color: LL.inkSoft),
              ),
              const SizedBox(height: 14),
              if (canSaveFile) ...[
                FilledButton.icon(
                  onPressed: () async {
                    final ok = await saveTextFile('lift-load-${log.code}.json', log.exportJson());
                    say(ok ? 'Saved. Send the file to the person who invited you.' : 'Could not save. Copy instead.');
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download results file', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                    backgroundColor: LL.ink,
                    foregroundColor: LL.cream,
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: log.exportCode()));
                  say('Copied. Paste it into a message to the person who invited you.');
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy results code', style: TextStyle(fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: LL.ink,
                  side: const BorderSide(color: LL.ink, width: 2),
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
