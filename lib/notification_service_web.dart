class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> init() async {}

  Future<void> cancelAll() async {}

  Future<void> schedule(
    String tag,
    int id,
    String title,
    String body,
    DateTime when, {
    bool playSound = true,
    bool isAdhan = false,
  }) async {}
}
