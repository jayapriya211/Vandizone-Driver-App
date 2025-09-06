import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vandizone_caption/routes/routes.dart';
import 'package:sizer/sizer.dart';
import '../../utils/assets.dart';
import '../../utils/constant.dart';
import '../../widgets/my_elevated_button.dart';
import '../../widgets/my_textfield.dart';
import '../../widgets/my_dropdown.dart';
import '../../widgets/my_imagepicker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
// utils/code_generator.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CodeGenerator {
  static Future<String> generateUserCode(String role) async {
    final currentYear = DateTime.now().year.toString().substring(2);
    final prefix = role == 'owner' ? 'VO' : 'VD';
    final counterDoc = role == 'owner' ? 'owner_codes' : 'captain_codes';

    final firestore = FirebaseFirestore.instance;
    final counterRef = firestore.collection('counters').doc(counterDoc);

    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int currentCount = snapshot.exists ? (snapshot.data()?['count'] ?? 0) : 0;
      currentCount++;

      transaction.set(counterRef, {'count': currentCount}, SetOptions(merge: true));

      return '$prefix${currentYear}${currentCount.toString().padLeft(4, '0')}';
    });
  }
}

class SignUpView extends StatefulWidget {
  const SignUpView({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  int selectedRole = 0; // 0 for captain, 1 for owner
  String? selectedPermitAccess;
  final List<String> permitAccess = ['Zone/Local Use Only', 'Inter-District & Inter-State Allowed'];

  // Text controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();
  final TextEditingController districtController = TextEditingController();
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController branchNameController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController ifscController = TextEditingController();
  final TextEditingController accountHolderController = TextEditingController();

  // Image variables
  File? selfieImage;
  String? selfieImageUrl;
  final ImagePicker _picker = ImagePicker();

  String? captainFeeNote;
  bool isSigningUp = false;

  bool isLoadingFee = true;

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    dobController.dispose();
    licenseController.dispose();
    districtController.dispose();
    bankNameController.dispose();
    branchNameController.dispose();
    accountNumberController.dispose();
    ifscController.dispose();
    accountHolderController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    getCaptainFee();
  }

  Future<void> getCaptainFee() async {
    try {
      final feeDoc = await FirebaseFirestore.instance
          .collection('registrationFeeCharges')
          .limit(1)
          .get();

      if (feeDoc.docs.isEmpty) throw 'Registration fee not set.';

      final data = feeDoc.docs.first.data();
      final fee = data['captain_registration_fee'];

      setState(() {
        captainFeeNote = 'Note: Captain registration fee is ₹$fee';
        isLoadingFee = false;
      });
    } catch (e) {
      setState(() {
        captainFeeNote = 'Note: Registration fee not available';
        isLoadingFee = false;
      });
    }
  }

  Future<String> generateUserCode(String role) async {
    final currentYear = DateTime.now().year.toString().substring(2);
    final prefix = role == 'owner' ? 'VO' : 'VD';
    final counterDoc = role == 'owner' ? 'owner_codes' : 'captain_codes';

    final firestore = FirebaseFirestore.instance;
    final counterRef = firestore.collection('counters').doc(counterDoc);

    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int currentCount = snapshot.exists ? (snapshot.data()?['count'] ?? 0) : 0;
      currentCount++;

      transaction.set(counterRef, {'count': currentCount}, SetOptions(merge: true));

      return '$prefix${currentYear}${currentCount.toString().padLeft(4, '0')}';
    });
  }

  Future<void> _uploadImageAndSignUp() async {

    if (isSigningUp) return; // ⛔ prevent multiple taps

    setState(() {
      isSigningUp = true;
    });

    try {
      // Validate fields
      if (nameController.text.isEmpty || mobileController.text.isEmpty) {
        throw 'Please fill all required fields';
      }

      if (selectedRole == 0 && selfieImage == null) {
        throw 'Please upload your selfie';
      }
      if (selectedRole == 1) {
        if (bankNameController.text.isEmpty ||
            branchNameController.text.isEmpty ||
            accountNumberController.text.isEmpty ||
            ifscController.text.isEmpty) {
          throw 'Please fill all bank details';
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final String userRole = selectedRole == 0 ? 'captain' : 'owner';
      final String userCode = await CodeGenerator.generateUserCode(userRole);
      await prefs.setInt('selectedRole', selectedRole);

      // 🔽 Upload selfie image to Firebase Storage
      if (selectedRole == 0 && selfieImage != null) {
        final fileName = '${mobileController.text}_selfie.jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('user_selfies')
            .child(fileName);

        final uploadTask = await ref.putFile(selfieImage!);
        selfieImageUrl = await ref.getDownloadURL();
      }

      final tempData = {
        'name': nameController.text,
        'mobile': mobileController.text,
        'role': userRole,
        'userCode': userCode,
        if (selectedRole == 0) ...{
          'dob': dobController.text,
          'licenseNumber': licenseController.text,
          'district': districtController.text,
          'profileImage': selfieImageUrl, // ✅ now not null
        },
        if (selectedRole == 1) ...{
          'district': districtController.text,
          'bankName': bankNameController.text,
          'branchName': branchNameController.text,
          'accountNumber': accountNumberController.text,
          'ifscCode': ifscController.text,
          'accountHolderName': accountHolderController.text.isNotEmpty
              ? accountHolderController.text
              : nameController.text, // Use name if account holder not specified
        },
      };

      await FirebaseFirestore.instance
          .collection('temp_registrations')
          .doc(mobileController.text)
          .set(tempData);

      setState(() {
        role = selectedRole;
      });

      Navigator.pushNamed(
        context,
        Routes.otp,
        arguments: {
          'mobile': mobileController.text,
          'userType': userRole,
        },
      );
    } catch (e) {
      print('Error: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          selfieImage = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => dismissKeyBoard(context),
      child: Scaffold(
        body: SizedBox(
          height: 100.h,
          width: 100.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                child: Container(
                  width: 100.w,
                  height: 23.h,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: primary,
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: AssetImage(AssetImages.authbg),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () => Navigator.pop(context),
                                  child: Icon(Icons.arrow_back_ios_new, color: white, size: 20),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Sign Up for Vandizone',
                                    style: whiteSemiBold22,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                top: 19.h,
                child: Container(
                  height: 80.h,
                  width: 100.w,
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.vertical(top: myRadius(20)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  selectedRole = 0;
                                  role = 0;
                                }),
                                child: Container(
                                  padding: EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: selectedRole == 0 ? primary.withOpacity(0.1) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selectedRole == 0 ? primary : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        AssetImages.driver,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                      SizedBox(height: 8),
                                      Text('Captain', style: TextStyle(
                                        color: selectedRole == 0 ? primary : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  selectedRole = 1;
                                  role = 1;
                                }),
                                child: Container(
                                  padding: EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: selectedRole == 1 ? primary.withOpacity(0.1) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selectedRole == 1 ? primary : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        AssetImages.owner1,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                      SizedBox(height: 8),
                                      Text('Owner', style: TextStyle(
                                        color: selectedRole == 1 ? primary : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(20).copyWith(top: 0),
                          physics: BouncingScrollPhysics(),
                          children: [
                            Text('Create your new account', style: blackMedium20),
                            Gap(10),
                            Text('Sign up with following details', style: colorC4Regular16),
                            if (!isLoadingFee && captainFeeNote != null && selectedRole == 0) ...[
                              Gap(10),
                              Text(
                                captainFeeNote!,
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                              ),
                            ],
                            Gap(20),
                            if (selectedRole == 0) ...[
                              Gap(15),
                              MyTextfield(header: 'Name', controller: nameController),
                              Gap(15),
                              MyTextfield(
                                header: 'Mobile',
                                controller: mobileController,
                                keyboardType: TextInputType.phone,
                              ),
                              Gap(15),
                              MyTextfield(
                                header: 'DOB',
                                controller: dobController,
                                readOnly: true,
                                onTap: () async {
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime(2000),
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                  );
                                  if (pickedDate != null) {
                                    dobController.text = "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                                  }
                                },
                                suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                              ),
                              Gap(15),
                              MyTextfield(header: 'Driving License Number', controller: licenseController),
                              Gap(15),
                              MyTextfield(header: 'Registering from District', controller: districtController),
                              Gap(15),
                              // MyDropdownField<String>(
                              //   header: "Permit me to Access",
                              //   value: selectedPermitAccess,
                              //   hintText: "Select permit me to access",
                              //   items: permitAccess.map((type) {
                              //     return DropdownMenuItem<String>(
                              //       value: type,
                              //       child: Text(type),
                              //     );
                              //   }).toList(),
                              //   onChanged: (value) => setState(() => selectedPermitAccess = value),
                              // ),
                              // Gap(15),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Upload Selfie',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => _showImageSourceActionSheet(context),
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
                                  if (selfieImage != null) ...[
                                    Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            selfieImage!,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              )
                            ],
                            if (selectedRole == 1) ...[
                              MyTextfield(header: 'Name', controller: nameController),
                              Gap(15),
                              MyTextfield(
                                header: 'Mobile Number',
                                controller: mobileController,
                                keyboardType: TextInputType.phone,
                              ),
                              Gap(15),
                              MyTextfield(header: 'Registering from District', controller: districtController),
                              Gap(15),
                              // 🔹 Bank Details Section
                              MyTextfield(header: 'Bank Name', controller: bankNameController),
                              Gap(15),
                              MyTextfield(header: 'Branch Name', controller: branchNameController),
                              Gap(15),
                              MyTextfield(header: 'Account Number', controller: accountNumberController, keyboardType: TextInputType.number),
                              Gap(15),
                              MyTextfield(header: 'IFSC Code', controller: ifscController),
                              Gap(15),
                              MyTextfield(header: 'Account Holder Name', controller: accountHolderController),
                              Gap(15),
                              // MyDropdownField<String>(
                              //   header: "Permit me to Access",
                              //   value: selectedPermitAccess,
                              //   hintText: "Select permit me to access",
                              //   items: permitAccess.map((type) {
                              //     return DropdownMenuItem<String>(
                              //       value: type,
                              //       child: Text(type),
                              //     );
                              //   }).toList(),
                              //   onChanged: (value) => setState(() => selectedPermitAccess = value),
                              // ),
                              // Gap(15),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: white,
                          borderRadius: BorderRadius.vertical(top: myRadius(20)),
                          boxShadow: [
                            BoxShadow(blurRadius: 6, color: black.withValues(alpha: 0.15))
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: MyElevatedButton(
                          title: isSigningUp ? "Signing Up..." : "Sign Up",
                          onPressed: isSigningUp ? null : _uploadImageAndSignUp,
                        ),
                      ),
                      // ElevatedButton(
                      //   onPressed: () async {
                      //     await deleteCollection("captains"); // will clear "users" collection
                      //   },
                      //   child: Text("Clear Users"),
                      // )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Camera"),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> deleteCollection(String collectionPath, {int batchSize = 2}) async {
    final collectionRef = FirebaseFirestore.instance.collection(collectionPath);

    while (true) {
      final snapshot = await collectionRef.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

}