import 'content/content_store.dart';

class FlashCard {
  const FlashCard({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}

class FlashcardReviewResult {
  const FlashcardReviewResult({
    required this.card,
    required this.cardNumber,
    required this.known,
  });

  final FlashCard card;
  final int cardNumber;
  final bool known;
}

class FlashcardSessionArgs {
  const FlashcardSessionArgs({
    required this.subjectName,
    required this.chapterTitle,
    required this.chapterId,
    this.deckId,
    this.deckTitle,
  });

  final String subjectName;
  final String chapterTitle;
  final String chapterId;
  final String? deckId;
  final String? deckTitle;
}

List<FlashCard> flashcardsForChapter(
  String chapterId,
  String chapterTitle, {
  String? deckId,
}) {
  final store = ContentStore.instance;
  if (!store.isLoaded) return const [];
  // Trust CMS only: never invent placeholder cards for empty decks.
  return store.flashcardsForChapter(chapterId, deckId: deckId);
}
