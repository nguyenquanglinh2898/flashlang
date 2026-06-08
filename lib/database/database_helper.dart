import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/card_model.dart';
import '../models/group_model.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _databaseName = 'flash_lang.db';
  static const int _databaseVersion = 1;

  static const String cardGroupsTable = 'card_groups';
  static const String cardsTable = 'cards';
  static const String cardGroupMappingTable = 'card_group_mapping';
  static const String notificationSettingsTable = 'notification_settings';

  static const List<String> defaultPushTimes = <String>[
    '07:00',
    '09:00',
    '11:00',
    '13:00',
    '15:00',
    '17:00',
    '19:00',
    '21:00',
  ];

  Database? _database;
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String databasesPath = await getDatabasesPath();
    final String path = p.join(databasesPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $cardGroupsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $cardsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        phonetic TEXT,
        meaning TEXT NOT NULL,
        imagePath TEXT,
        createdAt TEXT NOT NULL,
        lastPushedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $cardGroupMappingTable (
        cardId INTEGER NOT NULL,
        groupId INTEGER NOT NULL,
        PRIMARY KEY (cardId, groupId),
        FOREIGN KEY (cardId) REFERENCES $cardsTable(id) ON DELETE CASCADE,
        FOREIGN KEY (groupId) REFERENCES $cardGroupsTable(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $notificationSettingsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pushTimes TEXT NOT NULL,
        pushCount INTEGER NOT NULL DEFAULT 8
      )
    ''');

    await db.insert(
      notificationSettingsTable,
      <String, Object?>{
        'pushTimes': jsonEncode(defaultPushTimes),
        'pushCount': defaultPushTimes.length,
      },
    );
  }

  Future<void> close() async {
    final Database db = await database;
    await db.close();
    _database = null;
  }

  Future<int> insertGroup(GroupModel group) async {
    final Database db = await database;
    return db.insert(cardGroupsTable, group.toMap());
  }

  Future<List<GroupModel>> getAllGroups() async {
    final Database db = await database;
    final List<Map<String, Object?>> maps = await db.query(
      cardGroupsTable,
      orderBy: 'createdAt DESC',
    );

    return maps.map(GroupModel.fromMap).toList();
  }

  Future<List<GroupWithCount>> getGroupsWithCardCount() async {
    final Database db = await database;
    final List<Map<String, Object?>> maps = await db.rawQuery('''
      SELECT
        g.id,
        g.name,
        g.createdAt,
        COUNT(m.cardId) AS cardCount
      FROM $cardGroupsTable g
      LEFT JOIN $cardGroupMappingTable m ON m.groupId = g.id
      GROUP BY g.id
      ORDER BY g.createdAt DESC
    ''');

    return maps.map(GroupWithCount.fromMap).toList();
  }

  Future<GroupModel?> getGroupById(int groupId) async {
    final Database db = await database;
    final List<Map<String, Object?>> maps = await db.query(
      cardGroupsTable,
      where: 'id = ?',
      whereArgs: <Object?>[groupId],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return GroupModel.fromMap(maps.first);
  }

  Future<GroupModel> createGroupIfNotExists(String name) async {
    final String trimmedName = name.trim();
    final Database db = await database;

    final List<Map<String, Object?>> existing = await db.query(
      cardGroupsTable,
      where: 'LOWER(name) = ?',
      whereArgs: <Object?>[trimmedName.toLowerCase()],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return GroupModel.fromMap(existing.first);
    }

    final GroupModel group = GroupModel(
      name: trimmedName,
      createdAt: DateTime.now(),
    );
    final int id = await insertGroup(group);

    return group.copyWith(id: id);
  }

  Future<int> deleteGroup(int groupId) async {
    final Database db = await database;
    return db.delete(
      cardGroupsTable,
      where: 'id = ?',
      whereArgs: <Object?>[groupId],
    );
  }

  Future<int> insertCard(CardModel card, List<int> groupIds) async {
    final Database db = await database;

    return db.transaction<int>((Transaction txn) async {
      final int cardId = await txn.insert(cardsTable, card.toMap());
      await _replaceCardGroups(txn, cardId, groupIds);
      return cardId;
    });
  }

  Future<int> updateCard(CardModel card, List<int> groupIds) async {
    if (card.id == null) {
      throw ArgumentError('Card id is required for update.');
    }

    final Database db = await database;

    return db.transaction<int>((Transaction txn) async {
      final int updatedRows = await txn.update(
        cardsTable,
        card.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[card.id],
      );
      await _replaceCardGroups(txn, card.id!, groupIds);
      return updatedRows;
    });
  }

  Future<void> _replaceCardGroups(
    Transaction txn,
    int cardId,
    List<int> groupIds,
  ) async {
    await txn.delete(
      cardGroupMappingTable,
      where: 'cardId = ?',
      whereArgs: <Object?>[cardId],
    );

    for (final int groupId in groupIds.toSet()) {
      await txn.insert(
        cardGroupMappingTable,
        <String, Object?>{
          'cardId': cardId,
          'groupId': groupId,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<CardModel?> getCardById(int cardId) async {
    final Database db = await database;
    final List<Map<String, Object?>> maps = await db.query(
      cardsTable,
      where: 'id = ?',
      whereArgs: <Object?>[cardId],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return CardModel.fromMap(maps.first);
  }

  Future<List<CardModel>> getAllCards() async {
    final Database db = await database;
    final List<Map<String, Object?>> maps = await db.query(
      cardsTable,
      orderBy: 'createdAt DESC',
    );

    return maps.map(CardModel.fromMap).toList();
  }

  Future<List<CardModel>> getCardsByGroupId(int groupId) async {
    final Database db = await database;
    final List<Map<String, Object?>> maps = await db.rawQuery('''
      SELECT c.*
      FROM $cardsTable c
      INNER JOIN $cardGroupMappingTable m ON m.cardId = c.id
      WHERE m.groupId = ?
      ORDER BY c.createdAt DESC
    ''', <Object?>[groupId]);

    return maps.map(CardModel.fromMap).toList();
  }

  Future<List<GroupModel>> getGroupsForCard(int cardId) async {
    final Database db = await database;
    final List<Map<String, Object?>> maps = await db.rawQuery('''
      SELECT g.*
      FROM $cardGroupsTable g
      INNER JOIN $cardGroupMappingTable m ON m.groupId = g.id
      WHERE m.cardId = ?
      ORDER BY g.name COLLATE NOCASE ASC
    ''', <Object?>[cardId]);

    return maps.map(GroupModel.fromMap).toList();
  }

  Future<List<int>> getGroupIdsForCard(int cardId) async {
    final Database db = await database;
    final List<Map<String, Object?>> maps = await db.query(
      cardGroupMappingTable,
      columns: <String>['groupId'],
      where: 'cardId = ?',
      whereArgs: <Object?>[cardId],
    );

    return maps
        .map((Map<String, Object?> map) => map['groupId'] as int)
        .toList();
  }

  Future<int> deleteCard(int cardId) async {
    final Database db = await database;
    return db.delete(
      cardsTable,
      where: 'id = ?',
      whereArgs: <Object?>[cardId],
    );
  }

  Future<void> upsertNotificationSettings(List<String> pushTimes) async {
    final Database db = await database;
    final List<String> normalizedTimes = List<String>.from(pushTimes)
      ..sort((String a, String b) => a.compareTo(b));

    await db.update(
      notificationSettingsTable,
      <String, Object?>{
        'pushTimes': jsonEncode(normalizedTimes),
        'pushCount': normalizedTimes.length,
      },
      where: 'id = ?',
      whereArgs: const <Object?>[1],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<NotificationSettingsModel> getNotificationSettings() async {
    final Database db = await database;
    final List<Map<String, Object?>> maps = await db.query(
      notificationSettingsTable,
      limit: 1,
    );

    if (maps.isEmpty) {
      await db.insert(
        notificationSettingsTable,
        <String, Object?>{
          'id': 1,
          'pushTimes': jsonEncode(defaultPushTimes),
          'pushCount': defaultPushTimes.length,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return NotificationSettingsModel(
        id: 1,
        pushTimes: defaultPushTimes,
        pushCount: defaultPushTimes.length,
      );
    }

    return NotificationSettingsModel.fromMap(maps.first);
  }

  Future<CardModel?> getNextCardForNotification() async {
    final Database db = await database;
    final DateTime twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));

    final List<Map<String, Object?>> eligibleMaps = await db.query(
      cardsTable,
      where: 'lastPushedAt IS NULL OR lastPushedAt < ?',
      whereArgs: <Object?>[twoDaysAgo.toIso8601String()],
      orderBy:
          'CASE WHEN lastPushedAt IS NULL THEN 0 ELSE 1 END, lastPushedAt ASC, createdAt ASC, id ASC',
      limit: 1,
    );

    if (eligibleMaps.isNotEmpty) {
      return CardModel.fromMap(eligibleMaps.first);
    }

    final List<Map<String, Object?>> fallbackMaps = await db.query(
      cardsTable,
      orderBy:
          'CASE WHEN lastPushedAt IS NULL THEN 0 ELSE 1 END, lastPushedAt ASC, createdAt ASC, id ASC',
      limit: 1,
    );

    if (fallbackMaps.isEmpty) {
      return null;
    }

    return CardModel.fromMap(fallbackMaps.first);
  }

  Future<void> updateCardLastPushedAt(int cardId, DateTime pushedAt) async {
    final Database db = await database;
    await db.update(
      cardsTable,
      <String, Object?>{
        'lastPushedAt': pushedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[cardId],
    );
  }

  Future<ImportedCardInsertResult> insertImportedCard({
    required String word,
    String? phonetic,
    required String meaning,
    String? imagePath,
    required List<String> groupNames,
  }) async {
    final Database db = await database;

    return db.transaction<ImportedCardInsertResult>((Transaction txn) async {
      final String normalizedWord = word.trim();
      final String normalizedMeaning = meaning.trim();
      final String? normalizedPhonetic = _normalizeNullableString(phonetic);
      final String? normalizedImagePath = _normalizeNullableString(imagePath);
      final List<String> normalizedGroupNames = groupNames
          .map((String name) => name.trim())
          .where((String name) => name.isNotEmpty)
          .toSet()
          .toList();

      if (normalizedWord.isEmpty ||
          normalizedMeaning.isEmpty ||
          normalizedGroupNames.isEmpty) {
        return const ImportedCardInsertResult.invalid();
      }

      final List<int> groupIds = <int>[];
      for (final String name in normalizedGroupNames) {
        final List<Map<String, Object?>> existingGroups = await txn.query(
          cardGroupsTable,
          where: 'LOWER(name) = ?',
          whereArgs: <Object?>[name.toLowerCase()],
          limit: 1,
        );

        if (existingGroups.isNotEmpty) {
          groupIds.add(existingGroups.first['id'] as int);
          continue;
        }

        final int groupId = await txn.insert(
          cardGroupsTable,
          <String, Object?>{
            'name': name,
            'createdAt': DateTime.now().toIso8601String(),
          },
        );
        groupIds.add(groupId);
      }

      final List<Map<String, Object?>> existingCards = await txn.query(
        cardsTable,
        where: 'LOWER(word) = ? AND LOWER(meaning) = ?',
        whereArgs: <Object?>[
          normalizedWord.toLowerCase(),
          normalizedMeaning.toLowerCase(),
        ],
        orderBy: 'createdAt ASC, id ASC',
        limit: 1,
      );

      int cardId;
      bool insertedCard = false;
      if (existingCards.isNotEmpty) {
        cardId = existingCards.first['id'] as int;
      } else {
        final CardModel card = CardModel(
          word: normalizedWord,
          phonetic: normalizedPhonetic,
          meaning: normalizedMeaning,
          imagePath: normalizedImagePath,
          createdAt: DateTime.now(),
        );

        cardId = await txn.insert(cardsTable, card.toMap());
        insertedCard = true;
      }

      int insertedGroupMappings = 0;
      for (final int groupId in groupIds) {
        final int mappingId = await txn.insert(
          cardGroupMappingTable,
          <String, Object?>{
            'cardId': cardId,
            'groupId': groupId,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        if (mappingId > 0) {
          insertedGroupMappings++;
        }
      }

      if (!insertedCard && insertedGroupMappings == 0) {
        return const ImportedCardInsertResult.duplicate();
      }

      return ImportedCardInsertResult.inserted(
        insertedCard: insertedCard,
        insertedGroupMappings: insertedGroupMappings,
      );
    });
  }

  Future<List<ExportableCardRow>> getCardsForExportByGroup(int groupId) async {
    final Database db = await database;
    final List<Map<String, Object?>> maps = await db.rawQuery('''
      SELECT
        c.id,
        c.word,
        c.phonetic,
        c.meaning,
        c.imagePath,
        GROUP_CONCAT(g.name, ';') AS groups
      FROM $cardsTable c
      INNER JOIN $cardGroupMappingTable baseMap ON baseMap.cardId = c.id
      LEFT JOIN $cardGroupMappingTable allMap ON allMap.cardId = c.id
      LEFT JOIN $cardGroupsTable g ON g.id = allMap.groupId
      WHERE baseMap.groupId = ?
      GROUP BY c.id
      ORDER BY c.createdAt DESC
    ''', <Object?>[groupId]);

    return maps.map(ExportableCardRow.fromMap).toList();
  }

  Future<List<ExportableCardRow>> getAllCardsForExport() async {
    final Database db = await database;
    final List<Map<String, Object?>> maps = await db.rawQuery('''
      SELECT
        c.id,
        c.word,
        c.phonetic,
        c.meaning,
        c.imagePath,
        GROUP_CONCAT(g.name, ';') AS groups
      FROM $cardsTable c
      LEFT JOIN $cardGroupMappingTable allMap ON allMap.cardId = c.id
      LEFT JOIN $cardGroupsTable g ON g.id = allMap.groupId
      GROUP BY c.id
      ORDER BY c.createdAt DESC
    ''');

    return maps.map(ExportableCardRow.fromMap).toList();
  }

  String? _normalizeNullableString(String? value) {
    if (value == null) {
      return null;
    }

    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class NotificationSettingsModel {
  const NotificationSettingsModel({
    required this.id,
    required this.pushTimes,
    required this.pushCount,
  });

  final int id;
  final List<String> pushTimes;
  final int pushCount;

  factory NotificationSettingsModel.fromMap(Map<String, Object?> map) {
    return NotificationSettingsModel(
      id: map['id'] as int,
      pushTimes: List<String>.from(jsonDecode(map['pushTimes'] as String) as List<dynamic>),
      pushCount: map['pushCount'] as int,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'pushTimes': jsonEncode(pushTimes),
      'pushCount': pushCount,
    };
  }
}

class GroupWithCount extends GroupModel {
  const GroupWithCount({
    required super.id,
    required super.name,
    required super.createdAt,
    required this.cardCount,
  });

  final int cardCount;

  factory GroupWithCount.fromMap(Map<String, Object?> map) {
    return GroupWithCount(
      id: map['id'] as int,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      cardCount: map['cardCount'] as int? ?? 0,
    );
  }
}

class ExportableCardRow {
  const ExportableCardRow({
    required this.id,
    required this.word,
    this.phonetic,
    required this.meaning,
    this.imagePath,
    required this.groups,
  });

  final int id;
  final String word;
  final String? phonetic;
  final String meaning;
  final String? imagePath;
  final String groups;

  factory ExportableCardRow.fromMap(Map<String, Object?> map) {
    return ExportableCardRow(
      id: map['id'] as int,
      word: map['word'] as String,
      phonetic: map['phonetic'] as String?,
      meaning: map['meaning'] as String,
      imagePath: map['imagePath'] as String?,
      groups: (map['groups'] as String?) ?? '',
    );
  }

  List<String> toCsvRow() {
    return <String>[
      word,
      phonetic ?? '',
      meaning,
      imagePath ?? '',
      groups,
    ];
  }
}

class ImportedCardInsertResult {
  const ImportedCardInsertResult.inserted({
    required this.insertedCard,
    required this.insertedGroupMappings,
  }) : status = ImportedCardInsertStatus.inserted;

  const ImportedCardInsertResult.duplicate()
      : status = ImportedCardInsertStatus.duplicate,
        insertedCard = false,
        insertedGroupMappings = 0;

  const ImportedCardInsertResult.invalid()
      : status = ImportedCardInsertStatus.invalid,
        insertedCard = false,
        insertedGroupMappings = 0;

  final ImportedCardInsertStatus status;
  final bool insertedCard;
  final int insertedGroupMappings;

  bool get isInserted => status == ImportedCardInsertStatus.inserted;
  bool get isDuplicate => status == ImportedCardInsertStatus.duplicate;
  bool get isInvalid => status == ImportedCardInsertStatus.invalid;
}

enum ImportedCardInsertStatus {
  inserted,
  duplicate,
  invalid,
}
