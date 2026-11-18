class ReminderModel {
  final int? id;
  final String text;
  final String due;
  final bool asked;
  final String? userId;
  final String recurring;

  ReminderModel({
    this.id,
    required this.text,
    required this.due,
    this.asked = false,
    this.userId,
    this.recurring = 'none',
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as int?,
      text: json['text']?.toString() ?? '',
      due: json['due']?.toString() ?? '',
      asked: json['asked'] as bool? ?? false,
      userId: json['user_id']?.toString(),
      recurring: json['recurring']?.toString() ?? 'none',
    );
  }

  Map<String, dynamic> toJson({String? currentUserId}) {
    return {
      'text': text,
      'due': due,
      'asked': asked,
      if (currentUserId != null) 'user_id': currentUserId,
      'recurring': recurring,
    };
  }

  ReminderModel copyWith({
    int? id,
    String? text,
    String? due,
    bool? asked,
    String? userId,
    String? recurring,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      text: text ?? this.text,
      due: due ?? this.due,
      asked: asked ?? this.asked,
      userId: userId ?? this.userId,
      recurring: recurring ?? this.recurring,
    );
  }
}
