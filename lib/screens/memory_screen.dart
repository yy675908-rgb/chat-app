import 'package:flutter/material.dart';

class MemoryScreen extends StatelessWidget {
  const MemoryScreen({required this.memories, super.key});

  final List<String> memories;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEBE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDEBE6),
        surfaceTintColor: Colors.transparent,
        title: const Text('共同记忆'),
      ),
      body: memories.isEmpty
          ? const Center(
              child: Text(
                '还没有被留下的记忆。\n以后重要的事会慢慢长在这里。',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: memories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => Card(
                elevation: 0,
                color: const Color(0xFFFAF9F5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(memories[index]),
                ),
              ),
            ),
    );
  }
}
