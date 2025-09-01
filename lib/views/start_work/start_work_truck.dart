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
import '../../helper/ui_helper.dart';
import '../../utils/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../widgets/my_elevated_button.dart';

class StartWorkTruckView extends StatefulWidget {
  final Map<String, dynamic>? bookingData;
  const StartWorkTruckView({super.key, this.bookingData});

  @override
  State<StartWorkTruckView> createState() => _StartWorkTruckViewState();
}

final PinTheme defaultPinTheme = PinTheme(
  width: 10.h,
  height: 7.h,
  textStyle: primaryMedium18,
  decoration: BoxDecoration(
    color: white,
    borderRadius: myBorderRadius(10),
    boxShadow: [boxShadow1],
  ),
  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
);

class _StartWorkTruckViewState extends State<StartWorkTruckView> {
  // Define the new primary color
  static const Color primary = Color(0xFF2ECC71);
  bool showStartOtpSection = false;
  bool showEndOtpSection = false;
  bool otpfromCust = false;
  bool otpStartTrip = false;
  bool otpEndTrip = false;
  TimeOfDay? _selectedDelayTime;
  DateTime? _selectedDelayDate;
  int totalSeconds = 0;
  bool isWorking = false;
  bool isPaused = false;
  String? loadWeight;
  String? unloadWeight;
  TextEditingController loadWeightController = TextEditingController();
  TextEditingController unloadWeightController = TextEditingController();
  TextEditingController ewayBillController = TextEditingController();
  // String? selectedIntensity;
  // final List<String> intensity = ['Light', 'Moderate', 'Heavy'];
  bool isOtpVerified = false;
  String? intensity;
  File? selectedImage;
  String? imageName;
  String _selectedPaymentMode = 'Cash'; // Default selection
  final List<String> _paymentModes = ['Cash', 'Online'];
  int _rating = 0;
  TextEditingController _remarksController = TextEditingController();
  String? _startWorkImageUrl;
  String? _afterWorkImageUrl; // Add this at the top of your state class
  DateTime? _workStartTime;
  DateTime? _workPauseTime;
  Duration _totalWorkDuration = Duration.zero;
  Timer? _workTimer;
  final ImagePicker _picker = ImagePicker();
  bool _isOtpVerifiedStart = false;
  bool _isOtpVerifiedEnd = false;
  late Razorpay _razorpay;
  bool _isProcessing = false;
  bool isBeforeLoadingComplete = false;
  bool isDuringTripComplete = false;
  String? _razorpayKeyId;
  File? _delayImage;
  String? _delayImageUrl;
  TextEditingController _tipController = TextEditingController();
  // String? _startWorkImageUrl;
  // String? _afterWorkImageUrl;
  bool _isBeforeLoadingComplete = false;
  bool _isDuringTripComplete = false;
  bool _isAfterDeliveryComplete = false;
  String? _locationText;


  // Future<void> pickStartWorkImage() async {
  //   final XFile? image = await ImagePicker().pickImage(source: ImageSource.camera);
  //   if (image == null) return;
  //
  //   final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
  //   if (bookingId == null) return;
  //
  //   final ref = FirebaseStorage.instance
  //       .ref()
  //       .child('truck_start_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
  //
  //   final uploadTask = ref.putFile(File(image.path));
  //   final snapshot = await uploadTask;
  //
  //   final downloadUrl = await snapshot.ref.getDownloadURL();
  //
  //   setState(() {
  //     _startWorkImageUrl = downloadUrl;
  //   });
  //
  //   await FirebaseFirestore.instance
  //       .collection('truck_bookings')
  //       .doc(bookingId)
  //       .update({
  //     'startworkImage': downloadUrl,
  //     'updatedAt': FieldValue.serverTimestamp(),
  //   });
  // }

  Future<void> pickStartWorkImage() async {
    // Step 1: Pick image from camera
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.camera);
    if (image == null) return;

    // Step 2: Get bookingId
    final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
    if (bookingId == null) return;

