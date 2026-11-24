List<Map<String, dynamic>> groupByDay(List<Map<String, dynamic>> items, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final sorted = [...items]
    ..sort((a, b) => (b['last_viewed_at'] as String).compareTo(a['last_viewed_at'] as String));
  final sections = <String, List<Map<String, dynamic>>>{'Today': [], 'Yesterday': [], 'Earlier': []};
  for (final item in sorted) {
    final viewed = DateTime.parse(item['last_viewed_at'] as String).toLocal();
    final day = DateTime(viewed.year, viewed.month, viewed.day);
    final title = !day.isBefore(today) ? 'Today' : (day == yesterday ? 'Yesterday' : 'Earlier');
    sections[title]!.add(item);
  }
  return [
    for (final entry in sections.entries)
      if (entry.value.isNotEmpty) {'title': entry.key, 'items': entry.value},
  ];
}
