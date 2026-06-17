import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/card_model.dart';
import '../models/group_model.dart';

class CardProvider extends ChangeNotifier {
  CardProvider({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  List<CardModel> _cards = <CardModel>[];
  bool _isLoading = false;
  String? _errorMessage;
  int? _activeGroupId;

  List<CardModel> get cards => List<CardModel>.unmodifiable(_cards);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get activeGroupId => _activeGroupId;
  bool get hasCards => _cards.isNotEmpty;

  Future<void> loadCardsByGroup(int groupId) async {
    _activeGroupId = groupId;
    _setLoading(true);
    _clearError();

    try {
      _cards = await _databaseHelper.getCardsByGroupId(groupId);
    } catch (error) {
      _setError('Failed to load cards: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAllCards() async {
    _activeGroupId = null;
    _setLoading(true);
    _clearError();

    try {
      _cards = await _databaseHelper.getAllCards();
    } catch (error) {
      _setError('Failed to load all cards: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<CardDetailData?> getCardDetail(int cardId) async {
    _clearError();

    try {
      final CardModel? card = await _databaseHelper.getCardById(cardId);
      if (card == null) {
        return null;
      }

      final List<GroupModel> groups = await _databaseHelper.getGroupsForCard(
        cardId,
      );
      return CardDetailData(card: card, groups: groups);
    } catch (error) {
      _setError('Failed to get card detail: $error');
      return null;
    }
  }

  Future<List<int>> getSelectedGroupIds(int cardId) async {
    _clearError();

    try {
      return await _databaseHelper.getGroupIdsForCard(cardId);
    } catch (error) {
      _setError('Failed to load selected groups: $error');
      return <int>[];
    }
  }

  Future<int?> addCard({
    required String word,
    String? partOfSpeech,
    String? phonetic,
    required String meaning,
    String? imagePath,
    required List<int> groupIds,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final CardModel card = CardModel(
        word: word,
        partOfSpeech: partOfSpeech,
        phonetic: phonetic,
        meaning: meaning,
        imagePath: imagePath,
        createdAt: DateTime.now(),
      );

      final int cardId = await _databaseHelper.insertCard(card, groupIds);
      await _reloadActiveCollection();
      return cardId;
    } catch (error) {
      _setError('Failed to add card: $error');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateCard({
    required int cardId,
    required String word,
    String? partOfSpeech,
    String? phonetic,
    required String meaning,
    String? imagePath,
    required List<int> groupIds,
    DateTime? createdAt,
    DateTime? lastPushedAt,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final CardModel? existingCard = await _databaseHelper.getCardById(cardId);
      if (existingCard == null) {
        _setError('Card not found.');
        return false;
      }

      final CardModel updatedCard = existingCard.copyWith(
        word: word,
        partOfSpeech: partOfSpeech,
        clearPartOfSpeech: (partOfSpeech ?? '').trim().isEmpty,
        phonetic: phonetic,
        clearPhonetic: (phonetic ?? '').trim().isEmpty,
        meaning: meaning,
        imagePath: imagePath,
        clearImagePath: (imagePath ?? '').trim().isEmpty,
        createdAt: createdAt ?? existingCard.createdAt,
        lastPushedAt: lastPushedAt ?? existingCard.lastPushedAt,
      );

      await _databaseHelper.updateCard(updatedCard, groupIds);
      await _reloadActiveCollection();

      return true;
    } catch (error) {
      _setError('Failed to update card: $error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteCard(int cardId) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseHelper.deleteCard(cardId);
      _cards = _cards.where((CardModel card) => card.id != cardId).toList();

      notifyListeners();
      return true;
    } catch (error) {
      _setError('Failed to delete card: $error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<CardModel?> getCardById(int cardId) async {
    _clearError();

    try {
      return await _databaseHelper.getCardById(cardId);
    } catch (error) {
      _setError('Failed to get card: $error');
      return null;
    }
  }

  Future<CardModel?> getNextCardForNotification() async {
    _clearError();

    try {
      return await _databaseHelper.getNextCardForNotification();
    } catch (error) {
      _setError('Failed to get next card for notification: $error');
      return null;
    }
  }

  Future<CardModel?> getMostRecentlyPushedCard() async {
    _clearError();

    try {
      return await _databaseHelper.getMostRecentlyPushedCard();
    } catch (error) {
      _setError('Failed to get last pushed card: $error');
      return null;
    }
  }

  Future<List<ReviewCardData>> getReviewCards({List<int>? groupIds}) async {
    _clearError();

    try {
      return await _databaseHelper.getReviewCards(groupIds: groupIds);
    } catch (error) {
      _setError('Failed to load review cards: $error');
      return <ReviewCardData>[];
    }
  }

  Future<void> markCardAsPushed(int cardId) async {
    _clearError();

    try {
      await _databaseHelper.updateCardLastPushedAt(cardId, DateTime.now());

      final int cardIndex = _cards.indexWhere(
        (CardModel card) => card.id == cardId,
      );
      if (cardIndex != -1) {
        _cards[cardIndex] = _cards[cardIndex].copyWith(
          lastPushedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (error) {
      _setError('Failed to update push timestamp: $error');
    }
  }

  Future<bool> updateMasteredStatus(int cardId, bool isMastered) async {
    _clearError();

    try {
      await _databaseHelper.updateCardMastered(cardId, isMastered);
      final int cardIndex = _cards.indexWhere(
        (CardModel card) => card.id == cardId,
      );
      if (cardIndex != -1) {
        _cards[cardIndex] = _cards[cardIndex].copyWith(isMastered: isMastered);
        notifyListeners();
      }
      return true;
    } catch (error) {
      _setError('Failed to update mastered status: $error');
      return false;
    }
  }

  Future<void> importCardRow({
    required String word,
    String? partOfSpeech,
    String? phonetic,
    required String meaning,
    String? imagePath,
    required List<String> groupNames,
  }) async {
    await importCardRowWithResult(
      word: word,
      partOfSpeech: partOfSpeech,
      phonetic: phonetic,
      meaning: meaning,
      imagePath: imagePath,
      groupNames: groupNames,
    );
  }

  Future<ImportedCardInsertResult> importCardRowWithResult({
    required String word,
    String? partOfSpeech,
    String? phonetic,
    required String meaning,
    String? imagePath,
    required List<String> groupNames,
  }) async {
    _clearError();

    try {
      final ImportedCardInsertResult result = await _databaseHelper
          .insertImportedCard(
            word: word,
            partOfSpeech: partOfSpeech,
            phonetic: phonetic,
            meaning: meaning,
            imagePath: imagePath,
            groupNames: groupNames,
          );
      if (result.isInserted) {
        await _reloadActiveCollection();
      }
      return result;
    } catch (error) {
      _setError('Failed to import card: $error');
      return const ImportedCardInsertResult.invalid();
    }
  }

  Future<List<ExportableCardRow>> getExportRowsForGroup(int groupId) async {
    _clearError();

    try {
      return await _databaseHelper.getCardsForExportByGroup(groupId);
    } catch (error) {
      _setError('Failed to prepare export rows: $error');
      return <ExportableCardRow>[];
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_activeGroupId != null) {
      await loadCardsByGroup(_activeGroupId!);
      return;
    }

    await loadAllCards();
  }

  Future<void> _reloadActiveCollection() async {
    if (_activeGroupId != null) {
      _cards = await _databaseHelper.getCardsByGroupId(_activeGroupId!);
    } else {
      _cards = await _databaseHelper.getAllCards();
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}

class CardDetailData {
  const CardDetailData({required this.card, required this.groups});

  final CardModel card;
  final List<GroupModel> groups;
}