    // Step 3: Request & Get current location
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    double latitude = position.latitude;
    double longitude = position.longitude;

    // Step 4: Upload image to Firebase Storage
    final ref = FirebaseStorage.instance
        .ref()
        .child('truck_start_images/${DateTime.now().millisecondsSinceEpoch}.jpg');

    final uploadTask = ref.putFile(File(image.path));
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    setState(() {
      _startWorkImageUrl = downloadUrl;
    });

    // Step 5: Update Firestore with image + location
    await FirebaseFirestore.instance
        .collection('truck_bookings')
        .doc(bookingId)
        .update({
      'startworkImage': downloadUrl,
      'startworkLat': latitude,
      'startworkLng': longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> pickAfterWorkImage() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.camera);
    if (image == null) return;

    final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
    if (bookingId == null) return;

    final ref = FirebaseStorage.instance
        .ref()
        .child('truck_end_images/${DateTime.now().millisecondsSinceEpoch}.jpg');

    final uploadTask = ref.putFile(File(image.path));
    final snapshot = await uploadTask;

    final downloadUrl = await snapshot.ref.getDownloadURL();

    setState(() {
      _afterWorkImageUrl = downloadUrl;
    });

    await FirebaseFirestore.instance
        .collection('truck_bookings')
        .doc(bookingId)
        .update({
      'afterworkImage': downloadUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Widget _buildBeforeWorkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Before Work Photo"),
        if (_startWorkImageUrl != null)
          Image.network(_startWorkImageUrl!, height: 150),
        ElevatedButton(
          onPressed: pickStartWorkImage,
          child: Text("Take Start Work Photo"),
        ),
      ],
    );
  }

