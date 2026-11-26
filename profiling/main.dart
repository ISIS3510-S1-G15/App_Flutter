import 'package:flutter/material.dart';
import 'benchmarks.dart';

void main() => runApp(const MaterialApp(home: MicroOptimizationProfiler()));

class MicroOptimizationProfiler extends StatefulWidget {
  const MicroOptimizationProfiler({super.key});

  @override
  State<MicroOptimizationProfiler> createState() => _MicroOptimizationProfilerState();
}

class _MicroOptimizationProfilerState extends State<MicroOptimizationProfiler> {
  List<BenchmarkResult> _results = const [];
  bool _running = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Micro-optimization profiler')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('2000 restaurants, 200 history rows, 50 search rounds, 60 frames'),
          const SizedBox(height: 16),
          FilledButton(onPressed: _running ? null : _run, child: Text(_running ? 'Running…' : 'Run benchmark')),
          const SizedBox(height: 24),
          for (final r in _results)
            ListTile(title: Text(r.name), trailing: Text('${r.milliseconds.toStringAsFixed(2)} ms')),
        ],
      ),
    );
  }
}
