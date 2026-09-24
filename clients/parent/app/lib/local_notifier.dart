// The platform side of the app's notifications (R-NOTIFY-14): a local
// notification, nothing more. Android (a channel), iOS and macOS (Darwin).
// Windows has no adapter here yet, so on Windows the lists work and nothing is
// raised; the notice label says so.
//
// This is the one file that talks to the OS notification plugin. Every rule --
// what is raised, what is cleared -- lives in notifier.dart and is tested there.

import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:omarchy_kids_parent/feed.dart';

import 'notifier.dart';

class LocalNotifier implements Notifier {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  void Function(NoticeTap tap)? _onTap;

  /// True on a platform this adapter can raise a notification on. Windows is not
  /// wired: the app still lists and decides, it just cannot raise one there.
  static bool get supported => const {'android', 'ios', 'macos'}.contains(Platform.operatingSystem);

  @override
  Future<void> initialize({required void Function(NoticeTap tap) onTap}) async {
    _onTap = onTap;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Ask for nothing at initialize: the permission is requested once after
    // pairing (below), and a refusal only means no notifications, never a broken
    // list.
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin, macOS: darwin),
      onDidReceiveNotificationResponse: _dispatch,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: false, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: false, sound: true);
    // A tap that launched the app (it was not running): deliver it too, once the
    // app is alive; the row opens when the first document carries it.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    final tap = parseNoticePayload(payload);
    if (launch?.didNotificationLaunchApp == true && tap != null) onTap(tap);
  }

  void _dispatch(NotificationResponse response) {
    final tap = parseNoticePayload(response.payload);
    if (tap != null) _onTap?.call(tap);
  }

  @override
  Future<void> show({
    required String kind,
    required String id,
    required String title,
    required String body,
  }) async {
    final platformId = await platformNotificationId(kind, id);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'kids-mode',
        'Kids Mode',
        channelDescription: 'Requests and add-on changes from the computer',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    await _plugin.show(platformId, title, body, details, payload: noticePayload(kind, id));
  }

  @override
  Future<void> cancel({required String kind, required String id}) async {
    await _plugin.cancel(await platformNotificationId(kind, id));
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
