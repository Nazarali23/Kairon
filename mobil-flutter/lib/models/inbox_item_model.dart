class InboxItemModel {
  final String id;
  final String title;
  final String body;
  final String source;
  final String kind;
  final String? filePath;
  final bool isRead;
  final DateTime? createdAt;
  final String? userId;

  InboxItemModel({
    required this.id,
    required this.title,
    required this.body,
    this.source = 'pc_agent',
    this.kind = 'summary',
    this.filePath,
    this.isRead = false,
    this.createdAt,
    this.userId,
  });

  factory InboxItemModel.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    if (json['created_at'] != null) {
      try {
        dt = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }

    return InboxItemModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Bilgilendirme',
      body: json['body']?.toString() ?? '',
      source: json['source']?.toString() ?? 'pc_agent',
      kind: json['kind']?.toString() ?? 'summary',
      filePath: json['file_path']?.toString(),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: dt,
      userId: json['user_id']?.toString(),
    );
  }
}
