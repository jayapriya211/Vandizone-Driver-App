import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../routes/routes.dart';

const String appId = "da5ba2c7378a4397b8fec54f3e4521ce";

// Enhanced VoiceCallScreen with better state management
class VoiceCallScreen extends StatefulWidget {
  final bool isCaller;
  final String? initialChannel;
  final String? callerName;
  final String? callerImage;
  final VoidCallback? onCallEnded;

  const VoiceCallScreen({
    Key? key,
    required this.isCaller,
    this.initialChannel,
    this.callerName,
    this.callerImage,
    this.onCallEnded,
  }) : super(key: key);

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _channelController = TextEditingController();
  RtcEngine? _engine;

  // Call states
  bool _joined = false;
  bool _isConnecting = false;
  int? _remoteUid;
  bool _isMuted = false;
  bool _isSpeakerphone = false;
  bool _showIncomingCall = false;
  CallState _callState = CallState.idle;

  // Timers and animations
  late AnimationController _pulseController;
  late AnimationController _avatarController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _avatarAnimation;
  late Animation<double> _fadeAnimation;

  late final int _randomUid;
  DateTime? _callStartTime;
  String _callDuration = "00:00";

  // Auto-decline timer
  Timer? _autoDeclineTimer;
  static const int _autoDeclineSeconds = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _randomUid = DateTime.now().millisecondsSinceEpoch % 100000;
    _initializeAnimations();
    _initializeCall();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _avatarController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _avatarAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _avatarController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
  }

  void _initializeCall() async {
    await initAgora();

    if (widget.initialChannel != null) {
      _channelController.text = widget.initialChannel!;

      // Set early to prevent "Call Ended" UI flicker
      _callState = widget.isCaller ? CallState.connecting : CallState.incoming;

      setState(() {
        _isConnecting = true;
      });

      await joinChannel();

      if (!widget.isCaller) {
        _startIncomingCallAnimation();
        _startAutoDeclineTimer();
      }
    }
  }


  void _startIncomingCallAnimation() {
    _pulseController.repeat(reverse: true);
    _avatarController.forward();
    _fadeController.forward();

    // Haptic feedback
    HapticFeedback.lightImpact();
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) HapticFeedback.lightImpact();
    });
  }

  void _startAutoDeclineTimer() {
    _autoDeclineTimer = Timer(Duration(seconds: _autoDeclineSeconds), () {
      if (mounted && _callState == CallState.incoming) {
        _declineCall();
      }
    });
  }

  void _startCallTimer() {
    _callStartTime = DateTime.now();
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted || _callState != CallState.connected) {
        timer.cancel();
        return;
      }

      final duration = DateTime.now().difference(_callStartTime!);
      setState(() {
        _callDuration = _formatDuration(duration);
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<String?> fetchAgoraToken(String channelName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user');
        return null;
      }

      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse("https://generateagoratoken-2eejyf46ra-uc.a.run.app"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'channelName': channelName,
          'uid': _randomUid,
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'];
      } else {
        print('❌ Failed to get Agora token: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching Agora token: $e');
      return null;
    }
  }

  Future<void> initAgora() async {
    try {
      // Request permissions
      final permissions = await [
        Permission.microphone,
        Permission.phone,
      ].request();

      if (permissions[Permission.microphone] != PermissionStatus.granted) {
        _showErrorDialog('Microphone permission is required for voice calls');
        return;
      }

      // Initialize Agora engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: appId));
      await _engine!.disableVideo();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableAudio();

      // Register event handlers
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            print('✅ Successfully joined channel: ${connection.channelId}');
            setState(() {
              _joined = true;
              _isConnecting = false;
              _showIncomingCall = false;
              _callState = CallState.connected;
            });
            _stopIncomingCallAnimation();
            _startCallTimer();
          },

          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            print('✅ Remote user joined: $remoteUid');
            setState(() {
              _remoteUid = remoteUid;
              _callState = CallState.connected;
            });
            _startCallTimer();
          },

          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            print('👋 Remote user left: $remoteUid, reason: $reason');

            // Allow ending call in other states like connecting
            if (_callState == CallState.connected || _callState == CallState.connecting || _callState == CallState.incoming) {
              _endCall();
            } else {
              print('⚠️ Ignoring userOffline during $_callState');
            }
          },

          onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            print('🔗 Connection state changed: $state, reason: $reason');

            if (state == ConnectionStateType.connectionStateFailed) {
              _showErrorDialog('Connection failed. Please try again.');
              _endCall();
            }
          },

          onError: (ErrorCodeType err, String msg) {
            print("❌ Agora Error: $err - $msg");
            _showErrorDialog('Call error: $msg');
          },
        ),
      );
    } catch (e) {
      print("❌ Agora initialization failed: $e");
      _showErrorDialog('Failed to initialize call system');
    }
  }

  Future<void> _acceptCall() async {
    _autoDeclineTimer?.cancel();
    HapticFeedback.mediumImpact();

    setState(() {
      _isConnecting = true;
      _callState = CallState.connecting;
    });

    await joinChannel();
  }

  Future<void> _declineCall() async {
    _autoDeclineTimer?.cancel();
    HapticFeedback.mediumImpact();

    setState(() {
      _showIncomingCall = false;
      _callState = CallState.declined;
    });

    _stopIncomingCallAnimation();

    await _sendCallDeclinedNotification();

    Navigator.pop(context);
  }

  Future<void> joinChannel() async {
    if (_channelController.text.trim().isEmpty) {
      _showErrorDialog('Channel name cannot be empty');
      return;
    }

    try {
      final channelName = _channelController.text.trim();
      final agoraToken = await fetchAgoraToken(channelName);

      if (agoraToken == null) {
        _showErrorDialog('Failed to get access token');
        setState(() => _isConnecting = false);
        return;
      }

      await _engine!.joinChannel(
        token: agoraToken,
        channelId: channelName,
        uid: _randomUid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
        ),
      );

      print('🚀 Attempting to join channel: $channelName with UID: $_randomUid');

    } catch (e) {
      print("❌ Failed to join channel: $e");
      _showErrorDialog('Failed to join call: $e');
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _endCall() async {
    try {
      print('⚠️ _endCall() triggered at state: $_callState');

      await _engine?.leaveChannel();

      setState(() {
        _joined = false;
        _remoteUid = null;
        _isConnecting = false;
        _callState = CallState.ended;
      });

      _stopIncomingCallAnimation();
      widget.onCallEnded?.call();

      // 🚨 FIXED: Safe navigation
      Future.delayed(Duration(milliseconds: 300), () {
        if (!mounted) return;

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacementNamed(context, Routes.home);
        }
      });
    } catch (e) {
      print("❌ Error ending call: $e");
    }
  }

  void _stopIncomingCallAnimation() {
    _pulseController.stop();
    _pulseController.reset();
  }

  void toggleMute() async {
    try {
      await _engine?.muteLocalAudioStream(!_isMuted);
      setState(() => _isMuted = !_isMuted);
      HapticFeedback.selectionClick();
    } catch (e) {
      print("❌ Failed to toggle mute: $e");
    }
  }

  void toggleSpeakerphone() async {
    try {
      await _engine?.setEnableSpeakerphone(!_isSpeakerphone);
      setState(() => _isSpeakerphone = !_isSpeakerphone);
      HapticFeedback.selectionClick();
    } catch (e) {
      print("❌ Failed to toggle speakerphone: $e");
    }
  }

  Future<void> _sendCallDeclinedNotification() async {
    // Implementation for notifying caller about declined call
    // This would typically involve FCM or your backend API
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Call Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      // App is in background, keep call active
        break;
      case AppLifecycleState.resumed:
      // App is back in foreground
        break;
      case AppLifecycleState.detached:
        if (_callState == CallState.connected) {
          _endCall();
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoDeclineTimer?.cancel();
    _pulseController.dispose();
    _avatarController.dispose();
    _fadeController.dispose();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  Widget _buildIncomingCallScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.grey[900]!,
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Incoming call',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        widget.callerName ?? _channelController.text,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),

                Spacer(),

                // Avatar with pulse animation
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: AnimatedBuilder(
                          animation: _avatarAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _avatarAnimation.value,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.1),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
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
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                Spacer(),

                // Connection status
                if (_isConnecting)
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: Colors.green,
                          strokeWidth: 2,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Connecting...',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Action buttons
                if (!_isConnecting)
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Decline button
                        _buildActionButton(
                          onTap: _declineCall,
                          color: Colors.red,
                          icon: Icons.call_end,
                          label: 'Decline',
                        ),

                        // Accept button
                        _buildActionButton(
                          onTap: _acceptCall,
                          color: Colors.green,
                          icon: Icons.call,
                          label: 'Accept',
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[700],
      child: Icon(
        Icons.person,
        size: 80,
        color: Colors.white54,
      ),
    );
  }

  Widget _buildActiveCallScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.grey[900]!,
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with call status
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      _remoteUid != null ? 'Connected' : 'Calling...',
                      style: TextStyle(
                        color: _remoteUid != null ? Colors.green : Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _callDuration,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      widget.callerName ?? _channelController.text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),

              Spacer(),

              // Avatar
              Center(
                child: Container(
                  width: 180,
                  height: 180,
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
              ),

              Spacer(),

              // Control buttons
              Padding(
                padding: EdgeInsets.all(40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute button
                    _buildControlButton(
                      onTap: toggleMute,
                      isActive: _isMuted,
                      activeColor: Colors.white,
                      inactiveColor: Colors.grey[800]!,
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      iconColor: _isMuted ? Colors.red : Colors.white,
                    ),

                    // End call button
                    GestureDetector(
                      onTap: _endCall,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),

                    // Speaker button
                    _buildControlButton(
                      onTap: toggleSpeakerphone,
                      isActive: _isSpeakerphone,
                      activeColor: Colors.white,
                      inactiveColor: Colors.grey[800]!,
                      icon: _isSpeakerphone ? Icons.volume_up : Icons.phone,
                      iconColor: _isSpeakerphone ? Colors.blue : Colors.white,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback onTap,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? activeColor : inactiveColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 25,
        ),
      ),
    );
  }

  Widget _buildCallerModeScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text("Voice Call"),
        backgroundColor: Colors.green[600],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _channelController,
              decoration: InputDecoration(
                labelText: 'Channel Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isConnecting ? null : joinChannel,
              child: Text(_isConnecting ? "Connecting..." : "Start Call"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 32),
              ),
            ),
            if (_joined) ...[
              SizedBox(height: 20),
              Text("Call Duration: $_callDuration"),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: toggleMute,
                    child: Text(_isMuted ? "Unmute" : "Mute"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isMuted ? Colors.red : Colors.grey,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _endCall,
                    child: Text("End Call"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_callState == CallState.incoming) {
      return _buildIncomingCallScreen();
    } else if (_callState == CallState.connecting) {
      return _buildConnectingScreen();
    } else if (_callState == CallState.connected) {
      return _buildActiveCallScreen();
    } else if (_callState == CallState.ended || _callState == CallState.declined) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Call Ended',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      );
    } else {
      // Default placeholder for idle or loading state
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
  }

  Widget _buildConnectingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Connecting...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// Call state enum for better state management
enum CallState {
  idle,
  incoming,
  connecting,
  connected,
  ended,
  declined,
}

// Enhanced notification handler with better error handling
class CallNotificationManager {
  static Future<void> showIncomingCallNotification(
      RemoteMessage message,
      FlutterLocalNotificationsPlugin notificationsPlugin,
      ) async {
    final callerName = message.data['callerName'] ??
        message.notification?.title ??
        'Unknown Caller';
    final channelName = message.data['channelName'] ?? '';
    final callerImage = message.data['callerImage'];

    if (channelName.isEmpty) {
      print('❌ Missing channel name in call notification');
      return;
    }

    final notificationId = channelName.hashCode;

    try {
      const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
        'incoming_call_channel',
        'Incoming Calls',
        description: 'Incoming voice calls',
        importance: Importance.max,
        playSound: true,
      );

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
              contextual: true,
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'decline',
              'Decline',
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

      await notificationsPlugin.show(
        notificationId,
        '📞 Incoming Call',
        'From: $callerName',
        notificationDetails,
        payload: jsonEncode(message.data),
      );

      print('✅ Incoming call notification shown for: $callerName');
    } catch (e) {
      print('❌ Error showing incoming call notification: $e');
    }
  }
}