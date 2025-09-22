import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';
import 'dart:io';
import '../../../widgets/my_textfield.dart';
import '../../helper/voice_call.dart';
import '../../views/home/ride_tracking/ride_tracking_view.dart';
import '../../../routes/routes.dart';
import 'package:pinput/pinput.dart';
import '../../../helper/ui_helper.dart';
import '../../utils/constant.dart';
import '../../../widgets/my_elevated_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:intl/intl.dart';

enum BHLType { low, moderate, heavy }

class StartWorkView extends StatefulWidget {
  final Map<String, dynamic>? bookingData;

  const StartWorkView({super.key, this.bookingData});

  @override
  State<StartWorkView> createState() => _StartWorkViewState();
}

final PinTheme defaultPinTheme = PinTheme(
  width: 7.h,
  height: 7.h,
  textStyle: primaryMedium18,
  decoration: BoxDecoration(
    color: white,
    borderRadius: myBorderRadius(10),
    boxShadow: [boxShadow1],
  ),
  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
);

class _StartWorkViewState extends State<StartWorkView> {
  // Define the new primary color
  static const Color primary = Color(0xFF2ECC71);
  bool showStartOtpSection = false;
  bool showEndOtpSection = false;
  bool otpfromCust = false;
  bool otpStartTrip = false;
  bool otpEndTrip = false;
  int _rating = 0;
  TextEditingController _remarksController = TextEditingController();
  int totalSeconds = 0;
  bool isWorking = false;
  bool isPaused = false;
  String? loadWeight;
  String? unloadWeight;
  TextEditingController loadWeightController = TextEditingController();
  TextEditingController unloadWeightController = TextEditingController();
  bool isOtpVerified = false;
  String intensity = '';
  File? selectedImage;
  String? imageName;
  String _selectedPaymentMode = ''; // Default selection
  final List<String> _paymentModes = ['Cash On Site', 'Online'];
  bool _isOtpVerifiedStart = false;
  bool _isOtpVerifiedEnd = false;
  String? _startWorkImageUrl;
  String? _afterWorkImageUrl; // Add this at the top of your state class
  DateTime? _workStartTime;
  DateTime? _workPauseTime;
  Duration _totalWorkDuration = Duration.zero;
  Timer? _workTimer;
  final ImagePicker _picker = ImagePicker();
  late Razorpay _razorpay;
  bool _isProcessing = false;
  String? _razorpayKeyId;
  TextEditingController _tipController = TextEditingController();
  bool _isOtpGenerated = false;
  DateTime? _overallStartTime;
  DateTime? _overallEndTime;

  List<Map<String, DateTime>> _breaks = []; // Store start and end of each break
  Duration _totalBreakDuration = Duration.zero;
  bool isOnBreak = false;

  DateTime? _currentBreakStart; // To store current break start time

  bool _pickupConfirmed = false;
  bool _documentsCollected = false;
  bool _deliveryReached = false;
  bool _deliveryConfirmed = false;
  String _remarks = '';


  final Map<BHLType, double> _bhlHourlyRates = {
  BHLType.low: 25.0,
  BHLType.moderate: 35.0,
  BHLType.heavy: 50.0,
  };

  @override
  void initState() {
    super.initState();
    _loadBookingData();
    _fetchBhlRates();
    _loadExistingImage();
    _loadTripProgress();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _loadTripProgress() async {
    final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];

    final doc = await FirebaseFirestore.instance
        .collection('bhl_bookings')
        .doc(bookingId)
        .get();

    final tripProgress = doc.data()?['tripProgress'] ?? {};

    if (mounted) {
      setState(() {
        _pickupConfirmed = tripProgress['pickupConfirmed'] == true;
        _documentsCollected = tripProgress['documentsCollected'] == true;
        _deliveryReached = tripProgress['deliveryReached'] == true;
        _deliveryConfirmed = tripProgress['deliveryConfirmed'] == true;
        _remarks = tripProgress['remarks'] ?? '';
      });
    }
  }


  Future<void> _fetchBhlRates() async {
    try {
      debugPrint("Step 1: Starting _fetchBhlRates()");

      final query = FirebaseFirestore.instance
          .collection('vehicleOwnerCharges')
          .where('is_active', isEqualTo: true)
          .limit(1);

      debugPrint("Step 2: Built Firestore query");

      final docSnapshot = await query.get();

      debugPrint("Step 3: Query executed");

      if (docSnapshot.docs.isNotEmpty) {
        debugPrint(
            "Step 4: Found at least one active vehicleOwnerCharges document");

        final data = docSnapshot.docs.first.data();

        debugPrint("Step 5: Retrieved document data: $data");

        setState(() {
          _bhlHourlyRates[BHLType.low] =
              (data['bhl_low_per_hour'] ?? 25).toDouble();
          _bhlHourlyRates[BHLType.moderate] =
              (data['bhl_medium_per_hour'] ?? 35).toDouble();
          _bhlHourlyRates[BHLType.heavy] =
              (data['bhl_high_per_hour'] ?? 50).toDouble();
        });

        debugPrint("Step 6: State updated with BHL rates");
      } else {
        debugPrint("Step 4: No active vehicleOwnerCharges documents found");
      }
    } catch (e) {
      debugPrint("Error in _fetchBhlRates: $e");
    }
  }

  double _calculatePaymentAmount() {
    // Get the work intensity type
    BHLType intensityType;
    switch (intensity.toLowerCase()) {
      case 'heavy':
        intensityType = BHLType.heavy;
        break;
      case 'moderate':
        intensityType = BHLType.moderate;
        break;
      default:
        intensityType = BHLType.low;
    }

    // Get the hourly rate based on intensity
    final hourlyRate = _bhlHourlyRates[intensityType] ?? 25.0;

    // Calculate total hours (work duration in hours)
    final totalHours = _totalWorkDuration.inMinutes / 60.0;

    // Calculate total amount
    return totalHours * hourlyRate;
  }

