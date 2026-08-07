enum Sender { user, k }

class ChatMessage {
  final String text;
  final Sender sender;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.sender,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'text': text,
        'sender': sender.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String,
        sender: Sender.values.firstWhere((e) => e.name == json['sender']),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
