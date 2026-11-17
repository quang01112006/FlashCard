class CardDeck {
  const CardDeck({required this.id, required this.name, this.description = ''});
  static const flutterId = 'flutter-default';
  static const legacyId = 'legacy-added';
  final String id;
  final String name;
  final String description;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
  };
  factory CardDeck.fromJson(Map<String, dynamic> value) {
    if (value['id'] is! String ||
        (value['id'] as String).trim().isEmpty ||
        value['name'] is! String ||
        (value['name'] as String).trim().isEmpty ||
        (value['description'] != null && value['description'] is! String)) {
      throw const FormatException('Invalid deck');
    }
    return CardDeck(
      id: value['id'],
      name: value['name'],
      description: value['description'] ?? '',
    );
  }
}