  Future<void> _loadBookingData() async {
    final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
    if (bookingId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('bhl_bookings')
        .doc(bookingId)
        .get();

    if (doc.exists) {
      final data = doc.data();
      setState(() {
        intensity = data?['workIntensity'] ?? '';
        _startWorkImageUrl = data?['startworkImage'] ?? '';
        _afterWorkImageUrl = data?['afterworkImage'] ?? '';
        _selectedPaymentMode = data?['paymentMethod'] ?? '';
        _isOtpVerifiedStart = data?['startOtpVerified'] ?? false;
        _isOtpVerifiedEnd = data?['endOtpVerified'] ?? false;
        // final Timestamp? startTimestamp = data?['workStartedAt'];
        // if (startTimestamp != null) {
        //   _overallStartTime = startTimestamp.toDate();
        //   final now = DateTime.now();
        //   _totalWorkDuration = now.difference(_overallStartTime!);
        //
        //   // Optionally restart the timer to keep incrementing
        //   _startWorkTimer();
        // }
        final Timestamp? startTimestamp = data?['workStartedAt'];
        final Timestamp? endTimestamp = data?['workEndedAt'];

        if (startTimestamp != null) {
          _overallStartTime = startTimestamp.toDate();
          if (endTimestamp != null) {
            // Work has ended → calculate total once and stop
            _overallEndTime = endTimestamp.toDate();
            _totalWorkDuration = _overallEndTime!.difference(_overallStartTime!);
          } else {
            // Work still in progress → keep timer running
            final now = DateTime.now();
            _totalWorkDuration = now.difference(_overallStartTime!);
            _startWorkTimer();
          }
        }

      });
    }
  }

  StreamSubscription<Position>? _positionStream;

  void _startLiveLocationTracking(String bookingId) async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      debugPrint('[TRACKING] New position: ${position.latitude}, ${position.longitude}');

      await FirebaseFirestore.instance
          .collection('bhl_bookings')
          .doc(bookingId)
          .update({
        'captainLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
    });
  }

