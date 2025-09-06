import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sizer/sizer.dart';
import 'package:vandizone_caption/utils/key.dart';
import 'package:audioplayers/audioplayers.dart';
import 'helper/voice_call.dart';
import 'routes/routes.dart';
import 'theme/my_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void printFCMMessageDetails(RemoteMessage message, String context) {
  print('\n=== FCM Message Details ($context) ===');
  print('📩 Message ID: ${message.messageId}');
  print('📝 From: ${message.from}');
  print('⏰ Sent Time: ${message.sentTime}');
  print('🎯 Category: ${message.category}');
  print('📋 Message Type: ${message.messageType}');
  print('📱 Thread ID: ${message.threadId}');

  // Print notification details
  if (message.notification != null) {
    print('\n📢 Notification:');
    print('  Title: ${message.notification!.title}');
    print('  Body: ${message.notification!.body}');
    print('  Android Channel ID: ${message.notification!.android?.channelId}');
    print('  Android Sound: ${message.notification!.android?.sound}');
    print('  Android Priority: ${message.notification!.android?.priority}');
    print('  iOS Sound: ${message.notification!.apple?.sound}');
    print('  iOS Badge: ${message.notification!.apple?.badge}');
  } else {
    print('\n📢 Notification: null');
  }

  // Print all data payload
  print('\n📦 Data Payload:');
  if (message.data.isNotEmpty) {
    message.data.forEach((key, value) {
      print('  $key: $value (${value.runtimeType})');
    });

    // Specifically check for 'type' field
    if (message.data.containsKey('type')) {
      print('🔍 TYPE FOUND: "${message.data['type']}" (${message.data['type'].runtimeType})');
    } else {
      print('❌ NO TYPE FIELD FOUND');
    }
  } else {
    print('  (empty)');
  }

  print('================================\n');
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  printFCMMessageDetails(message, 'BACKGROUND');

  final messageType = message.data['type'];
  print('🔎 Checking message type: "$messageType"');

  if (messageType == 'voice_call') {
    print('✅ Voice call detected - showing call notification');
    await _showIncomingCallNotification(message);
  } else {
    print('📬 Regular message detected - showing normal notification');
    await _showNotification(message);
  }
}

const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
  'incoming_call_channel',
  'Incoming Calls',
  description: 'Incoming voice calls',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('phone_ring'),
);

const AndroidNotificationChannel fcmChannel = AndroidNotificationChannel(
  'fcm_channel',
  'FCM Notifications',
  description: 'General FCM Notifications',
  importance: Importance.high,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('phone_ring'),
);

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: null,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print('🔔 Notification tapped: ${response.payload}');
      _handleNotificationAction(response);
    },
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(callChannel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(fcmChannel);
}

void _handleNotificationAction(NotificationResponse response) {
  print('\n=== Notification Action Handler ===');
  print('🔔 Action ID: ${response.actionId}');
  print('📝 Payload: ${response.payload}');
  print('📱 Input: ${response.input}');

  try {
    final data = jsonDecode(response.payload ?? '{}');
    print('📦 Parsed data: $data');

    final messageType = data['type'];
    print('🔎 Message type from payload: "$messageType"');

    if (messageType == 'voice_call') {
      print('✅ Voice call action detected');
      if (response.actionId == 'answer') {
        print('📞 Answering call');
        _answerCall(data);
      } else if (response.actionId == 'decline') {
        print('📞 Declining call');
        _declineCall(data);
      } else {
        print('📞 Showing full screen call');
        _showFullScreenCall(data);
      }
    } else {
      print('📬 Regular notification action');
    }
  } catch (e) {
    print('❌ Error parsing notification payload: $e');
  }

  print('================================\n');
}

void _showFullScreenCall(Map<String, dynamic> data) {
  if (navigatorKey.currentState != null) {
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callerName: data['callerName'] ?? 'Unknown',
          callerImage: data['callerImage'],
          channelName: data['channelName'],
          onAnswer: () => _answerCall(data),
          onDecline: () => _declineCall(data),
        ),
      ),
    );
  }
}

void _answerCall(Map<String, dynamic> data) {
  flutterLocalNotificationsPlugin.cancel(data['channelName'].hashCode);
  if (navigatorKey.currentState != null) {
    navigatorKey.currentState!.pushReplacement(
      MaterialPageRoute(
        builder: (_) => VoiceCallScreen(
          isCaller: false,
          initialChannel: data['channelName'],
          callerName: data['callerName'],
          callerImage: data['callerImage'],
        ),
      ),
    );
  }
}

void _declineCall(Map<String, dynamic> data) {
  flutterLocalNotificationsPlugin.cancel(data['channelName'].hashCode);
  print('📞 Call declined');
}

Future<void> checkAndRequestPermissions() async {
  final status = await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.areNotificationsEnabled();

  if (status == false) {
    print('⚠️ Notifications are disabled!');
  }

  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print('🔐 Notification permission: ${settings.authorizationStatus}');
}

AudioPlayer? _ringtonePlayer;

