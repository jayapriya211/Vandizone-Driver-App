class NotificationModel {
  final String id;
  final String title;
  final String subtitle;
  final String dateTime;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.dateTime,
    this.isRead = false,
  });
}