  void _stopLiveLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    debugPrint('[TRACKING] Live location tracking stopped');
  }

  Future<void> _sendCompletionNotifications() async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final now = DateTime.now();

      final bookingData = widget.bookingData;
      if (bookingData == null) return;

      final bookingId = bookingData['vehicleDetails']['currentBooking'] ?? '';
      final tripId = bookingData['tripId']?.toString() ?? '';
      final customerId = bookingData['customer']?['uid'];
      final ownerId = bookingData['ownerDetails']?['id'];
      final captainId = FirebaseAuth.instance.currentUser?.uid;
      final captainName = bookingData['captain']?['name'] ?? 'Captain';

      final batch = firestore.batch();

      // Customer notification
      if (customerId != null) {
        final ref = firestore.collection('customer_notifications').doc();
        batch.set(ref, {
          'userId': customerId,
          'type': 'payment_completed',
          'bookingId': bookingId,
          'title': 'Payment Received',
          'message': 'Your payment for trip $tripId has been collected by $captainName.',
          'createdAt': now,
          'read': false,
          'relatedUserId': captainId,
          'relatedUserType': 'captain',
        });
      }

      // Owner notification
      if (ownerId != null) {
        final ref = firestore.collection('owner_notifications').doc();
        batch.set(ref, {
          'userId': ownerId,
          'type': 'payment_completed',
          'bookingId': bookingId,
          'title': 'Trip Completed',
          'message': 'Trip $tripId completed and payment collected by $captainName.',
          'createdAt': now,
          'read': false,
          'relatedUserId': captainId,
          'relatedUserType': 'captain',
        });
      }

      // Captain notification
      if (captainId != null) {
        final ref = firestore.collection('captain_notifications').doc();
        batch.set(ref, {
          'userId': captainId,
          'type': 'payment_completed',
          'bookingId': bookingId,
          'title': 'Trip Completed',
          'message': 'You have successfully completed trip $tripId and collected the payment.',
          'createdAt': now,
          'read': false,
        });
      }

      await batch.commit();
      debugPrint('[NOTIFICATIONS] Payment completion notifications sent');
    } catch (e) {
      debugPrint('[NOTIFICATIONS ERROR] Failed to send notifications: $e');
    }
  }


  @override
  void dispose() {
    loadWeightController.dispose();
    unloadWeightController.dispose();
    _workTimer?.cancel();
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // Handle payment success
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment successful: ${response.paymentId}')),
    );
    _handleOnlinePaymentCompletion();
    // ✅ Show trip complete dialog here
    UiHelper.showTripCompletedDialog(context);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.code} - ${response.message}')),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet: ${response.walletName}')),
    );
  }

  void _openRazorpayPayment() async {
    final tip = double.tryParse(_tipController.text.trim()) ?? 0.0;
    var fare = _calculatePaymentAmount(); // Use calculated amount instead of fixed fare
    fare += tip;

    final settingsQuery = await FirebaseFirestore.instance
        .collection('settings')
        .where('razorpayKeyId', isNotEqualTo: null)
        .limit(1)
        .get();

    if (settingsQuery.docs.isEmpty) {
      throw Exception('No settings document with razorpayKey found');
    }

    final razorpayKey = settingsQuery.docs.first.data()['razorpayKeyId'] as String?;

    if (razorpayKey == null || razorpayKey.isEmpty) {
      throw Exception('Razorpay key is empty in settings');
    }

    // Get customer details from booking data
    final customerName = widget.bookingData?['customerDetails']?['name']?.toString() ?? '';
    final customerMobile = widget.bookingData?['customerDetails']?['mobile']?.toString() ?? '';

    var options = {
      'key': razorpayKey,
      'amount': (fare * 100).toInt(), // Amount in paise
      'name': 'Vandizone',
      'description': 'Payment for BHL work',
      'prefill': {
        'name': customerName,
        'email': customerMobile
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Captain Duty - Action Panel'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Banner
            Container(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: primary, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Work Mode - Backhoe Loader',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
              // Backhoe Loader specific content
              _buildWorkIntensitySection(),
              SizedBox(height: 24),
              _buildBeforeWorkSection(),
              SizedBox(height: 24),
              if (_isOtpVerifiedStart==true) ...[
                SizedBox(height: 24),
                _buildDuringWorkSection(),
              ],
              SizedBox(height: 24),
              _buildAfterWorkSection(),
          ],
        ),
      ),
    );
  }

  Future<void> sendCustomerBookingNotification({
    required String collection,
    required String bookingCode,
    required String eventType,
    required String title,
    required String body,
  }) async {
    try {
      debugPrint("[NOTIFICATION] Preparing to send $eventType notification for booking $bookingCode");

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("[NOTIFICATION] ❌ Failed - User not authenticated");
        throw Exception("Not authenticated");
      }

      final idToken = await user.getIdToken();
      debugPrint("[NOTIFICATION] Retrieved user ID token");

      final uri = Uri.parse("https://us-central1-vandizone-admin.cloudfunctions.net/sendCustomCustomerNotification");
      debugPrint("[NOTIFICATION] Target URL: $uri");

      final payload = jsonEncode({
        'collection': collection,
        'bookingCode': bookingCode,
        'eventType': eventType,
        'title': title,
        'body': body,
      });
      debugPrint("[NOTIFICATION] Payload: $payload");

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: payload,
      );

      if (response.statusCode == 200) {
        debugPrint("[NOTIFICATION] ✅ Successfully sent $eventType notification");
        debugPrint("[NOTIFICATION] Response: ${response.body}");
      } else {
        debugPrint("[NOTIFICATION] ❌ Failed with status ${response.statusCode}");
        debugPrint("[NOTIFICATION] Error response: ${response.body}");
      }
    } catch (e) {
      debugPrint("[NOTIFICATION] ❌ Exception occurred: $e");
      rethrow;
    }
  }

  Widget _buildWorkIntensitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WORK INTENSITY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            _buildIntensityButton('Light'),
            _buildIntensityButton('Moderate'),
            _buildIntensityButton('Heavy'),
          ],
        ),
      ],
    );
  }

  Widget _buildIntensityButton(String level) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: intensity == level
            ? Colors.orange  // Selected color
            : Colors.grey.shade300, // Unselected color
        foregroundColor: intensity == level
            ? Colors.white
            : Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      onPressed: () {
        if (intensity != level) {
          _showIntensityChangeDialog(level);
        }
      },

      child: Text(level),
    );
  }

  Widget _buildBeforeWorkSection() {
    final bool isPhotoUploaded = _startWorkImageUrl != null && _startWorkImageUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BEFORE WORK',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.5
            )),
        SizedBox(height: 8),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Before Work Photo',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14
                              )),
                          // SizedBox(height: 4),
                          // Text('(Optional)',
                          //     style: TextStyle(
                          //         fontSize: 12,
                          //         color: Colors.grey.shade600
                          //     )),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: pickImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primary,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: primary),
                        ),
                      ),
                      child: Text('Take Photo'),
                    ),
                  ],
                ),
                if (isPhotoUploaded)
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(_startWorkImageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                // If photo is selected locally (preview before upload)
                if (selectedImage != null)
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(selectedImage!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isOtpVerifiedStart
                    ? null
                    : () async {
                  debugPrint('[DEBUG] Button pressed');

                  // Always show bottom sheet first
                  _showOtpBottomSheet(context);

                  // Generate OTP only if not done before
                  if (!_isOtpGenerated) {
                    try {
                      debugPrint('[DEBUG] First time OTP generation starting');
                      _stopLiveLocationTracking();
                      _startLiveLocationTracking(
                          widget.bookingData?['vehicleDetails']['currentBooking']);
                      await generateOtpForUserByCaptain(
                          widget.bookingData!['customer']['uid']);
                      debugPrint('[DEBUG] OTP generated successfully');
                      _isOtpGenerated = true; // Prevent further generation
                    } catch (e, stackTrace) {
                      debugPrint('[ERROR] Exception in OTP generation: $e');
                      debugPrint('[ERROR] Stack trace: $stackTrace');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                          Text('Failed to generate OTP: ${e.toString()}'),
                        ),
                      );
                    }
                  } else {
                    debugPrint('[DEBUG] OTP already generated, skipping generation');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Get OTP from Customer to Start',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            // SizedBox(
            //   width: double.infinity,
            //   child: ElevatedButton(
            //     onPressed: _isOtpVerifiedStart
            //         ? null
            //         : () async {
            //       debugPrint('[DEBUG] Button pressed - starting OTP flow');
            //       try {
            //         _stopLiveLocationTracking();
            //         _startLiveLocationTracking(widget.bookingData?['vehicleDetails']['currentBooking']);
            //         // _startLiveLocationTracking(widget.bookingData?['bookingCode']);
            //         debugPrint('[DEBUG] Calling generateOtpForUserByCaptain');
            //         await generateOtpForUserByCaptain(widget.bookingData!['customer']['uid']);
            //         debugPrint('[DEBUG] OTP generation completed, showing bottom sheet');
            //         _showOtpBottomSheet(context);
            //       } catch (e, stackTrace) {
            //         debugPrint('[ERROR] Exception in button handler: $e');
            //         debugPrint('[ERROR] Stack trace: $stackTrace');
            //         ScaffoldMessenger.of(context).showSnackBar(
            //             SnackBar(content: Text('Failed to generate OTP: ${e.toString()}'))
            //         );
            //       }
            //     },
            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: primary,
            //       padding: EdgeInsets.symmetric(vertical: 16),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(10),
            //       ),
            //     ),
            //     child: Text('Get OTP from Customer to Start',
            //         style: TextStyle(
            //             color: Colors.white,
            //             fontWeight: FontWeight.w600
            //         )),
            //   ),
            // ),
          ],
        ),
      ],
    );
  }

  Widget _buildDuringWorkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DURING WORK',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.5)),
        SizedBox(height: 8),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                if (_overallEndTime == null) ...[
                  // Show controls only if work hasn't ended
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildControlButton(
                        icon: Icons.play_arrow,
                        label: isOnBreak ? 'Resume' : 'Start',
                        color: Colors.green,
                        onPressed: () {
                          if (!isWorking) {
                            _startWorkTimer();
                          } else if (isOnBreak) {
                            _resumeWork();
                          }
                        },
                      ),
                      _buildControlButton(
                        icon: Icons.pause,
                        label: 'Break',
                        color: Colors.orange,
                        onPressed: isWorking && !isOnBreak ? () => _pauseWork() : null,
                      ),
                      _buildControlButton(
                        icon: Icons.stop,
                        label: 'Stop',
                        color: Colors.red,
                        onPressed: (isWorking && !isOnBreak && _currentBreakStart == null)
                            ? () => _stopWorkAndSave()
                            : null,
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],

                // Always show the summary
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_overallStartTime != null)
                        _buildSummaryRow('Start Time:',
                            DateFormat('hh:mm a').format(_overallStartTime!)),
                      if (_overallEndTime != null)
                        _buildSummaryRow('End Time:',
                            DateFormat('hh:mm a').format(_overallEndTime!)),
                      _buildSummaryRow('Work Time:', _formatDuration(_totalWorkDuration)),
                      _buildSummaryRow('Break Time:', _formatDuration(_totalBreakDuration)),
                      _buildSummaryRow('Break Count:', _breaks.length.toString()),
                    ],
                  ),
                ),

                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined,
                          color: Colors.grey.shade700, size: 20),
                      SizedBox(width: 8),
                      Text('Total Time Recorded:',
                          style: TextStyle(color: Colors.grey.shade700)),
                      SizedBox(width: 8),
                      Text(_formatDuration(_totalWorkDuration),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAfterWorkSection() {
    final bool isPhotoUploaded = _afterWorkImageUrl != null && _afterWorkImageUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AFTER WORK',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.5
            )),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: white,
            boxShadow: [boxShadow1],
            borderRadius: myBorderRadius(10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text('After Work Photo', style: blackRegular16),
                  Spacer(),
                  ElevatedButton(
                    onPressed: isPhotoUploaded ? null : pickAfterWorkImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primary,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: primary,
                        ),
                      ),
                    ),
                    child: Text('Take Photo'),
                  ),
                ],
              ),
              if (isPhotoUploaded)
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(_afterWorkImageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              // If photo is selected locally (preview before upload)
              if (selectedImage != null)
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(selectedImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isOtpVerifiedEnd
                      ? null
                      : () async{
                    await generateOtpForUserByCaptain(widget.bookingData!['customer']['uid']);
                    _showEndOtpBottomSheet(context);
                    _stopLiveLocationTracking();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Get OTP Confirm Work Done',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600
                      )),
                ),
              ),
              SizedBox(height: 20),
              // Inside _buildAfterWorkSection(), add this before the payment buttons:
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Work Time:', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(_formatDuration(_totalWorkDuration)),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Calculated Amount:', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('₹${_calculatePaymentAmount().toStringAsFixed(2)}'),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _showRatingDialog(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: primary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Rate Customer',
                          style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w600
                          )),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _showPaymentModeBottomSheet(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Confirm Payment',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600
                          )),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showIntensityChangeDialog(String newIntensity) {
    if (_startWorkImageUrl != null && _startWorkImageUrl!.isNotEmpty) {
      _showErrorSnackbar('Work intensity cannot be changed after uploading before work photo');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: white,
        shape: RoundedRectangleBorder(borderRadius: myBorderRadius(10)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Change Work Intensity", style: blackSemiBold20),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Icon(Icons.work_outline, size: 60, color: Colors.orange),
            ),
            Text(
              "Are you sure you want to change work intensity?",
              textAlign: TextAlign.center,
              style: colorABMedium18,
            ),
            Gap(25),
            Row(
              children: [
                Expanded(
                  child: MyElevatedButton(
                    isSecondary: true,
                    title: "Cancel",
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Gap(20),
                Expanded(
                  child: MyElevatedButton(
                    title: "Confirm",
                    onPressed: () {
                      Navigator.pop(context);
                      _updateWorkIntensity(newIntensity);
                    },
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _updateWorkIntensity(String newIntensity) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final bookingId = widget.bookingData!['vehicleDetails']['currentBooking'] ?? "";
      if (bookingId.isEmpty) {
        throw Exception('Booking ID not found');
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('bhl_bookings')
          .doc(bookingId)
          .update({
        'workIntensity': newIntensity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await sendCustomerBookingNotification(
        collection: 'bhl_bookings',
        bookingCode: bookingId,
        eventType: 'booking_started',
        title: 'Work Intensity',
        body: 'Captain updated the Work Intensity.',
      );

      // Update local state
      setState(() {
        intensity = newIntensity;
      });

      // Dismiss loading dialog first
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Work intensity updated successfully!')),
      );

      // Reload data
      _loadBookingData();

    } catch (e) {
      // Dismiss loading dialog on error
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update work intensity: ${e.toString()}')),
      );
    }
  }

  Future<void> generateOtpForUserByCaptain(String userId) async {
    debugPrint('[DEBUG] Starting OTP generation process for user: $userId');

    try {
      // Step 1: Get current authenticated user
      final captain = FirebaseAuth.instance.currentUser;
      debugPrint('[DEBUG] Current captain user: ${captain?.uid ?? "null"}');

      if (captain == null) {
        debugPrint('[ERROR] No authenticated captain user found');
        throw Exception("Not authenticated");
      }

      // Step 2: Get ID token
      debugPrint('[DEBUG] Getting ID token...');
      final idToken = await captain.getIdToken();
      debugPrint('[DEBUG] Successfully obtained ID token');

      // Step 3: Prepare request
      final url = "https://us-central1-vandizone-admin.cloudfunctions.net/sendOtpToUser";
      debugPrint('[DEBUG] Preparing POST request to: $url');
      debugPrint('[DEBUG] Request payload: {"userId": "$userId"}');

      // Step 4: Send request
      debugPrint('[DEBUG] Sending OTP generation request...');
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"userId": userId}),
      );

      // Step 5: Handle response
      debugPrint('[DEBUG] Received response with status code: ${response.statusCode}');
      debugPrint('[DEBUG] Response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('[DEBUG] OTP successfully sent to user');
      } else {
        debugPrint('[ERROR] Failed to generate OTP. Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception("Failed to generate OTP: ${response.body}");
      }
    } catch (e) {
      debugPrint('[ERROR] Exception in generateOtpForUserByCaptain: $e');
      debugPrint('[ERROR] Stack trace: ${e is Error ? (e as Error).stackTrace : ''}');
      rethrow; // Re-throw to let the caller handle it
    }
  }

  Future<void> verifyUserOtpByCaptainStart(String userId, String otp) async {
    print('[OTP VERIFICATION] Starting OTP verification process');
    print('[OTP VERIFICATION] User ID: $userId');
    print('[OTP VERIFICATION] OTP received: $otp'); // Printing the OTP value

    try {
      print('[OTP VERIFICATION] Step 1: Checking captain authentication');
      final captain = FirebaseAuth.instance.currentUser;
      if (captain == null) {
        print('[OTP VERIFICATION ERROR] No authenticated captain user found');
        throw Exception("Not authenticated");
      }
      print('[OTP VERIFICATION] Captain UID: ${captain.uid}');

      print('[OTP VERIFICATION] Step 2: Getting captain ID token');
      final idToken = await captain.getIdToken();
      print('[OTP VERIFICATION] Successfully obtained ID token');

      final url = "https://us-central1-vandizone-admin.cloudfunctions.net/verifyOtpForUser";
      print('[OTP VERIFICATION] Step 3: Preparing request to URL: $url');
      print('[OTP VERIFICATION] Request payload: {"otp": "$otp"}');

      print('[OTP VERIFICATION] Step 4: Sending verification request...');
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $idToken", // Fixed: Using idToken instead of userId
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId, // Added userId to request body
          "otp": otp,
        }),
      );

      if (response.statusCode == 200) {
        final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
        if (bookingId != null) {
          await FirebaseFirestore.instance
              .collection('bhl_bookings')
              .doc(bookingId)
              .update({
            'startOtpVerified': true,
          });
        }
        debugPrint("[NOTIFICATION] Sending booking started notification");
        await sendCustomerBookingNotification(
          collection: 'bhl_bookings',
          bookingCode: bookingId ?? '',
          eventType: 'booking_started',
          title: 'Work Started',
          body: 'Captain has started your work.',
        );
        debugPrint("[NOTIFICATION] Booking started notification sent");
        _loadBookingData();
        _verify(context);
      } else {
        throw Exception("Invalid OTP: ${response.body}");
      }
    } catch (e) {
      rethrow;
    } finally {
      print('[OTP VERIFICATION] Verification process completed');
    }
  }

  Future<void> verifyUserOtpByCaptainEnd(String userId, String otp) async {
    print('[OTP VERIFICATION] Starting OTP verification process');
    print('[OTP VERIFICATION] User ID: $userId');
    print('[OTP VERIFICATION] OTP received: $otp'); // Printing the OTP value

    try {
      print('[OTP VERIFICATION] Step 1: Checking captain authentication');
      final captain = FirebaseAuth.instance.currentUser;
      if (captain == null) {
        print('[OTP VERIFICATION ERROR] No authenticated captain user found');
        throw Exception("Not authenticated");
      }
      print('[OTP VERIFICATION] Captain UID: ${captain.uid}');

      print('[OTP VERIFICATION] Step 2: Getting captain ID token');
      final idToken = await captain.getIdToken();
      print('[OTP VERIFICATION] Successfully obtained ID token');
      // Note: For security, don't print the actual token - just confirm we got it

      final url = "https://us-central1-vandizone-admin.cloudfunctions.net/verifyOtpForUser";
      print('[OTP VERIFICATION] Step 3: Preparing request to URL: $url');
      print('[OTP VERIFICATION] Request payload: {"otp": "$otp"}');

      print('[OTP VERIFICATION] Step 4: Sending verification request...');
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $idToken", // Fixed: Using idToken instead of userId
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId, // Added userId to request body
          "otp": otp,
        }),
      );

      if (response.statusCode == 200) {
        final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
        if (bookingId != null) {
          await FirebaseFirestore.instance
              .collection('bhl_bookings')
              .doc(bookingId)
              .update({
            'endOtpVerified': true,
          });
        }
        await sendCustomerBookingNotification(
          collection: 'bhl_bookings',
          bookingCode: bookingId ?? '',
          eventType: 'booking_ended',
          title: 'Work Ended',
          body: 'Captain Finished your work. Proceed with your payment',
        );
        _loadBookingData();
        _verify(context);
      } else {
        throw Exception("Invalid OTP: ${response.body}");
      }
    } catch (e) {
      rethrow;
    } finally {
      print('[OTP VERIFICATION] Verification process completed');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _startWorkTimer() {
    if (_workTimer != null && _workTimer!.isActive) return; // prevent duplicate timers

    if (_overallStartTime == null) {
      _overallStartTime = DateTime.now();

      final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
      if (bookingId != null) {
        FirebaseFirestore.instance.collection('bhl_bookings').doc(bookingId).update({
          'workStartedAt': _overallStartTime,
        });
      }
    }

    setState(() {
      isWorking = true;
      isOnBreak = false;
    });

    _workTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (isWorking && !isOnBreak) {
        setState(() {
          _totalWorkDuration += Duration(seconds: 1);
        });
      }
    });
  }

  // void _pauseWorkTimer() {
  //   debugPrint('[WORK TIMER] Pausing work timer');
  //   setState(() {
  //     _workPauseTime = DateTime.now();
  //     isPaused = true;
  //   });
  //
  //   // Log work pause to Firestore
  //   _logWorkEvent('work_paused');
  // }

  void _resumeWork() {
    if (isOnBreak && _currentBreakStart != null) {
      final now = DateTime.now();
      final breakDuration = now.difference(_currentBreakStart!);

      setState(() {
        _breaks.add({
          'start': _currentBreakStart!,
          'end': now,
        });
        _totalBreakDuration += breakDuration;
        _currentBreakStart = null;
        isOnBreak = false;
      });
    }
  }


  void _pauseWork() {
    if (isWorking && !isOnBreak && _currentBreakStart == null) {
      setState(() {
        isOnBreak = true;
        _currentBreakStart = DateTime.now();
      });
    }
  }

  void _showWorkSummaryDialog(BuildContext context, Map<String, dynamic> workLog) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Work Summary'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryRow('Start Time:',
                  DateFormat('hh:mm a').format(workLog['workStartedAt'])),
              _buildSummaryRow('End Time:',
                  DateFormat('hh:mm a').format(workLog['workEndedAt'])),
              _buildSummaryRow('Total Session:',
                  _formatDuration(Duration(minutes: workLog['totalSessionDurationMinutes']))),
              _buildSummaryRow('Work Time:',
                  _formatDuration(Duration(minutes: workLog['totalWorkDurationMinutes']))),
              _buildSummaryRow('Break Time:',
                  _formatDuration(Duration(minutes: workLog['totalBreakDurationMinutes']))),
              _buildSummaryRow('Number of Breaks:',
                  workLog['numberOfBreaks'].toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );

    // Update UI state without clearing data
    setState(() {
      isWorking = false;
      isOnBreak = false;
      _workTimer = null;
    });
  }

  void _stopWorkAndSave() async {
    // _workTimer?.cancel();
    setState(() {
      _workTimer?.cancel(); // Stop the periodic timer
      _overallEndTime = DateTime.now(); // Final end time
      isWorking = false;
      isOnBreak = false;
    });
    if (isOnBreak) _resumeWork(); // End break if active

    // _overallEndTime = DateTime.now();
    final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
    if (bookingId == null) return;

    final totalSessionDuration = _overallEndTime!.difference(_overallStartTime!);

    final workLog = {
      'workStartedAt': _overallStartTime,
      'workEndedAt': _overallEndTime,
      'totalSessionDurationMinutes': totalSessionDuration.inMinutes,
      'totalWorkDurationMinutes': _totalWorkDuration.inMinutes,
      'totalBreakDurationMinutes': _totalBreakDuration.inMinutes,
      'numberOfBreaks': _breaks.length,
      'breaks': _breaks.map((b) => {
        'start': b['start'],
        'end': b['end'],
        'durationMinutes': b['end']!.difference(b['start']!).inMinutes,
      }).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('bhl_bookings')
        .doc(bookingId)
        .update({'workSessionSummary': workLog});

    debugPrint("✅ Work session summary saved");

    // Show summary dialog instead of resetting
    _showWorkSummaryDialog(context, workLog);
  }


  void _stopWork() {
    _workTimer?.cancel();
    _overallEndTime = DateTime.now();

    if (isOnBreak) {
      _resumeWork(); // Close last break if still on break
    }

    final totalSession = _overallEndTime!.difference(_overallStartTime!);
    final finalWork = _totalWorkDuration;
    final finalBreak = _totalBreakDuration;

    debugPrint("🔚 Work ended at $_overallEndTime");
    debugPrint("🕒 Total Session: ${_formatDuration(totalSession)}");
    debugPrint("🛠️  Work Time: ${_formatDuration(finalWork)}");
    debugPrint("☕ Break Time: ${_formatDuration(finalBreak)}");
    debugPrint("🔁 Break Count: ${_breaks.length}");

    // Optionally store to Firestore here...

    setState(() {
      isWorking = false;
      isOnBreak = false;
    });
  }


  void _stopWorkTimer() {
    debugPrint('[WORK TIMER] Stopping work timer');
    _workTimer?.cancel();

    final endTime = DateTime.now();
    final totalDuration = _totalWorkDuration;
    final startTime = _workStartTime; // ✅ Store locally BEFORE clearing

    // Log work completion to Firestore
    _logWorkEvent(
      'work_completed',
      startTime: startTime, // ✅ Send the preserved startTime
      endTime: endTime,
      totalDuration: totalDuration,
    );

    // Now reset state after logging
    setState(() {
      isWorking = false;
      isPaused = false;
      _totalWorkDuration = Duration.zero;
      _workStartTime = null;
      _workPauseTime = null;
    });
  }

  Future<void> _logWorkEvent(
      String eventType, {
        DateTime? startTime,
        DateTime? endTime,
        Duration? totalDuration,
      }) async {
    try {
      final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
      if (bookingId == null) {
        debugPrint('[FIREBASE ERROR] No booking ID found');
        return;
      }

      // Update only the booking document
      if (eventType == 'work_completed') {
        await FirebaseFirestore.instance
            .collection('bhl_bookings')
            .doc(bookingId)
            .update({
          'workSessions': FieldValue.arrayUnion([
            {
              'start': Timestamp.fromDate(startTime!),
              'end': Timestamp.fromDate(endTime!),
            }
          ]),
          'totalWorkMinutes': totalDuration?.inMinutes,
        });

        debugPrint('[FIREBASE] Booking updated with new work session.');
      }

      debugPrint('[FIREBASE] Successfully logged work event: $eventType');
    } catch (e) {
      debugPrint('[FIREBASE ERROR] Failed to log work event: $e');
    }
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed, // ✅ Allow nullable
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: color),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500
            )),
      ],
    );
  }

  void _showEndOtpBottomSheet(BuildContext context) {
    final endOtpController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Enter OTP to confirm work done',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                InkWell(
                  onTap: () async {
                    print("📞 Call button pressed");

                    final user = FirebaseAuth.instance.currentUser;
                    final idToken = await user?.getIdToken();
                    print("🔐 Firebase ID Token: ${idToken != null ? 'Retrieved' : 'Null'}");

                    final customerId = widget.bookingData?['customer']?['uid'];
                    final captainName = widget.bookingData?['captainDetails']?['name'];
                    final bookingCode = widget.bookingData?['bookingCode'];
                    final channelName = getChannelName(bookingCode);

                    print("📦 Data:");
                    print("- customerId: $customerId");
                    print("- captainName: $captainName");
                    print("- bookingCode: $bookingCode");
                    print("- channelName: $channelName");

                    if (idToken != null && customerId != null) {
                      print("🚀 Sending call notification...");
                      await sendCustomerCallNotification(
                        customerId: customerId,
                        bookingCode: bookingCode,
                        captainName: captainName,
                        channelName: channelName,
                        idToken: idToken,
                      );
                      print("✅ Notification function called");
                    } else {
                      print("❌ Missing required data. Notification not sent.");
                    }

                    print("📞 Navigating to VoiceCallScreen");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VoiceCallScreen(
                          isCaller: true,
                          initialChannel: channelName,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withOpacity(0.1),
                    ),
                    child: Icon(Icons.phone, color: Colors.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Pinput(
              length: 4,
              controller: endOtpController,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: defaultPinTheme,
              submittedPinTheme: defaultPinTheme,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final otp = endOtpController.text;
                  if (otp.length != 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a 4-digit OTP')),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  verifyUserOtpByCaptainEnd(widget.bookingData!['customer']['uid'], otp);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Verify OTP',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  String getChannelName(String bookingCode) => "call_channel_$bookingCode";

  void _showOtpBottomSheet(BuildContext context) {
    final otpController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Enter OTP from Customer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                InkWell(
                  onTap: () async {
                    print("📞 Call button pressed");

                    final user = FirebaseAuth.instance.currentUser;
                    final idToken = await user?.getIdToken();
                    print("🔐 Firebase ID Token: ${idToken != null ? 'Retrieved' : 'Null'}");

                    final customerId = widget.bookingData?['customer']?['uid'];
                    final captainName = widget.bookingData?['captainDetails']?['name'];
                    final bookingCode = widget.bookingData?['bookingCode'];
                    final channelName = getChannelName(bookingCode);

                    print("📦 Data:");
                    print("- customerId: $customerId");
                    print("- captainName: $captainName");
                    print("- bookingCode: $bookingCode");
                    print("- channelName: $channelName");

                    if (idToken != null && customerId != null) {
                      print("🚀 Sending call notification...");
                      await sendCustomerCallNotification(
                        customerId: customerId,
                        bookingCode: bookingCode,
                        captainName: captainName,
                        channelName: channelName,
                        idToken: idToken,
                      );
                      print("✅ Notification function called");
                    } else {
                      print("❌ Missing required data. Notification not sent.");
                    }

                    print("📞 Navigating to VoiceCallScreen");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VoiceCallScreen(
                          isCaller: true,
                          initialChannel: channelName,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withOpacity(0.1),
                    ),
                    child: Icon(Icons.phone, color: Colors.green),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Pinput(
              length: 4,
              controller: otpController,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: defaultPinTheme,
              submittedPinTheme: defaultPinTheme,
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final otp = otpController.text;
                  if (otp.length != 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a 4-digit OTP')),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  verifyUserOtpByCaptainStart(widget.bookingData!['customer']['uid'], otp);

                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Verify OTP',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Future<void> sendCustomerCallNotification({
    required String customerId,
    required String bookingCode,
    required String captainName,
    required String channelName,
    required String idToken,
  }) async {
    final uri = Uri.parse(
      "https://us-central1-vandizone-admin.cloudfunctions.net/sendCustomerCallNotification",
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'customerId': customerId,
        'bookingCode': bookingCode,
        'captainName': captainName,
        'channelName': channelName,
      }),
    );

    if (response.statusCode == 200) {
      print("✅ Notification sent to customer.");
    } else {
      print("❌ Failed to send notification: ${response.body}");
    }
  }

// Reusable button widgets
  Widget _buildPrimaryButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          )),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlineButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: primary),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelWithTextField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hintText,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  void _verify(BuildContext context) {
    setState(() {
      isOtpVerified = true; // This will trigger UI to show during work section
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OTP verified successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Rate Customer',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold
                      )),
                  SizedBox(height: 20),

                  // Star Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          size: 40,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() {
                            _rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  SizedBox(height: 20),

                  // Remarks
                  MyTextfield(
                    controller: _remarksController,
                    header: "Review",
                    maxLines: 3,
                  ),
                  SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      minimumSize: Size(double.infinity, 50),
                    ),
                      onPressed: () async {
                        if (_rating > 0) {
                          final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
                          if (bookingId != null) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('bhl_bookings')
                                  .doc(bookingId)
                                  .update({
                                'customerRating': _rating,
                                'customerReview': _remarksController.text.trim(),
                              });

                              Navigator.pop(context); // Close rating bottom sheet

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Rating submitted successfully!')),
                              );

                              // ✅ Don't call `UiHelper.showTripCompletedDialog(context);` here
                              // ✅ Let the dialog be called only after payment completion
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to submit rating: $e')),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Booking ID not found')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Please select a rating')),
                          );
                        }
                      },
                      child: Text('Submit Rating',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16
                        )),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // void _showPaymentModeBottomSheet(BuildContext context) {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (context) {
  //       return StatefulBuilder(
  //         builder: (BuildContext context, StateSetter setState) {
  //           return Padding(
  //             padding: const EdgeInsets.all(20.0),
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   'Select Payment Mode',
  //                   style: TextStyle(
  //                       fontSize: 18, fontWeight: FontWeight.bold),
  //                 ),
  //                 SizedBox(height: 20),
  //
  //                 TextField(
  //                   controller: _tipController,
  //                   keyboardType:
  //                   TextInputType.numberWithOptions(decimal: true),
  //                   decoration: InputDecoration(
  //                     labelText: 'Optional Tip Amount (₹)',
  //                     border: OutlineInputBorder(),
  //                   ),
  //                 ),
  //                 SizedBox(height: 16),
  //
  //                 // Radio buttons for payment modes
  //                 Column(
  //                   children: _paymentModes.map((mode) {
  //                     return RadioListTile<String>(
  //                       title: Text(mode),
  //                       value: mode,
  //                       groupValue: _selectedPaymentMode,
  //                       onChanged: (String? value) {
  //                         setState(() {
  //                           _selectedPaymentMode = value!;
  //                         });
  //                       },
  //                       contentPadding: EdgeInsets.zero,
  //                     );
  //                   }).toList(),
  //                 ),
  //                 SizedBox(height: 20),
  //
  //                 // ⚠️ Note for cash payments
  //                 if (_selectedPaymentMode == 'Cash On Site') ...[
  //                   Text(
  //                     'Note: Vandizone is not responsible for any money collected as cash.',
  //                     style: TextStyle(
  //                       fontSize: 13,
  //                       color: Colors.grey[600],
  //                     ),
  //                   ),
  //                   SizedBox(height: 12),
  //                 ],
  //
  //                 ElevatedButton(
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: primary,
  //                     minimumSize: Size(double.infinity, 50),
  //                   ),
  //                   onPressed: () async {
  //                     if (_selectedPaymentMode == 'Cash On Site') {
  //                       // await _handlePaymentAndCommission();
  //                       await _handlePaymentAndCommission();
  //                       Navigator.pop(context); // Close bottom sheet
  //                       UiHelper.showTripCompletedDialog(context);
  //
  //                     } else {
  //                       Navigator.pop(context); // Close the bottom sheet first
  //                       _handleOnlinePaymentCompletion(); // Then open Razorpay
  //                     }
  //                   },
  //                   child: Text(
  //                     _selectedPaymentMode == 'Cash On Site'
  //                         ? 'Confirm Payment'
  //                         : 'Confirm Payment',
  //                     style: TextStyle(color: Colors.white, fontSize: 16),
  //                   ),
  //                 ),
  //                 SizedBox(height: 10),
  //               ],
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }


  Future<void> pickImage() async {
    try {
      // Open camera
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 88,
      );

      if (image == null) return;

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploading image...')),
      );

      // Get reference to Firebase Storage
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('images/${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Upload the file
      final UploadTask uploadTask = storageRef.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update state with the new image URL
      setState(() {
        _startWorkImageUrl = downloadUrl;
      });

      // Store in Firestore
      final bookingId = widget.bookingData!['vehicleDetails']['currentBooking'];
      if (bookingId != null) {
        await FirebaseFirestore.instance
            .collection('bhl_bookings')
            .doc(bookingId)
            .update({
          'startworkImage': downloadUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Show success message
      _showSuccessSnackbar('Image uploaded successfully');
      _loadExistingImage();
      await sendCustomerBookingNotification(
        collection: 'bhl_bookings', // 👈 If always truck, change to 'truck_bookings'
        bookingCode: bookingId,
        eventType: 'booking_started',
        title: 'Reached Site',
        body: 'Captain has reached the site.',
      );
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload photo: $e')),
      );
    }
  }

  Future<void> pickAfterWorkImage() async {
    try {
      // Open camera
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 88,
      );

      if (image == null) return;

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploading after work image...')),
      );

      // Get reference to Firebase Storage
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('afterwork_images/${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Upload the file
      final UploadTask uploadTask = storageRef.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Optionally store in a separate variable
      setState(() {
        // You can use a new variable if needed: _afterWorkImageUrl = downloadUrl;
      });

      // Store in Firestore under "afterworkImage"
      final bookingId = widget.bookingData!['vehicleDetails']['currentBooking'];
      if (bookingId != null) {
        await FirebaseFirestore.instance
            .collection('bhl_bookings')
            .doc(bookingId)
            .update({
          'afterworkImage': downloadUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Show success message
      _showSuccessSnackbar('After work image uploaded successfully');
      _loadExistingImage(); // Optional: reload image if you want to preview it
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload after work photo: $e')),
      );
    }
  }

  Future<void> _loadExistingImage() async {
    try {
      final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
      if (bookingId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('bhl_bookings')
            .doc(bookingId)
            .get();

        if (doc.exists && doc.data()?['startworkImage'] != null) {
          setState(() {
            _startWorkImageUrl = doc.data()?['startworkImage'];
          });
        }
      }
    } catch (e) {
      print('Error loading existing image: $e');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: white), // Use your white color constant
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: myBorderRadius(10), // Use your existing border radius utility
        ),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: white), // Use your white color constant
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: myBorderRadius(10), // Use your existing border radius utility
        ),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _handlePaymentAndCommission() async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      if (widget.bookingData == null || widget.bookingData!['ownerDetails'] == null) {
        throw Exception("Invalid booking data");
      }

      final userCode = widget.bookingData!['ownerDetails']['userCode']?.toString() ?? '';
      if (userCode.isEmpty) {
        throw Exception("Owner user code not found");
      }

      final tip = double.tryParse(_tipController.text.trim()) ?? 0.0;
      final fare = _calculatePaymentAmount(); // Use calculated amount
      final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];

      if (bookingId == null) {
        throw Exception("Booking or vehicle reference not found");
      }

      final settingsQuery = await firestore.collection('settings')
          .where('vandizoneCommission', isNotEqualTo: null)
          .limit(1)
          .get();

      if (settingsQuery.docs.isEmpty) {
        throw Exception("No settings document with 'vandizoneCommission' field found");
      }

      final settingsDoc = settingsQuery.docs.first;
      final vandizoneCommissionPercent = (settingsDoc.data()!['vandizoneCommission'] as num?)?.toDouble() ?? 0.0;
      if (vandizoneCommissionPercent <= 0) {
        throw Exception("Commission percentage is not set or invalid");
      }

      // 2. Calculate commission amount
      final double commissionAmount = (fare * vandizoneCommissionPercent) / 100;

      // 3. Find owner document by userCode to get ownerId
      final ownerQuery = await firestore.collection('owners')
          .where('userCode', isEqualTo: userCode)
          .limit(1)
          .get();

      if (ownerQuery.docs.isEmpty) {
        throw Exception("Owner with userCode '$userCode' not found");
      }
      final ownerId = ownerQuery.docs.first.id;

      // 4. Get current wallet balance
      final ownerWalletRef = firestore.collection('owner_wallets').doc(ownerId);
      final ownerWalletSnap = await ownerWalletRef.get();
      if (!ownerWalletSnap.exists) {
        throw Exception("Wallet not found for owner $ownerId");
      }

      final currentBalance = (ownerWalletSnap.data()!['balance'] as num?)?.toDouble() ?? 0.0;

      // 5. Deduct commission from balance (allow negative)
      final newBalance = currentBalance - commissionAmount;
