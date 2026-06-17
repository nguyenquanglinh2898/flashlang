import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/card_model.dart';
import '../services/tts_service.dart';
import '../widgets/confirm_dialog.dart';
import 'review_setup_screen.dart';

class ReviewSessionScreen extends StatefulWidget {
  const ReviewSessionScreen({
    super.key,
    required this.cards,
    required this.optionPool,
    required this.mode,
  });

  final List<ReviewCardData> cards;
  final List<ReviewCardData> optionPool;
  final ReviewMode mode;

  @override
  State<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends State<ReviewSessionScreen> {
  late final List<_ReviewQuestion> _questions;
  final List<_ReviewAnswerRecord> _answers = <_ReviewAnswerRecord>[];
  final TextEditingController _typedAnswerController = TextEditingController();

  int _currentIndex = 0;
  bool _showAnswer = false;
  String? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _questions = _buildQuestions(widget.cards);
  }

  @override
  void dispose() {
    _typedAnswerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _ReviewQuestion currentQuestion = _questions[_currentIndex];
    final double progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == ReviewMode.englishToVietnamese
              ? 'Review Session'
              : 'Reverse Review',
        ),
        actions: <Widget>[
          TextButton(onPressed: _finishReview, child: const Text('Finish')),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Card ${_currentIndex + 1} of ${_questions.length}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: progress),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _showAnswer
                    ? _ReviewAnswerCard(
                        key: const ValueKey<String>('answer'),
                        question: currentQuestion,
                        selectedAnswer: _selectedAnswer,
                        mode: widget.mode,
                      )
                    : widget.mode == ReviewMode.englishToVietnamese
                    ? _MultipleChoiceQuestionCard(
                        key: const ValueKey<String>('mcq'),
                        question: currentQuestion,
                        selectedAnswer: _selectedAnswer,
                        onAnswerSelected: _handleAnswerSelection,
                      )
                    : _TypedQuestionCard(
                        key: const ValueKey<String>('typed'),
                        question: currentQuestion,
                        controller: _typedAnswerController,
                        onSubmit: _handleTypedSubmission,
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (_showAnswer)
              FilledButton.icon(
                onPressed: _goToNextCard,
                icon: Icon(
                  _currentIndex == _questions.length - 1
                      ? Icons.check_circle_outline_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  _currentIndex == _questions.length - 1
                      ? 'Xem kết quả'
                      : 'Tiếp theo',
                ),
              )
            else if (widget.mode == ReviewMode.englishToVietnamese)
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.touch_app_rounded),
                label: const Text('Chọn một đáp án'),
              )
            else
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _typedAnswerController,
                builder: (_, TextEditingValue value, __) {
                  return FilledButton.icon(
                    onPressed: value.text.trim().isEmpty
                        ? null
                        : _handleTypedSubmission,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Trả lời'),
                  );
                },
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _confirmStopReview,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Dừng ôn tập'),
            ),
          ],
        ),
      ),
    );
  }

  List<_ReviewQuestion> _buildQuestions(List<ReviewCardData> cards) {
    final Random random = Random();
    final List<ReviewCardData> shuffledCards = List<ReviewCardData>.from(cards)
      ..shuffle(random);

    return shuffledCards.map((_cardToQuestion)).toList(growable: false);
  }

  _ReviewQuestion _cardToQuestion(ReviewCardData item) {
    final Random random = Random();
    final Set<String> optionSet = <String>{item.card.meaning.trim()};
    final List<String> distractors =
        widget.optionPool
            .where((ReviewCardData other) => other.card.id != item.card.id)
            .map((ReviewCardData other) => other.card.meaning.trim())
            .where((String meaning) => meaning.isNotEmpty)
            .toSet()
            .toList()
          ..shuffle(random);

    for (final String distractor in distractors) {
      if (optionSet.length >= 6) {
        break;
      }
      optionSet.add(distractor);
    }

    final List<String> options = optionSet.toList()..shuffle(random);

    return _ReviewQuestion(
      item: item,
      correctAnswer: item.card.meaning.trim(),
      options: options,
    );
  }

  void _handleAnswerSelection(String selectedAnswer) {
    if (_showAnswer) {
      return;
    }

    final _ReviewQuestion question = _questions[_currentIndex];
    final bool isCorrect = selectedAnswer == question.correctAnswer;
    _recordAnswer(selectedAnswer: selectedAnswer, isCorrect: isCorrect);
  }

  void _handleTypedSubmission() {
    if (_showAnswer) {
      return;
    }

    final _ReviewQuestion question = _questions[_currentIndex];
    final String selectedAnswer = _typedAnswerController.text.trim();
    final bool isCorrect =
        _normalizeAnswer(selectedAnswer) ==
        _normalizeAnswer(question.item.card.word);
    _recordAnswer(selectedAnswer: selectedAnswer, isCorrect: isCorrect);
  }

  void _recordAnswer({
    required String selectedAnswer,
    required bool isCorrect,
  }) {
    final _ReviewQuestion question = _questions[_currentIndex];
    _answers.add(
      _ReviewAnswerRecord(
        question: question,
        selectedAnswer: selectedAnswer,
        isCorrect: isCorrect,
      ),
    );

    setState(() {
      _selectedAnswer = selectedAnswer;
      _showAnswer = true;
    });
  }

  Future<void> _goToNextCard() async {
    if (_currentIndex >= _questions.length - 1) {
      await _finishReview();
      return;
    }

    setState(() {
      _currentIndex++;
      _showAnswer = false;
      _selectedAnswer = null;
      _typedAnswerController.clear();
    });
  }

  Future<void> _confirmStopReview() async {
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: 'Stop review?',
      message: 'We will show your score based on the answers so far.',
      confirmText: 'Finish',
      isDestructive: false,
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _finishReview();
  }

  Future<void> _finishReview() async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => _ReviewResultScreen(
          totalQuestions: _questions.length,
          answers: List<_ReviewAnswerRecord>.unmodifiable(_answers),
          mode: widget.mode,
        ),
      ),
    );
  }

  String _normalizeAnswer(String value) {
    return value.trim().toLowerCase();
  }
}

