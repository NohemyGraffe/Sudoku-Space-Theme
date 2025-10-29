class BuildInfo {
  static final DateTime startedAt = DateTime.now();

  static String two(int n) => n.toString().padLeft(2, '0');

  static String get hhmmss {
    final t = startedAt;
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  static String get ymdHms {
    final t = startedAt;
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