// Optionally log a warning if balance goes negative
      if (newBalance < 0) {
        debugPrint("[WARNING] Wallet balance will go negative. Current: ₹$currentBalance, After Deduction: ₹$newBalance");
      }


      // 6. Update all documents in a single transaction
      await firestore.runTransaction((transaction) async {
        // Update owner wallet
        transaction.update(ownerWalletRef, {
          'balance': newBalance,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Add transaction record
        final transactionRef = firestore.collection('owner_wallet_transactions').doc();
        transaction.set(transactionRef, {
          'userId': ownerId,
          'amount': commissionAmount,
          'type': 'debit',
          'description': 'Vandizone Commission for Cash payment',
          'timestamp': FieldValue.serverTimestamp(),
          'tripId': widget.bookingData?['tripId']?.toString() ?? '',
          'userCode': userCode,
          'fare': fare,
          'commissionPercentage': vandizoneCommissionPercent,
        });

        // Update booking status to 5 (completed)
        final bookingRef = firestore.collection('bhl_bookings').doc(bookingId);
        transaction.update(bookingRef, {
          'status': 5,
          // "tip":tip,
          // 'paymentStatus': 'paid',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final bhlQuery = await firestore.collection('bhl')
            .where('currentBooking', isEqualTo: bookingId)
            .limit(1)
            .get();

        if (bhlQuery.docs.isNotEmpty) {
          final bhlRef = firestore.collection('bhl').doc(bhlQuery.docs.first.id);
          transaction.update(bhlRef, {
            'status': 0,
            'currentBooking': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      debugPrint('[PAYMENT] Payment processed successfully. Booking:$bookingId');

      // Show success message and close bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment collected and status updated successfully')),
      );

      Navigator.pop(context, true); // Close the bottom sheet
      _showRatingDialog(context);
      await _sendCompletionNotifications();

    } catch (e, stackTrace) {
      debugPrint('[ERROR] Failed to process payment: $e');
      debugPrint('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleOnlinePaymentCompletion() async {
    try {

      final tip = double.tryParse(_tipController.text.trim()) ?? 0.0;

      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      if (widget.bookingData == null) {
        throw Exception("Invalid booking data");
      }

      final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
      final tripId = widget.bookingData?['tripId']?.toString() ?? '';
      final fare = (widget.bookingData?['fare'] as num?)?.toDouble() ?? 0.0;
      final ownerId = widget.bookingData?['ownerDetails']?['id'];
      final userCode = widget.bookingData?['ownerDetails']?['userCode']?.toString() ?? '';

      if (bookingId == null || fare <= 0 || ownerId == null) {
        throw Exception("Missing booking, fare or owner info");
      }

      // Step 1: Update booking and release BHL
      await firestore.runTransaction((transaction) async {
        final bookingRef = firestore.collection('bhl_bookings').doc(bookingId);
        transaction.update(bookingRef, {
          'status': 5,
          // 'paymentStatus': 'paid',
          // "tip":tip,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Free the BHL vehicle
        final bhlQuery = await firestore.collection('bhl')
            .where('currentBooking', isEqualTo: bookingId)
            .limit(1)
            .get();

        if (bhlQuery.docs.isNotEmpty) {
          final bhlRef = firestore.collection('bhl').doc(bhlQuery.docs.first.id);
          transaction.update(bhlRef, {
            'status': 0,
            'currentBooking': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      await firestore.collection('vandizone_wallet').add({
        'amount': fare,
        'type': 'settlement',
        'status': 'received',
        'tripId': tripId,
        'bookingId': bookingId,
        'ownerId': ownerId,
        'captainId': userCode,
        'payment': {
          'mode': 'online',
          'receivedAt': FieldValue.serverTimestamp(),
          'settledAt': null,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });


      debugPrint('[ONLINE PAYMENT] Payment completed successfully. Booking:$bookingId');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Online payment recorded in Vandizone wallet')),
      );

      Navigator.pop(context, true); // Close any bottom sheet
      _showRatingDialog(context);
      await _sendCompletionNotifications();

    } catch (e, stackTrace) {
      debugPrint('[ERROR] Failed to complete online payment: $e');
      debugPrint('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _showPaymentModeBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Has the customer completed the payment?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context, false); // Cancel
                      },
                      child: Text("Cancel"),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () {
                        _updatePaymentStatus();
                        Navigator.pop(context, true); // Confirm
                      },
                      child: Text("Confirm"),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updatePaymentStatus() async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      if (widget.bookingData == null) {
        throw Exception("Invalid booking data");
      }

      final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
      if (bookingId == null) {
        throw Exception("Booking reference not found");
      }

      final tip = double.tryParse(_tipController.text.trim()) ?? 0.0;

      await firestore.runTransaction((transaction) async {
        // Update booking
        final bookingRef = firestore.collection('bhl_bookings').doc(bookingId);
        transaction.update(bookingRef, {
          'status': 5,
          // 'tip': tip,
          // 'paymentStatus': 'paid',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update truck
        final truckQuery = await firestore.collection('bhl')
            .where('currentBooking', isEqualTo: bookingId)
            .limit(1)
            .get();

        if (truckQuery.docs.isNotEmpty) {
          final truckRef = firestore.collection('bhl').doc(truckQuery.docs.first.id);
          transaction.update(truckRef, {
            'status': 0,
            'currentBooking': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      debugPrint('[PAYMENT] Payment completed successfully. Booking: $bookingId');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment processed and status updated successfully')),
      );

      Navigator.pop(context, true); // Close sheet
      _showRatingDialog(context);

    } catch (e, stackTrace) {
      debugPrint('[ERROR] Failed to update payment: $e');
      debugPrint('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
}