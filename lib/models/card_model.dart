class CardModel {
  const CardModel({
    this.id,
    required this.word,
    this.partOfSpeech,
    this.phonetic,
    required this.meaning,
    this.imagePath,
    required this.createdAt,
    this.lastPushedAt,
  });

  final int? id;
  final String word;
  final String? partOfSpeech;
  final String? phonetic;
  final String meaning;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime? lastPushedAt;

  factory CardModel.fromMap(Map<String, Object?> map) {
    return CardModel(
      id: map['id'] as int?,
      word: map['word'] as String,
      partOfSpeech: map['partOfSpeech'] as String?,
      phonetic: map['phonetic'] as String?,
      meaning: map['meaning'] as String,
      imagePath: map['imagePath'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastPushedAt: map['lastPushedAt'] == null
          ? null
          : DateTime.parse(map['lastPushedAt'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'word': word.trim(),
      'partOfSpeech': _normalizeNullableString(partOfSpeech),
      'phonetic': _normalizeNullableString(phonetic),
      'meaning': meaning.trim(),
      'imagePath': _normalizeNullableString(imagePath),
      'createdAt': createdAt.toIso8601String(),
      'lastPushedAt': lastPushedAt?.toIso8601String(),
    };
  }

  CardModel copyWith({
    int? id,
    String? word,
    String? partOfSpeech,
    bool clearPartOfSpeech = false,
    String? phonetic,
    bool clearPhonetic = false,
    String? meaning,
    String? imagePath,
    bool clearImagePath = false,
    DateTime? createdAt,
    DateTime? lastPushedAt,
    bool clearLastPushedAt = false,
  }) {
    return CardModel(
      id: id ?? this.id,
      word: word ?? this.word,
      partOfSpeech: clearPartOfSpeech ? null : (partOfSpeech ?? this.partOfSpeech),
      phonetic: clearPhonetic ? null : (phonetic ?? this.phonetic),
      meaning: meaning ?? this.meaning,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      createdAt: createdAt ?? this.createdAt,
      lastPushedAt: clearLastPushedAt
          ? null
          : (lastPushedAt ?? this.lastPushedAt),
    );
  }

  bool get hasPhonetic => phonetic != null && phonetic!.trim().isNotEmpty;
  bool get hasPartOfSpeech =>
      partOfSpeech != null && partOfSpeech!.trim().isNotEmpty;

  bool get hasImage => imagePath != null && imagePath!.trim().isNotEmpty;

  String get notificationTitle {
    final String? abbreviation = _partOfSpeechAbbreviation(partOfSpeech);
    if (abbreviation == null) {
      return word;
    }

    return '$word ($abbreviation)';
  }

  String get notificationBody => '$word: $meaning';

  String? _partOfSpeechAbbreviation(String? value) {
    final String normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return null;
    }

    const Map<String, String> abbreviations = <String, String>{
      'noun': 'n',
      'verb': 'v',
      'adjective': 'adj',
      'adverb': 'adv',
      'pronoun': 'pron',
      'preposition': 'prep',
      'conjunction': 'conj',
      'interjection': 'int',
      'phrasal verb': 'phr v',
      'noun phrase': 'n phr',
      'verb phrase': 'v phr',
      'idiom': 'idm',
      'other': 'other',
    };

    return abbreviations[normalized] ?? value?.trim();
  }

  String? _normalizeNullableString(String? value) {
    if (value == null) {
      return null;
    }

    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  String toString() {
    return 'CardModel(id: $id, word: $word, meaning: $meaning)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CardModel &&
        other.id == id &&
        other.word == word &&
        other.partOfSpeech == partOfSpeech &&
        other.phonetic == phonetic &&
        other.meaning == meaning &&
        other.imagePath == imagePath &&
        other.createdAt == createdAt &&
        other.lastPushedAt == lastPushedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        word,
        partOfSpeech,
        phonetic,
        meaning,
        imagePath,
        createdAt,
        lastPushedAt,
      );
}