class _MultipleChoiceQuestionCard extends StatelessWidget {
  const _MultipleChoiceQuestionCard({
    super.key,
    required this.question,
    required this.selectedAnswer,
    required this.onAnswerSelected,
  });

  final _ReviewQuestion question;
  final String? selectedAnswer;
  final ValueChanged<String> onAnswerSelected;

  @override
  Widget build(BuildContext context) {
    final CardModel card = question.item.card;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    card.word,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => TtsService.instance.speak(card.word),
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ],
            ),
            if (card.hasPhonetic) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                card.phonetic!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            if (card.hasPartOfSpeech) ...<Widget>[
              const SizedBox(height: 14),
              Chip(label: Text(card.partOfSpeech!)),
            ],
            const SizedBox(height: 18),
            Text(
              'Chọn nghĩa đúng',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: question.options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final String option = question.options[index];
                  return OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: selectedAnswer == null
                        ? () => onAnswerSelected(option)
                        : null,
                    child: Text(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypedQuestionCard extends StatelessWidget {
  const _TypedQuestionCard({
    super.key,
    required this.question,
    required this.controller,
    required this.onSubmit,
  });

  final _ReviewQuestion question;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final CardModel card = question.item.card;

    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              card.meaning,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (card.hasImage) ...<Widget>[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Image.file(
                    File(card.imagePath!),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) {
                      return Container(
                        height: 160,
                        alignment: Alignment.center,
                        child: const Text('Image not available'),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Gõ từ tiếng Anh',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'English word',
                hintText: 'Type your answer',
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewAnswerCard extends StatelessWidget {
  const _ReviewAnswerCard({
    super.key,
    required this.question,
    required this.selectedAnswer,
    required this.mode,
  });

  final _ReviewQuestion question;
  final String? selectedAnswer;
  final ReviewMode mode;

  @override
  Widget build(BuildContext context) {
    final CardModel card = question.item.card;
    final bool isCorrect = mode == ReviewMode.englishToVietnamese
        ? selectedAnswer == question.correctAnswer
        : selectedAnswer?.trim().toLowerCase() ==
              card.word.trim().toLowerCase();

    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isCorrect
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isCorrect ? 'Chính xác' : 'Chưa đúng',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              mode == ReviewMode.englishToVietnamese ? card.word : card.meaning,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (mode == ReviewMode.englishToVietnamese &&
                card.hasPhonetic) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                card.phonetic!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 18),
            _AnswerInfoTile(label: 'Bạn chọn', value: selectedAnswer ?? '-'),
            const SizedBox(height: 10),
            _AnswerInfoTile(
              label: 'Đáp án đúng',
              value: mode == ReviewMode.englishToVietnamese
                  ? question.correctAnswer
                  : card.word,
              highlight: true,
            ),
            if (card.hasImage) ...<Widget>[
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 320),
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Image.file(
                    File(card.imagePath!),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) {
                      return Container(
                        height: 180,
                        alignment: Alignment.center,
                        child: const Text('Image not available'),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerInfoTile extends StatelessWidget {
  const _AnswerInfoTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: highlight
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewResultScreen extends StatelessWidget {
  const _ReviewResultScreen({
    required this.totalQuestions,
    required this.answers,
    required this.mode,
  });

  final int totalQuestions;
  final List<_ReviewAnswerRecord> answers;
  final ReviewMode mode;

  @override
  Widget build(BuildContext context) {
    final int correctCount = answers
        .where((_ReviewAnswerRecord answer) => answer.isCorrect)
        .length;
    final int answeredCount = answers.length;
    final int incorrectCount = answers
        .where((_ReviewAnswerRecord answer) => !answer.isCorrect)
        .length;
    final double percentage = totalQuestions == 0
        ? 0
        : (correctCount / totalQuestions) * 100;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Review Result'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$correctCount/$totalQuestions',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${percentage.toStringAsFixed(0)}% correct',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Answered: $answeredCount/$totalQuestions'),
                  Text('Wrong answers: $incorrectCount'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (incorrectCount == 0)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Great job. You answered every reviewed card correctly.',
                ),
              ),
            )
          else ...<Widget>[
            Text(
              'Wrong answers',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...answers
                .where((_ReviewAnswerRecord answer) => !answer.isCorrect)
                .map(
                  (_ReviewAnswerRecord answer) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            mode == ReviewMode.englishToVietnamese
                                ? answer.question.item.card.word
                                : answer.question.item.card.meaning,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Text('Your answer: ${answer.selectedAnswer}'),
                          const SizedBox(height: 6),
                          Text(
                            'Correct answer: ${mode == ReviewMode.englishToVietnamese ? answer.question.correctAnswer : answer.question.item.card.word}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ),
    );
  }
}

class _ReviewQuestion {
  const _ReviewQuestion({
    required this.item,
    required this.correctAnswer,
    required this.options,
  });

  final ReviewCardData item;
  final String correctAnswer;
  final List<String> options;
}

class _ReviewAnswerRecord {
  const _ReviewAnswerRecord({
    required this.question,
    required this.selectedAnswer,
    required this.isCorrect,
  });

  final _ReviewQuestion question;
  final String selectedAnswer;
  final bool isCorrect;
}
