import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/assets.dart';
import '../../../utils/constant.dart';
import '../../../utils/icon_size.dart';
import '../../../components/my_appbar.dart';
import '../../../widgets/my_textfield.dart';
import '../../../widgets/my_elevated_button.dart';
import '../../../widgets/my_dropdown.dart';
import 'package:vandizone_caption/routes/routes.dart';
import '../../../helper/ui_helper.dart';
import 'dart:io';

class VehicleFormPage extends StatefulWidget {
  final Map<String, dynamic>? vehicleData;

  const VehicleFormPage({super.key, this.vehicleData});

  @override
  State<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends State<VehicleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late Razorpay _razorpay;
  double? _bhlRegistrationFee;

  // Controllers
  final TextEditingController _vehicleNumberController = TextEditingController();
  final TextEditingController _makeModelController = TextEditingController();
  final TextEditingController _axlesController = TextEditingController();
  final TextEditingController _engineNumberController = TextEditingController();
  final TextEditingController _chassisNumberController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _insuredValueController = TextEditingController();
  final TextEditingController _tyresController = TextEditingController();
  final TextEditingController _payloadController = TextEditingController();
  final TextEditingController _gcwController = TextEditingController();
  final TextEditingController _dimensionsController = TextEditingController();
  final TextEditingController _rcStartDateController = TextEditingController();
  final TextEditingController _rcEndDateController = TextEditingController();


  // Dropdown values
  String? selectedVehicleType;
  final List<String> vehicleTypes = ['Truck', 'Backhoe Loader'];
  String? selectedVehicleCategory;
  final List<String> vehicleCategory = ['LCV', 'MCV', 'HCV', 'Trailer'];
  Map<String, dynamic>? selectedBodyType;
  List<Map<String, dynamic>> vehicleBodyTypes = [];
  String? selectedPermitAccess;
  final List<String> permitAccess = ['Zone/Local Use Only', 'Inter-District & Inter-State Allowed'];

  // Image files
  File? vehiclePhotoImage;
  String? vehiclePhotoImageName;
  File? sideViewImage;
  String? sideViewImageName;
  File? rcImage;
  String? rcImageName;
  File? insuranceImage;
  String? insuranceImageName;

