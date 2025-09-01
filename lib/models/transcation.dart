class Transcation {
  final String id;
  final String title;
  final String dateTime;
  final bool isSuccess;
  final String amount;

  Transcation({
    required this.id,
    required this.title,
    required this.dateTime,
    this.isSuccess = false,
    required this.amount,
  });
}
