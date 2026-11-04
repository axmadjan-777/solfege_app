import 'dart:math';

enum AiChatRole { user, model }

/// Stable across retries, including an interrupted acknowledgement.
String newChatMessageId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

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