Future<void> startRingtone() async {
  _ringtonePlayer ??= AudioPlayer();
  await _ringtonePlayer!.setReleaseMode(ReleaseMode.loop); // Loop until stopped
  await _ringtonePlayer!.play(AssetSource('notification.mp3'));
}

Future<void> stopRingtone() async {
  await _ringtonePlayer?.stop();
}

Future<void> _showIncomingCallNotification(RemoteMessage message) async {
  await startRingtone();
  final callerName = message.data['callerName'] ?? message.notification?.title ?? 'Unknown Caller';
  final channelName = message.data['channelName'] ?? '';

  final notificationId = channelName.hashCode;

  final notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      callChannel.id,
      callChannel.name,
      channelDescription: callChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('phone_ring'),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      icon: '@mipmap/ic_launcher',
      // largeIcon: DrawableResourceAndroidBitmap('@mipmap/caller_avatar'),
      color: const Color(0xFF4CAF50),
      colorized: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: false,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
      actions: [
        AndroidNotificationAction(
          'answer',
          'Answer',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_call_answer'),
          contextual: true,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'decline',
          'Decline',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_call_decline'),
          contextual: true,
          showsUserInterface: false,
        ),
      ],
      styleInformation: BigTextStyleInformation(
        'Incoming call from $callerName',
        htmlFormatBigText: true,
        contentTitle: '📞 Incoming Call',
        htmlFormatContentTitle: true,
        summaryText: 'Tap to answer or decline',
        htmlFormatSummaryText: true,
      ),
    ),
  );

  await flutterLocalNotificationsPlugin.show(
    notificationId,
    '📞 Incoming Call',
    'From: $callerName',
    notificationDetails,
    payload: jsonEncode(message.data),
  );

  if (navigatorKey.currentState != null) {
    _showFullScreenCall(message.data);
  }
}

Future<void> _showNotification(RemoteMessage message) async {
  final notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      fcmChannel.id,
      fcmChannel.name,
      channelDescription: fcmChannel.description,
      importance: fcmChannel.importance,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('phone_ring'),
      icon: '@mipmap/ic_launcher',
      color: Colors.blue,
      priority: Priority.high,
    ),
  );

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'New Notification',
    message.notification?.body ?? 'You have a new message',
    notificationDetails,
    payload: jsonEncode(message.data),
  );
}

// Full-screen incoming call widget
class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String? callerImage;
  final String channelName;
  final VoidCallback onAnswer;
  final VoidCallback onDecline;

  const IncomingCallScreen({
    Key? key,
    required this.callerName,
    this.callerImage,
    required this.channelName,
    required this.onAnswer,
    required this.onDecline,
  }) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the answer button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Slide animation for the screen
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1a1a1a),
                Color(0xFF000000),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top section with caller info
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Incoming call',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Caller avatar
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: widget.callerImage != null
                              ? Image.network(
                            widget.callerImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildDefaultAvatar(),
                          )
                              : _buildDefaultAvatar(),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Caller name
                      Text(
                        widget.callerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Voice call',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 50),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Decline button
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            widget.onDecline();
                          },
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                        // Answer button with pulse animation
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            widget.onAnswer();
                          },
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.call,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(
        Icons.person,
        size: 80,
        color: Colors.white70,
      ),
    );
  }
}

// Enhanced main function with detailed logging
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Future<void> _fetchPlatformSettings() async {
    final platformDoc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('platformSettings')
        .get();

    if (platformDoc.exists) {
      final data = platformDoc.data();
      if (data != null && data.containsKey('mapApiKey')) {
        googleMapApiKey = data['mapApiKey'];
        tollGuruApiKey = data['tollGuruApiKey'];
        debugPrint('✅ Google Map API Key set: $googleMapApiKey');
      } else {
        debugPrint('❌ mapApiKey not found in settings/platformSettings');
      }
    } else {
      debugPrint('❌ platformSettings document does not exist');
    }
  }

  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');

    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    await initializeNotifications();
    await checkAndRequestPermissions();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Enhanced foreground message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Print detailed message info
      printFCMMessageDetails(message, 'FOREGROUND');

      final messageType = message.data['type'];
      print('🔎 Checking message type: "$messageType"');

      if (messageType == 'voice_call') {
        print('✅ Voice call detected - showing call notification');
        _showIncomingCallNotification(message);
      } else {
        print('📬 Regular message detected - showing normal notification');
        _showNotification(message);
      }
    });

    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      printFCMMessageDetails(initialMessage, 'COLD START');

      if (initialMessage.data['type'] == 'voice_call') {
        print('✅ Cold start voice call detected');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showFullScreenCall(initialMessage.data);
        });
      }
    }

    // FCM token
    final token = await FirebaseMessaging.instance.getToken();
    print('📲 FCM Token: $token');
  } catch (e) {
    print('❌ Initialization error: $e');
  }

  await _fetchPlatformSettings();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (_, __, ___) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: MyTheme.lightTheme,
          initialRoute: Routes.initialRoute,
          onGenerateRoute: Routes.generateRoute,
        ),
      ),
    );
  }
}