  Widget _buildAfterWorkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("After Work Photo"),
        if (_afterWorkImageUrl != null)
          Image.network(_afterWorkImageUrl!, height: 150),
        ElevatedButton(
          onPressed: pickAfterWorkImage,
          child: Text("Take End Work Photo"),
        ),
      ],
    );
  }

  Future<void> _loadExistingImages() async {
    final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
    if (bookingId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('truck_bookings')
        .doc(bookingId)
        .get();

    if (doc.exists) {
      setState(() {
        _startWorkImageUrl = doc.data()?['startworkImage'];
        _afterWorkImageUrl = doc.data()?['afterworkImage'];
      });
    }
  }

  Future<void> pickImage() async {
    final picked = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (picked != null) {
      final image = await ImagePicker().pickImage(source: picked);
      if (image != null) {
        setState(() {
          _delayImage = File(image.path);
        });
        await _uploadDelayImage();
      }
    }
  }

  Future<void> _uploadDelayImage() async {
    if (_delayImage == null) return;

    try {
      final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
      if (bookingId == null) return;

      // Create a reference to the location you want to upload to in Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('delay_images')
          .child('$bookingId-${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Upload the file to Firebase Storage
      final uploadTask = storageRef.putFile(_delayImage!);
      final snapshot = await uploadTask.whenComplete(() {});

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore with the image URL
      await FirebaseFirestore.instance
          .collection('truck_bookings')
          .doc(bookingId)
          .update({
        'delayImageUrl': downloadUrl,
        'delayItem': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      setState(() {
        _delayImageUrl = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delay image uploaded successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload delay image: $e')),
      );
    }
  }


  @override
  void initState() {
    super.initState();
    _loadBookingData();
    _loadExistingImages();
    _loadCompletionStatus();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // Handle payment success
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment successful: ${response.paymentId}')),
    );
    _handleOnlinePaymentCompletion();
  }

  Future<void> _loadCompletionStatus() async {
    final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
    if (bookingId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('truck_bookings')
        .doc(bookingId)
        .get();

    if (doc.exists) {
      setState(() {
        _isBeforeLoadingComplete = doc.data()?['startOtpVerified'] ?? false;
        _isDuringTripComplete = doc.data()?['tripInProgress'] ?? false;
        _isAfterDeliveryComplete = doc.data()?['endOtpVerified'] ?? false;
      });
    }
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

  void _loadBookingData() {
    if (widget.bookingData != null) {
      // Access booking details
      final fromLocation = widget.bookingData!['fromLocation'] as Map<String, dynamic>?;
      final toLocation = widget.bookingData!['toLocation'] as Map<String, dynamic>?;
      final customerDetails = widget.bookingData!['customer'] as Map<String, dynamic>?;
      final customerID = widget.bookingData!['customer']['uid'];
      final vehicleDetails = widget.bookingData!['vehicleDetails'] as Map<String, dynamic>?;
      final workIntensity = widget.bookingData!['workIntensity']??"";
      final paymentMethod = widget.bookingData!['paymentMethod']??"";
      final currentBooking = widget.bookingData!['vehicleDetails']['currentBooking']??"";
      _isOtpVerifiedStart = widget.bookingData!['startOtpVerified'] ?? false;
      _isOtpVerifiedEnd = widget.bookingData!['endOtpVerified'] ?? false;
      final loadWeight = widget.bookingData!['dimensions']?['tonnage'];

      if (loadWeight != null) {
        loadWeightController.text = loadWeight.toString();
      }
      if (workIntensity.isNotEmpty) {
        setState(() {
          intensity = workIntensity;
        });
      }
      final beforeWorkImage = widget.bookingData!['startworkImage'] ?? '';
      if (beforeWorkImage.isNotEmpty) {
        setState(() {
          _startWorkImageUrl = beforeWorkImage;
        });
      }
      final afterWorkImage = widget.bookingData!['afterworkImage'] ?? '';
      if (afterWorkImage.isNotEmpty) {
        setState(() {
          _afterWorkImageUrl = afterWorkImage;
        });
      }
      if (paymentMethod.isNotEmpty) {
        setState(() {
          _selectedPaymentMode = paymentMethod;
        });
      }
      // Use these details in your UI
      debugPrint('From Location: $fromLocation');
      debugPrint('To Location: $toLocation');
      debugPrint('Customer: $customerDetails');
      debugPrint('Vehicle: $vehicleDetails');
      debugPrint('workIntensity: $workIntensity');
      debugPrint('currentBooking: $currentBooking');
    }
  }

  @override
  void dispose() {
    loadWeightController.dispose();
    unloadWeightController.dispose();
    ewayBillController.dispose();
    _workTimer?.cancel();
    _razorpay.clear();
    super.dispose();
  }

  void _openRazorpayPayment() async{

    final tip = double.tryParse(_tipController.text.trim()) ?? 0.0;
    var fare = (widget.bookingData!['fare'] as num?)?.toDouble() ?? 0.0;
    fare +=tip;

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
      'amount': (fare * 100).toInt(),
      'name': 'Vandizone',
      'description': 'Payment for booking',
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
    print('[OTP VERIFICATION] OTP received: $otp');

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
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId,
          "otp": otp,
        }),
      );

      if (response.statusCode == 200) {
        final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
        if (bookingId != null) {
          // Get the load weight from the controller
          final loadWeight = loadWeightController.text;
          final loadWeightInt = int.tryParse(loadWeight) ?? 0;

          // Calculate tonnage (assuming 1000kg = 1 ton)
          final tonnage = (loadWeightInt / 1000).toStringAsFixed(2);

          // Update Firestore with OTP verification, load weight, and tonnage
          await FirebaseFirestore.instance
              .collection('truck_bookings')
              .doc(bookingId)
              .update({
            'startOtpVerified': true,
            'dimensions.tonnage': loadWeightController.text,
          });

          await sendCustomerBookingNotification(
            collection: 'truck_bookings',
            bookingCode: bookingId ?? '',
            eventType: 'booking_started',
            title: 'Work Started',
            body: 'Captain has started your work.',
          );

          print('[OTP VERIFICATION] Load weight updated to: $loadWeightInt kg');
          print('[OTP VERIFICATION] Tonnage updated to: $tonnage tons');
        }

        _loadBookingData();
        _verify(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP verified and load details updated successfully!')),
        );

        // final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
        if (bookingId != null) {
          await FirebaseFirestore.instance
              .collection('truck_bookings')
              .doc(bookingId)
              .update({
            'ewayBill': ewayBillController.text.trim(),
            'startOtpVerified': true,
            'tripStartedAt': FieldValue.serverTimestamp(),
          });

          setState(() {
            _isBeforeLoadingComplete = true;
          });
        }
      } else {
        throw Exception("Invalid OTP: ${response.body}");
      }
    } catch (e) {
      print('[OTP VERIFICATION ERROR] $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to verify OTP: $e')),
      );
      rethrow;
    } finally {
      print('[OTP VERIFICATION] Verification process completed');
    }
  }

  Future<void> verifyUserOtpByCaptainEnd(String userId, String otp) async {
    debugPrint('[OTP VERIFICATION] Starting end OTP verification process');

    try {
      final captain = FirebaseAuth.instance.currentUser;
      if (captain == null) {
        throw Exception("Not authenticated");
      }

      final idToken = await captain.getIdToken();

      final url = "https://us-central1-vandizone-admin.cloudfunctions.net/verifyOtpForUser";
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId,
          "otp": otp,
        }),
      );

      if (response.statusCode == 200) {
        final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
        if (bookingId != null) {
          await FirebaseFirestore.instance
              .collection('truck_bookings')
              .doc(bookingId)
              .update({
            'endOtpVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        setState(() {
          _isOtpVerifiedEnd = true;
        });

        // final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];

        if (bookingId != null) {
          await FirebaseFirestore.instance
              .collection('truck_bookings')
              .doc(bookingId)
              .update({
            'endOtpVerified': true,
            'tripCompletedAt': FieldValue.serverTimestamp(),
            // Update unload weight and other data
          });

          await sendCustomerBookingNotification(
            collection: 'truck_bookings',
            bookingCode: bookingId ?? '',
            eventType: 'booking_ended',
            title: 'Work Ended',
            body: 'Captain Finished your work. Proceed with your payment',
          );

          setState(() {
            _isDuringTripComplete = true;
          });
        }

      } else {
        throw Exception("Invalid OTP: ${response.body}");
      }
    } catch (e) {
      debugPrint('[OTP VERIFICATION ERROR] $e');
      rethrow;
    }
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
                     'Work Mode - Trip Mode - Truck',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
              // Truck specific content
            _buildSectionTitle('BEFORE LOADING'),
            _buildBeforeLoadingSection(),
            SizedBox(height: 24),

            // DURING TRIP SECTION (only visible if before loading complete)
            if (_isBeforeLoadingComplete) ...[
              _buildSectionTitle('DURING TRIP'),
              _buildDuringTripSection(),
              SizedBox(height: 24),
            ],

            // AFTER DELIVERY SECTION (only visible if during trip complete)
            // if (_isBeforeLoadingComplete && _isDuringTripComplete) ...[
              _buildSectionTitle('AFTER DELIVERY'),
              _buildAfterDeliverySection(),
            // ],
          ],
        ),
      ),
    );
  }

  void _showTruckOtpCust(BuildContext context) {
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
            const Text(
              'Enter OTP to Confirm Work Done',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  // ✅ Process the OTP value from endOtpController.text
                  Navigator.pop(context); // Close bottom sheet
                  // _onWorkDoneOtpVerified(); // Your logic after OTP verified
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
            const SizedBox(height: 10),
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
                  'Enter OTP to Confirm Unloading',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                InkWell(
                  onTap: () async {
                    print("📞 Call button pressed");
                    final user = FirebaseAuth.instance.currentUser;
                    final idToken = await user?.getIdToken();

                    final customerId = widget.bookingData?['customer']?['uid'];
                    final captainName = widget.bookingData?['captainDetails']?['name'];
                    final bookingCode = widget.bookingData?['bookingCode'];
                    final channelName = "call_channel_$bookingCode";

                    if (idToken != null && customerId != null) {
                      await sendCustomerCallNotification(
                        customerId: customerId,
                        bookingCode: bookingCode,
                        captainName: captainName,
                        channelName: channelName,
                        idToken: idToken,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VoiceCallScreen(
                            isCaller: true,
                            initialChannel: channelName,
                          ),
                        ),
                      );
                    }
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
                onPressed: () async {
                  final otp = endOtpController.text;
                  if (otp.length != 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a 4-digit OTP')),
                    );
                    return;
                  }

                  try {
                    Navigator.pop(context);
                    await verifyUserOtpByCaptainEnd(
                        widget.bookingData!['customer']['uid'],
                        otp
                    );

                    // Update unload weight in Firestore after OTP verification
                    final bookingId = widget.bookingData?['vehicleDetails']['currentBooking'];
                    if (bookingId != null) {
                      await FirebaseFirestore.instance
                          .collection('truck_bookings')
                          .doc(bookingId)
                          .update({
                        'unloadWeight': unloadWeightController.text,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('OTP verified and unload details updated!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to verify OTP: ${e.toString()}')),
                    );
                  }
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildBeforeLoadingSection() {
    final bool isPhotoUploaded = _startWorkImageUrl != null && _startWorkImageUrl!.isNotEmpty;
    final double fareAmount = double.tryParse(
        widget.bookingData?['fare']?.toString() ?? '0'
    ) ?? 0;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabelWithTextField(
              label: 'Load Weight (KG)',
              hintText: 'e.g., 12000',
              controller: loadWeightController,
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
            if (fareAmount > 50000)
            _buildLabelWithTextField(
              label: 'E-way Bill Number',
              hintText: 'Enter E-way Bill Number',
              controller: ewayBillController,
              keyboardType: TextInputType.text,
            ),
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
                          onPressed: pickStartWorkImage,
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
                    if (_locationText != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _locationText!,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildPrimaryButton(
              icon: Icons.directions_car_filled,
              text: 'OTP Confirm & Start Trip',
              onPressed: () async {
                try {
                  await generateOtpForUserByCaptain(widget.bookingData!['customer']['uid']);
                  _showOtpBottomSheet(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
                }
              },
            ),
            // if (otpStartTrip) ...[
            //   SizedBox(height: 20),
            //   Text(
            //       'Enter OTP we sent you',
            //       style: colorC4Regular16
            //   ),
            //   SizedBox(height: 10),
            //   Row(
            //     children: [
            //       Expanded(
            //         flex: 3, // Gives more space to OTP input
            //         child: Pinput(
            //           length: 4,
            //           defaultPinTheme: defaultPinTheme,
            //           focusedPinTheme: defaultPinTheme,
            //           submittedPinTheme: defaultPinTheme,
            //           // onCompleted: (value) => _verify(context),
            //         ),
            //       ),
            //       SizedBox(width: 10), // Space between OTP and button
            //       Expanded(
            //         flex: 1, // Smaller space for button
            //         child: ElevatedButton(
            //           onPressed: () {
            //             _verify(context);
            //             setState(() {
            //               otpStartTrip = false;
            //             });
            //           },
            //           style: ElevatedButton.styleFrom(
            //             backgroundColor: Colors.blue, // Changed to blue
            //             padding: EdgeInsets.symmetric(vertical: 16, horizontal: 3),
            //             shape: RoundedRectangleBorder(
            //               borderRadius: BorderRadius.circular(10),
            //             ),
            //           ),
            //           child: Text(
            //             'Verify',
            //             style: TextStyle(
            //               color: Colors.white,
            //               fontWeight: FontWeight.w600,
            //             ),
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ],
          ],
        ),
      ),
    );
  }

// Modified _buildDuringTripSection
  Future<void> _pickDelayTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDelayTime = picked;
      });
    }
  }

  // Widget _buildDuringTripSection() {
  //   return Card(
  //     elevation: 2,
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Row(
  //             children: [
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       'Delay Reason Photo',
  //                       style: TextStyle(
  //                         fontWeight: FontWeight.w500,
  //                         fontSize: 14,
  //                       ),
  //                     ),
  //                     Text(
  //                       '(if any)',
  //                       style: TextStyle(
  //                         fontSize: 12,
  //                         color: Colors.grey.shade600,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //               _buildOutlineButton(
  //                 icon: Icons.camera_alt,
  //                 text: 'Choose File',
  //                 onPressed: pickImage,
  //               ),
  //             ],
  //           ),
  //           if (_delayImage != null) ...[
  //             const SizedBox(height: 12),
  //             ClipRRect(
  //               borderRadius: BorderRadius.circular(8),
  //               child: Container(
  //                 height: 120,
  //                 width: double.infinity,
  //                 decoration: BoxDecoration(
  //                   color: Colors.grey.shade100,
  //                 ),
  //                 child: Stack(
  //                   children: [
  //                     Image.file(
  //                       _delayImage!,
  //                       fit: BoxFit.cover,
  //                       width: double.infinity,
  //                     ),
  //                     Positioned(
  //                       top: 4,
  //                       right: 4,
  //                       child: IconButton(
  //                         icon: const Icon(Icons.close, size: 20),
  //                         color: Colors.white,
  //                         style: IconButton.styleFrom(
  //                           backgroundColor: Colors.black54,
  //                           padding: const EdgeInsets.all(4),
  //                         ),
  //                         onPressed: () {
  //                           setState(() {
  //                             _delayImage = null;
  //                             _delayImageUrl = null;
  //                           });
  //                         },
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           ],
  //           const SizedBox(height: 16),
  //           _buildSecondaryButton(
  //             icon: Icons.access_time,
  //             text: 'Update Estimated Arrival Time',
  //             onPressed: _pickDelayTime,
  //           ),
  //           if (_selectedDelayTime != null) ...[
  //             const SizedBox(height: 8),
  //             Text(
  //               'Selected Time: ${_selectedDelayTime!.format(context)}',
  //               style: TextStyle(
  //                 fontSize: 14,
  //                 fontWeight: FontWeight.w500,
  //                 color: Colors.blueGrey,
  //               ),
  //             ),
  //           ],
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildDuringTripSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delay Reason Photo',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '(if any)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildOutlineButton(
                  icon: Icons.camera_alt,
                  text: 'Choose File',
                  onPressed: pickImage,
                ),
              ],
            ),
            if (_delayImage != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                  ),
                  child: Stack(
                    children: [
                      Image.file(
                        _delayImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          color: Colors.white,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            padding: const EdgeInsets.all(4),
                          ),
                          onPressed: () {
                            setState(() {
                              _delayImage = null;
                              _delayImageUrl = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Button to select date
            _buildSecondaryButton(
              icon: Icons.calendar_today,
              text: 'Select Delay Date',
              onPressed: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2023),
                  lastDate: DateTime(2030),
                );
                if (pickedDate != null) {
                  setState(() {
                    _selectedDelayDate = pickedDate;
                  });
                }
              },
            ),
            if (_selectedDelayDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Selected Date: ${_selectedDelayDate!.day}-${_selectedDelayDate!.month}-${_selectedDelayDate!.year}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.blueGrey,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Button to select time
            _buildSecondaryButton(
              icon: Icons.access_time,
              text: 'Update Estimated Arrival Time',
              onPressed: _pickDelayTime,
            ),
            if (_selectedDelayTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Selected Time: ${_selectedDelayTime!.format(context)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

//   Widget _buildDuringTripSection() {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Delay Reason Photo',
//                         style: TextStyle(
//                           fontWeight: FontWeight.w500,
//                           fontSize: 14,
//                         ),
//                       ),
//                       Text(
//                         '(if any)',
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.grey.shade600,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 _buildOutlineButton(
//                   icon: Icons.camera_alt,
//                   text: 'Choose File',
//                   onPressed: pickImage,
//                 ),
//               ],
//             ),
//             if (_delayImage != null) ...[
//               const SizedBox(height: 12),
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(8),
//                 child: Container(
//                   height: 120,
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade100,
//                   ),
//                   child: Stack(
//                     children: [
//                       Image.file(
//                         _delayImage!,
//                         fit: BoxFit.cover,
//                         width: double.infinity,
//                       ),
//                       Positioned(
//                         top: 4,
//                         right: 4,
//                         child: IconButton(
//                           icon: const Icon(Icons.close, size: 20),
//                           color: Colors.white,
//                           style: IconButton.styleFrom(
//                             backgroundColor: Colors.black54,
//                             padding: const EdgeInsets.all(4),
//                           ),
//                           onPressed: () {
//                             setState(() {
//                               _delayImage = null;
//                               _delayImageUrl = null;
//                             });
//                           },
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//             const SizedBox(height: 16),
//             _buildSecondaryButton(
//               icon: Icons.access_time,
//               text: 'Update Estimated Arrival Time',
//               onPressed: () {},
//             ),
//           ],
//         ),
//       ),
//     );
//   }

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
                                .collection('truck_bookings')
                                .doc(bookingId)
                                .update({
                              'customerRating': _rating,
                              'customerReview': _remarksController.text.trim(),
                            });

                            Navigator.pop(context); // Close bottom sheet
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Rating submitted successfully!')),
                            );
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

  Widget _buildAfterDeliverySection() {
    final bool isPhotoUploaded = _afterWorkImageUrl != null && _afterWorkImageUrl!.isNotEmpty;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabelWithTextField(
              label: 'Unload Weight (KG)',
              hintText: 'e.g., 11800',
              controller: unloadWeightController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
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
            SizedBox(height: 20),
            _buildPrimaryButton(
              icon: Icons.verified,
              text: 'OTP Confirm Unload',
              onPressed: () async {
                try {
                  await generateOtpForUserByCaptain(widget.bookingData!['customer']['uid']);
                  _showEndOtpBottomSheet(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to generate OTP: ${e.toString()}'))
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOutlineButton(
                    icon: Icons.star_rate,
                    text: 'Rate Customer',
                    onPressed: () {
                      _showRatingDialog(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPrimaryButton(
                    icon: Icons.payment,
                    text: 'Confirm Payment',
                    onPressed: () {
                      _showPaymentModeBottomSheet(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    bool isEditable = false; // Track edit state

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isEditable ? Icons.check : Icons.edit,
                    color: primary,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      isEditable = !isEditable;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isEditable ? Colors.white : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: MyTextfield(
                controller: controller,
                keyboardType: keyboardType,
                hintText: hintText,
                header: null,
                headerStyle: null,
                readOnly: !isEditable, // Use readOnly instead of enabled
              ),
            ),
          ],
        );
      },
    );
  }

  void _verify(BuildContext context) {
    setState(() {
      isOtpVerified = true;
      isBeforeLoadingComplete = true; // unlock the next section
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OTP verified successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showPaymentModeBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Payment Mode',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20),

                  // Radio buttons for payment modes
                  Column(
                    children: _paymentModes.map((mode) {
                      return RadioListTile<String>(
                        title: Text(mode),
                        value: mode,
                        groupValue: _selectedPaymentMode,
                        onChanged: (String? value) {
                          setState(() {
                            _selectedPaymentMode = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 20),

                  // ⚠️ Show disclaimer if Cash is selected
                  if (_selectedPaymentMode == 'Cash') ...[
                    Text(
                      'Note: Vandizone is not responsible for any money collected as cash.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 12),
                  ],

                  // Confirm Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      minimumSize: Size(double.infinity, 50),
                    ),
                    onPressed: () async {
                      if (_selectedPaymentMode == 'Cash') {
                        await _handlePaymentAndCommission();
                      } else {
                        Navigator.pop(context);
                        _openRazorpayPayment();
                      }
                    },
                    child: Text(
                      _selectedPaymentMode == 'Cash'
                          ? 'Confirm Payment'
                          : 'Confirm Payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),

                  // Tip field
                  TextField(
                    controller: _tipController,
                    keyboardType:
                    TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Optional Tip Amount (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
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

      final fare = (widget.bookingData!['fare'] as num?)?.toDouble() ?? 0.0;
      final tip = double.tryParse(_tipController.text.trim()) ?? 0.0;
      final totalFare = fare + tip;
      if (fare <= 0) {
        throw Exception("Invalid fare amount");
      }

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

      final double commissionAmount = (fare * vandizoneCommissionPercent) / 100;

      final ownerQuery = await firestore.collection('owners')
          .where('userCode', isEqualTo: userCode)
          .limit(1)
          .get();

      if (ownerQuery.docs.isEmpty) {
        throw Exception("Owner with userCode '$userCode' not found");
      }
      final ownerId = ownerQuery.docs.first.id;

      final ownerWalletRef = firestore.collection('owner_wallets').doc(ownerId);
      final ownerWalletSnap = await ownerWalletRef.get();
      if (!ownerWalletSnap.exists) {
        throw Exception("Wallet not found for owner $ownerId");
      }

      final currentBalance = (ownerWalletSnap.data()!['balance'] as num?)?.toDouble() ?? 0.0;

      final newBalance = currentBalance - commissionAmount;

      if (newBalance < 0) {
        debugPrint("[WARNING] Wallet balance will go negative. Current: ₹$currentBalance, After Deduction: ₹$newBalance");
      }

      await firestore.runTransaction((transaction) async {
        transaction.update(ownerWalletRef, {
          'balance': newBalance,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

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

        final bookingRef = firestore.collection('truck_bookings').doc(bookingId);
        transaction.update(bookingRef, {
          "tip": tip,
          'status': 5,
          'paymentStatus': 'paid',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final bhlQuery = await firestore.collection('trucks')
            .where('currentBooking', isEqualTo: bookingId)
            .limit(1)
            .get();

        if (bhlQuery.docs.isNotEmpty) {
          final bhlRef = firestore.collection('trucks').doc(bhlQuery.docs.first.id);
          transaction.update(bhlRef, {
            'status': 0,
            'currentBooking': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      debugPrint('[PAYMENT] Payment processed successfully. Booking:$bookingId');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment collected and status updated successfully')),
      );

      Navigator.pop(context, true);
      _showRatingDialog(context);

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
      if (bookingId == null) {
        throw Exception("Booking reference not found");
      }

      await firestore.runTransaction((transaction) async {
        final bookingRef = firestore.collection('truck_bookings').doc(bookingId);
        transaction.update(bookingRef, {
          'status': 5,
          "tip":tip,
          'paymentStatus': 'paid',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Find and update BHL document
        final bhlQuery = await firestore.collection('trucks')
            .where('currentBooking', isEqualTo: bookingId)
            .limit(1)
            .get();

        if (bhlQuery.docs.isNotEmpty) {
          final bhlRef = firestore.collection('trucks').doc(bhlQuery.docs.first.id);
          transaction.update(bhlRef, {
            'status': 0,
            'currentBooking': FieldValue.delete(), // Remove the booking reference
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      debugPrint('[ONLINE PAYMENT] Payment completed successfully. Booking:$bookingId');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Online payment processed and status updated successfully')),
      );

      Navigator.pop(context, true); // Close any open bottom sheet
      _showRatingDialog(context);

    } catch (e, stackTrace) {
      debugPrint('[ERROR] Failed to complete online payment: $e');
      debugPrint('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
}