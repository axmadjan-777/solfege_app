enum AiChatRole { user, model }

class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
  });

  final AiChatRole role;
  final String text;

  Map<String, String> toJson() {
    return {
      'role': role.name,
      'text': text,
    };
  }
}