  String? _ownerCode;
  String? _ownerId;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _initializeFormWithData();
    _fetchBHLRegistrationFee();
    _loadOwnerData();
    _fetchTruckTypes();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _vehicleNumberController.dispose();
    _makeModelController.dispose();
    _axlesController.dispose();
    _engineNumberController.dispose();
    _chassisNumberController.dispose();
    _districtController.dispose();
    _insuredValueController.dispose();
    _tyresController.dispose();
    _payloadController.dispose();
    _gcwController.dispose();
    _dimensionsController.dispose();
    _rcStartDateController.dispose();
    _rcEndDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchBHLRegistrationFee() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('othersCharges')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        setState(() {
          _bhlRegistrationFee = (data['bhl_registration_fee'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      print('Error fetching BHL registration fee: $e');
    }
  }

  Future<void> _loadOwnerData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('owners')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _ownerCode = userDoc.data()?['userCode'] ?? 'N/A';
            _ownerId = user.uid;
          });
        }
      }
    } catch (e) {
      print('Error loading owner data: $e');
    }
  }

  Future<void> _fetchTruckTypes() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('truckTypes')
          .orderBy('name')
          .get();

      setState(() {
        vehicleBodyTypes = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'basePrice': data['basePrice'] ?? 0.0,
            'capacityRange': data['capacityRange'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      print('Error fetching truck types: $e');
    }
  }

  void _initializeFormWithData() {
    if (widget.vehicleData != null) {
      final data = widget.vehicleData!;
      _vehicleNumberController.text = data['vehicleNumber'] ?? '';
      _makeModelController.text = data['makeModel'] ?? '';
      _axlesController.text = data['numberOfAxles'] ?? '';
      _engineNumberController.text = data['engineNumber'] ?? '';
      _chassisNumberController.text = data['chassisNumber'] ?? '';
      _districtController.text = data['registeringDistrict'] ?? '';
      _insuredValueController.text = data['insuredDeclaredValue'] ?? '';
      _tyresController.text = data['numberOfTyres'] ?? '';
      _payloadController.text = data['payload'] ?? '';
      _gcwController.text = data['gcw'] ?? '';
      _dimensionsController.text = data['dimensions'] ?? '';
      selectedVehicleType = data['vehicleType'];
      selectedVehicleCategory = data['vehicleCategory'];
      selectedPermitAccess = data['permitAccess'];

      // Initialize selected body type if editing
      if (data['bodyTypeId'] != null) {
        selectedBodyType = {
          'id': data['bodyTypeId'],
          'name': data['bodyType'],
          'basePrice': data['basePrice'],
          'capacityRange': data['capacityRange'],
        };
      }
    }
  }

  Future<void> _pickImage({
    required Function(File, String) onImagePicked,
    ImageSource source = ImageSource.gallery,
  }) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      onImagePicked(File(pickedFile.path), pickedFile.name);
    }
  }

  Future<String?> _uploadImage(File? imageFile) async {
    if (imageFile == null) return null;

    try {
      final fileName = path.basename(imageFile.path);
      final destination = 'vehicles/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      final ref = FirebaseStorage.instance.ref(destination);
      await ref.putFile(imageFile);

      return await ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  Future<String> _generateVehicleCode(String vehicleType) async {
    String prefix = vehicleType.toLowerCase().contains('truck') ? 'VVT' : 'VVB';
    final yearSuffix = DateTime.now().year.toString().substring(2);

    final counterRef = FirebaseFirestore.instance.collection('counters').doc('${prefix.toLowerCase()}_codes');
    final counterDoc = await counterRef.get();
    int lastNumber = (counterDoc.data()?['lastNumber'] ?? 0) as int;
    lastNumber++;

    await counterRef.set({'lastNumber': lastNumber}, SetOptions(merge: true));

    return '$prefix$yearSuffix${lastNumber.toString().padLeft(4, '0')}';
  }

  Future<void> _initiatePayment() async {
    if (_formKey.currentState!.validate() && selectedVehicleType != null) {
      if (selectedVehicleType == 'Truck' && selectedBodyType == null) {
        UiHelper.showSnackBar(context, "Please select body type");
        return;
      }

      double amount = 0.0;
      String description = '';

      if (selectedVehicleType == 'Truck') {
        amount = (selectedBodyType!['basePrice'] as num).toDouble();
        description = 'Truck Registration Fee';
      } else if (selectedVehicleType == 'Backhoe Loader') {
        amount = _bhlRegistrationFee ?? 0.0;
        description = 'Backhoe Loader Registration Fee';
      }

      if (amount <= 0) {
        UiHelper.showSnackBar(context, "Invalid payment amount");
        return;
      }

      setState(() => _isProcessingPayment = true);

      try {
        final ownerId = FirebaseAuth.instance.currentUser?.uid;
        if (ownerId == null) throw Exception("Owner not logged in");

        final ownerDoc = await FirebaseFirestore.instance
            .collection('owners')
            .doc(ownerId)
            .get();

        if (!ownerDoc.exists) throw Exception("Owner not found");

        final ownerData = ownerDoc.data();
        final ownerMobile = ownerData?['mobile']?.toString() ?? '';
        final ownerEmail = ownerData?['email']?.toString() ?? '';

        if (ownerMobile.isEmpty) {
          throw Exception("Owner contact details missing");
        }

        final settingsQuery = await FirebaseFirestore.instance
            .collection('settings')
            .where('razorpayKeyId', isNotEqualTo: null)
            .limit(1)
            .get();

        if (settingsQuery.docs.isEmpty) {
          throw Exception('No settings document with Razorpay key found');
        }

        final razorpayKey = settingsQuery.docs.first.data()['razorpayKeyId'] as String?;
        if (razorpayKey == null || razorpayKey.isEmpty) {
          throw Exception('Razorpay key is empty in settings');
        }

        final options = {
          'key': razorpayKey,
          'amount': (amount * 100).toInt(), // paise
          'name': 'Vandizone',
          'description': description,
          'prefill': {
            'contact': ownerMobile,
            'email': ownerEmail,
          },
          'theme': {'color': '#00796B'}
        };

        _razorpay.open(options);
      } catch (e) {
        UiHelper.showSnackBar(context, "Error initiating payment: ${e.toString()}");
      } finally {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      // Record the wallet transaction first
      await _recordWalletTransaction(
        amount: selectedVehicleType == 'Truck'
            ? (selectedBodyType!['basePrice'] as num).toDouble()
            : _bhlRegistrationFee ?? 0.0,
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? '',
        signature: response.signature ?? '',
      );

      // Then submit the form
      await _submitForm();
    } catch (e) {
      UiHelper.showSnackBar(context, "Error processing payment: ${e.toString()}");
    } finally {
      setState(() => _isProcessingPayment = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessingPayment = false);
    UiHelper.showSnackBar(context, "Payment failed: ${response.message ?? 'Unknown error'}");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() => _isProcessingPayment = false);
    UiHelper.showSnackBar(context, "External wallet selected: ${response.walletName}");
  }

  Future<void> _recordWalletTransaction({
    required double amount,
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('vandizone_wallet').add({
        'amount': amount,
        'type': 'vehicle_registration',
        'status': 'completed',
        'ownerId': _ownerId,
        'ownerCode': _ownerCode,
        'vehicle': {
          'number': _vehicleNumberController.text.trim(),
          'type': selectedVehicleType,
          'bodyType': selectedBodyType?['name'],
        },
        'payment': {
          'paymentId': paymentId,
          'orderId': orderId,
          'signature': signature,
          'mode': 'online',
          'receivedAt': FieldValue.serverTimestamp(),
          'settledAt': null,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error recording wallet transaction: $e');
      rethrow;
    }
  }


  Future<void> _submitForm() async {
    try {
      UiHelper.showLoadingDialog(context, message: "Saving vehicle...");

      final vehicleCode = await _generateVehicleCode(selectedVehicleType!);
      final codeName = selectedVehicleType == 'Truck' ? 'truckcode' : 'bhlcode';

      Map<String, dynamic> vehicleData = {
        'vehicleNumber': _vehicleNumberController.text.trim(),
        'makeModel': _makeModelController.text.trim(),
        'vehicleType': selectedVehicleType!,
        codeName: vehicleCode,
        'engineNumber': _engineNumberController.text.trim(),
        'ownerCode': _ownerCode,
        'ownerId': _ownerId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 0, // 0 for pending approval or active
      };

      if (selectedVehicleType == 'Truck') {
        vehicleData.addAll({
          'rcStartDate': _rcStartDateController.text.trim(),
          'rcEndDate': _rcEndDateController.text.trim(),
          'permitAccess': selectedPermitAccess ?? '',
          'vehicleCategory': selectedVehicleCategory ?? '',
          'bodyType': selectedBodyType?['name'] ?? '',
          'bodyTypeId': selectedBodyType?['id'] ?? '',
          'basePrice': selectedBodyType?['basePrice'] ?? 0.0,
          'capacityRange': selectedBodyType?['capacityRange'] ?? '',
          'numberOfAxles': _axlesController.text.trim(),
          'chassisNumber': _chassisNumberController.text.trim(),
          'registeringDistrict': _districtController.text.trim(),
          'insuredDeclaredValue': _insuredValueController.text.trim(),
          'numberOfTyres': _tyresController.text.trim(),
          'payload': double.tryParse(_payloadController.text.trim()) != null
              ? double.parse((double.parse(_payloadController.text.trim())).toStringAsFixed(3))
              : null,
          'gcw': _gcwController.text.trim(),
          'dimensions': _dimensionsController.text.trim(),
          'vehiclePhotoUrl': await _uploadImage(vehiclePhotoImage),
          'sideViewUrl': await _uploadImage(sideViewImage),
          'rcUrl': await _uploadImage(rcImage),
          'insuranceUrl': await _uploadImage(insuranceImage),
        });
      }

      final collectionName = selectedVehicleType == 'Truck' ? 'trucks' : 'bhl';

      if (widget.vehicleData != null && widget.vehicleData!['id'] != null) {
        await FirebaseFirestore.instance
            .collection(collectionName)
            .doc(widget.vehicleData!['id'])
            .update(vehicleData);
      } else {
        await FirebaseFirestore.instance
            .collection(collectionName)
            .add(vehicleData);
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pushReplacementNamed(context, Routes.vehicleList);
        UiHelper.showSnackBar(context, "Vehicle saved successfully!");
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        UiHelper.showSnackBar(context, "Error saving vehicle: ${e.toString()}");
      }
    }
  }

  Widget _buildImageUploadCard({
    required String title,
    required File? imageFile,
    required String? imageName,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: onPressed,
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
                  child: Text('Choose File'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (imageFile != null) ...[
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      imageFile,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      imageName ?? '',
                      style: TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
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
    return Scaffold(
      appBar: MyAppBar(
        title: widget.vehicleData == null ? 'Add Vehicle' : 'Edit Vehicle',
        actions: [
          if (widget.vehicleData != null)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteVehicle,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyDropdownField<String>(
                header: "Vehicle Type",
                value: selectedVehicleType,
                hintText: "Select vehicle type",
                items: vehicleTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedVehicleType = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select vehicle type';
                  }
                  return null;
                },
              ),
              Gap(15),
              MyTextfield(
                header: 'Vehicle Number',
                controller: _vehicleNumberController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter vehicle number';
                  }
                  return null;
                },
              ),
              Gap(15),
              MyTextfield(
                header: 'Vehicle Make & Model',
                controller: _makeModelController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter make and model';
                  }
                  return null;
                },
              ),
              Gap(15),
              MyTextfield(
                header: 'Engine Number',
                controller: _engineNumberController,
              ),
              Gap(15),
              if(selectedVehicleType == 'Truck')...[
                MyTextfield(
                  header: 'Number of Axles',
                  controller: _axlesController,
                  keyboardType: TextInputType.number,
                ),
                Gap(15),
                MyTextfield(
                  header: 'Chassis Number',
                  controller: _chassisNumberController,
                ),
                Gap(15),
                MyTextfield(
                  header: 'Registering from District',
                  controller: _districtController,
                ),
                Gap(15),
                MyDropdownField<String>(
                  header: "Permit me to Access",
                  value: selectedPermitAccess,
                  hintText: "Select permit access",
                  items: permitAccess.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedPermitAccess = value;
                    });
                  },
                ),
                Gap(15),
                MyTextfield(
                  header: 'Insured Declared Value',
                  controller: _insuredValueController,
                  keyboardType: TextInputType.number,
                ),
                Gap(15),
                MyDropdownField<String>(
                  header: "Vehicle Category",
                  value: selectedVehicleCategory,
                  hintText: "Select vehicle category",
                  items: vehicleCategory.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedVehicleCategory = value;
                    });
                  },
                ),
                Gap(15),
                MyTextfield(
                  header: 'Number of Tyres',
                  controller: _tyresController,
                  keyboardType: TextInputType.number,
                ),
                Gap(15),
                MyTextfield(
                  header: 'Payload (As per Permit in MT)',
                  controller: _payloadController,
                  keyboardType: TextInputType.number,
                ),
                Gap(15),
                MyTextfield(
                  header: 'GCW (As per Permit)',
                  controller: _gcwController,
                  keyboardType: TextInputType.number,
                ),
                Gap(15),
                MyDropdownField<Map<String, dynamic>>(
                  header: "Body Type",
                  value: selectedBodyType,
                  hintText: "Select body type",
                  items: vehicleBodyTypes.map((type) {
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: type,
                      child: Text(type['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedBodyType = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select body type';
                    }
                    return null;
                  },
                ),
                if (selectedBodyType != null) ...[
                  Gap(10),
                  Text(
                    'Base Price: ₹${selectedBodyType!['basePrice']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Gap(5),
                  Text(
                    'Capacity Range: ${selectedBodyType!['capacityRange']}',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                Gap(15),
                MyTextfield(
                  header: 'Truck Dimensions (if any)',
                  controller: _dimensionsController,
                ),
                Gap(15),
                _buildImageUploadCard(
                  title: "Upload Vehicle Photos",
                  imageFile: vehiclePhotoImage,
                  imageName: vehiclePhotoImageName,
                  onPressed: () => _pickImage(
                    onImagePicked: (file, name) {
                      setState(() {
                        vehiclePhotoImage = file;
                        vehiclePhotoImageName = name;
                      });
                    },
                  ),
                ),
                Gap(15),
                _buildImageUploadCard(
                  title: "Side View",
                  imageFile: sideViewImage,
                  imageName: sideViewImageName,
                  onPressed: () => _pickImage(
                    onImagePicked: (file, name) {
                      setState(() {
                        sideViewImage = file;
                        sideViewImageName = name;
                      });
                    },
                  ),
                ),
                Gap(15),
                _buildImageUploadCard(
                  title: "Upload RC",
                  imageFile: rcImage,
                  imageName: rcImageName,
                  onPressed: () => _pickImage(
                    onImagePicked: (file, name) {
                      setState(() {
                        rcImage = file;
                        rcImageName = name;
                      });
                    },
                  ),
                ),
                Gap(15),
                MyTextfield(
                  header: 'FC Start Date',
                  controller: _rcStartDateController,
                  readOnly: true,
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      _rcStartDateController.text = picked.toIso8601String().split('T')[0];
                    }
                  },
                ),
                Gap(15),
                MyTextfield(
                  header: 'FC End Date',
                  controller: _rcEndDateController,
                  readOnly: true,
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      _rcEndDateController.text = picked.toIso8601String().split('T')[0];
                    }
                  },
                ),
                Gap(15),
                _buildImageUploadCard(
                  title: "Upload Insurance",
                  imageFile: insuranceImage,
                  imageName: insuranceImageName,
                  onPressed: () => _pickImage(
                    onImagePicked: (file, name) {
                      setState(() {
                        insuranceImage = file;
                        insuranceImageName = name;
                      });
                    },
                  ),
                ),
              ],
              Gap(15),
              Container(
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(blurRadius: 6, color: black.withOpacity(0.15))
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: MyElevatedButton(
                  title: widget.vehicleData == null
                      ? _isProcessingPayment
                      ? "Processing Payment..."
                      : "Add Vehicle & Pay"
                      : "Update Vehicle",
                  onPressed: _isProcessingPayment ? null : _initiatePayment,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteVehicle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Vehicle'),
        content: Text('Are you sure you want to delete this vehicle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.vehicleData != null) {
      try {
        UiHelper.showLoadingDialog(context, message: "Deleting vehicle...");

        await FirebaseFirestore.instance
            .collection('vehicles')
            .doc(widget.vehicleData!['id'])
            .delete();

        if (mounted) {
          Navigator.pop(context);
          Navigator.pushReplacementNamed(context, Routes.vehicleList);
          UiHelper.showSnackBar(context, "Vehicle deleted successfully!");
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          UiHelper.showSnackBar(context, "Error deleting vehicle: ${e.toString()}");
        }
      }
    }
  }
}