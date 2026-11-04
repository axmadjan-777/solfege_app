enum AiChatRole { user, model }

class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
    this.id,
    this.stored = false,
  });

  final AiChatRole role;
  final String text;
  final String? id;
  final bool stored;

  AiChatMessage markStored({String? id}) {
    return AiChatMessage(
      role: role,
      text: text,
      id: id ?? this.id,
      stored: true,
    );
  }

  Map<String, String> toJson() {
    return {
      'role': role.name,
      'text': text,
    };
  }
}
