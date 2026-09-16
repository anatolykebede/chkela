const aiFreeQuestionLimit = 3;

const aiSuggestedPrompts = [
  ('Explain this section simply', '📖'),
  ('Give me an example', '✏️'),
  ('What are my weak spots?', '📊'),
  ('Quiz me (3–5 questions)', '📝'),
];

class AiChatMessage {
  const AiChatMessage({
    required this.isUser,
    required this.text,
  });

  final bool isUser;
  final String text;
}
