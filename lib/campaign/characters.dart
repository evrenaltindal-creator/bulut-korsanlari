/// The people of the story who have a portrait.
enum Character {
  selvi,
  kerem,
  surmeli,
  kuzgun;

  String get asset => 'assets/images/portraits/$name.jpg';

  /// Strings key for the name shown under the portrait.
  String get nameKey => 'char.$name';

  /// Pirates appear in a briefing as the target, not the speaker.
  bool get isPirate => this == surmeli || this == kuzgun;
}

/// Story illustration paths.
abstract final class Art {
  static String chapter(int n) => 'assets/images/chapters/chapter$n.jpg';
  static String mission(String id) => 'assets/images/missions/$id.jpg';
}
