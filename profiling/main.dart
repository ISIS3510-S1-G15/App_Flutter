import 'package:flutter/material.dart';
import 'benchmarks.dart';
import 'review_cards_benchmark.dart';

void main() => runApp(const MaterialApp(home: MicroOptimizationProfiler()));

class MicroOptimizationProfiler extends StatefulWidget {
  const MicroOptimizationProfiler({super.key});

  @override
  State<MicroOptimizationProfiler> createState() => _MicroOptimizationProfilerState();
}

class _MicroOptimizationProfilerState extends State<MicroOptimizationProfiler> {
  List<BenchmarkResult> _results = const [];
  bool _running = false;

  final _cardsArea = GlobalKey<ReviewCardsBenchmarkAreaState>();
  List<BenchmarkResult> _cardsResults = const [];
  int? _scrollablesBefore, _scrollablesAfter;
  bool _cardsRunning = false;

  Future<void> _run() async {
    setState(() => _running = true);
    await Future.delayed(const Duration(milliseconds: 300));
    final results = runMicroOptimizationBenchmarks();
    for (final r in results) {
      debugPrint('${r.name}: ${r.milliseconds.toStringAsFixed(2)} ms');
    }
    setState(() {
      _results = results;
      _running = false;
    });
  }

  Future<void> _runCards() async {
    final area = _cardsArea.currentState;
    if (area == null) return;
    setState(() => _cardsRunning = true);
    final run = await runReviewCardsBenchmark(area);
    for (final r in run.results) {
      debugPrint('${r.name}: ${r.milliseconds.toStringAsFixed(2)} ms');
    }
    debugPrint('Scrollables mounted – before: ${run.scrollablesBefore}');
    debugPrint('Scrollables mounted – after: ${run.scrollablesAfter}');
    if (!mounted) return;
    setState(() {
      _cardsResults = run.results;
      _scrollablesBefore = run.scrollablesBefore;
      _scrollablesAfter = run.scrollablesAfter;
      _cardsRunning = false;
    });
  }

  // Leaves one variant mounted so its instances can be counted in DevTools Memory
  Future<void> _keepMounted(GridVariant v) async => _cardsArea.currentState?.show(v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Micro-optimization profiler')),
      // The cards area sits OUTSIDE the scrolling list: a ListView only mounts what is near the viewport,
      // and the benchmark needs its area always mounted to reach it through the GlobalKey
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Search and Recently Viewed (Sofía): 2000 restaurants, 200 history rows, 50 search rounds, 60 frames'),
                const SizedBox(height: 16),
                FilledButton(onPressed: _running ? null : _run, child: Text(_running ? 'Running…' : 'Run benchmark')),
                const SizedBox(height: 24),
                for (final r in _results)
                  ListTile(title: Text(r.name), trailing: Text('${r.milliseconds.toStringAsFixed(2)} ms')),

                const Divider(height: 32),
                Text('Review cards (Juan Felipe, #113)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                const Text('200 review cards mounted at once, 10 rounds, before vs after'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _cardsRunning ? null : _runCards,
                  child: Text(_cardsRunning ? 'Running…' : 'Run review cards benchmark'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cardsRunning ? null : () => _keepMounted(GridVariant.before),
                        child: const Text('Keep BEFORE mounted'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cardsRunning ? null : () => _keepMounted(GridVariant.after),
                        child: const Text('Keep AFTER mounted'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final r in _cardsResults)
                  ListTile(title: Text(r.name), trailing: Text('${r.milliseconds.toStringAsFixed(2)} ms')),
                if (_scrollablesBefore != null) ...[
                  ListTile(title: const Text('Scrollables mounted – before'), trailing: Text('$_scrollablesBefore')),
                  ListTile(title: const Text('Scrollables mounted – after'), trailing: Text('$_scrollablesAfter')),
                ],
              ],
            ),
          ),
          ReviewCardsBenchmarkArea(key: _cardsArea),
        ],
      ),
    );
  }
}
