// Small text helpers shared by several screens

// First two letters of a name in uppercase, used in the round avatars ("Juan" -> "JU", "A" -> "A")
// Returns the fallback if the name is empty (e.g. "ME" in the profile)
String initialsOf(String name, {String fallback = ''}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return fallback;
  // Takes at most 2 letters, so a 1-letter name doesn't crash like substring(0, 2) would
  return trimmed.substring(0, trimmed.length < 2 ? trimmed.length : 2).toUpperCase();
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// Formats a date like "Sep 12, 2026" (used in the review cards)
String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
