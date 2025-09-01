import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../components/my_appbar.dart';
import '../../../utils/assets.dart';
import '../../../utils/constant.dart';
import '../../../widgets/my_elevated_button.dart';
import '../../../widgets/my_textfield.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../helper/ui_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactUsView extends StatefulWidget {
  const ContactUsView({super.key});

  @override
  State<ContactUsView> createState() => _ContactUsViewState();
}

class _ContactUsViewState extends State<ContactUsView> {
  File? selectedImage;
  String? imageName;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String? _userRole;
  Map<String, dynamic>? _userDetails;

  // Text editing controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // First check SharedPreferences for cached data
      final prefs = await SharedPreferences.getInstance();
      final savedRole = prefs.getInt('selectedRole') ?? 0;
      _userRole = savedRole == 0 ? 'captain' : 'owner';

      // Get saved user details from SharedPreferences
      final savedName = prefs.getString('name');
      final savedMobile = prefs.getString('mobile');
      final savedUserCode = prefs.getString('userCode');

      if (savedName != null && savedMobile != null) {
        // Use saved data if available
        setState(() {
          _nameController.text = savedName;
          // If you have an email field in SharedPreferences, use it here
          _emailController.text = user.email ?? '';
        });

        // Store user details from SharedPreferences
        _userDetails = {
          'name': savedName,
          'phone': savedMobile,
          if (savedUserCode != null) 'customerCode': savedUserCode,
        };
      } else {
        // Fall back to Firestore if no SharedPreferences data
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          _userRole = userDoc['role'] ?? (_userRole ?? 'user');

          // Based on role, check specific collection
          final collectionName = _userRole == 'captain' ? 'captains' : 'owners';
          DocumentSnapshot roleDoc = await FirebaseFirestore.instance
              .collection(collectionName)
              .doc(user.uid)
              .get();

          if (roleDoc.exists) {
            _userDetails = roleDoc.data() as Map<String, dynamic>;
          }

          setState(() {
            _nameController.text = _userDetails?['name'] ?? userDoc['name'] ?? '';
            _emailController.text = user.email ?? _userDetails?['email'] ?? userDoc['email'] ?? '';
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          selectedImage = File(picked.path);
          imageName = picked.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
      );
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageName ?? 'image'}';
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('helpdesk_attachments/$fileName');

      UploadTask uploadTask = storageRef.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _submitHelpRequest() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You need to be logged in to submit a help request')),
        );
        return;
      }

      // Validate required fields
      if (_descriptionController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter your message')),
        );
        return;
      }

      String? imageUrl;
      if (selectedImage != null) {
        imageUrl = await _uploadImage(selectedImage!);
      }

      // Prepare helpdesk data
      Map<String, dynamic> helpdeskData = {
        'attachment': imageUrl,
        'customerId': user.uid,
        'email': _emailController.text.trim(),
        'message': _descriptionController.text.trim(),
        'name': _nameController.text.trim(),
        'status': 0, // 0 = Pending, 1 = In Progress, 2 = Resolved
        'role': _userRole ?? 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add role-specific fields
      if (_userRole == 'captain' && _userDetails != null) {
        helpdeskData.addAll({
          'captainId': user.uid,
          'phone': _userDetails?['phone'] ?? '',
          'vehicleNumber': _userDetails?['vehicleNumber'] ?? '',
        });
      } else if (_userRole == 'owner' && _userDetails != null) {
        helpdeskData.addAll({
          'ownerId': user.uid,
          'phone': _userDetails?['phone'] ?? '',
          'customerCode': _userDetails?['customerCode'] ?? '',
        });
      }

      await FirebaseFirestore.instance.collection('helpdesk').add(helpdeskData);

      UiHelper.showSnackBar(context, "Request submitted successfully!");
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: 'Help Desk'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              children: [
                Container(
                  color: secoBtnColor,
                  padding: EdgeInsets.symmetric(vertical: 25, horizontal: 20),
                  child: Column(
                    children: [
                      Text("Get in Touch", style: primaryMedium20),
                      Gap(15),
                      Text(
                        "If you have any inquiries get in touch with us.\nWe will be happy to help you",
                        style: colorABMedium16.copyWith(height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Gap(25),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Write Your Message', style: blackMedium20),
                      Gap(10),
                      Text(
                        'Describe your issue in detail...',
                        style: colorABRegular16,
                      ),
                      Gap(20),
                      MyTextfield(
                        header: "Full Name",
                        controller: _nameController,
                        readOnly: _nameController.text.isNotEmpty,
                      ),
                      Gap(15),
                      MyTextfield(
                        header: "Email",
                        keyboardType: TextInputType.emailAddress,
                        controller: _emailController,
                        readOnly: _emailController.text.isNotEmpty,
                      ),
                      Gap(15),
                      MyTextfield(
                        header: "Your Message",
                        maxLines: 5,
                        controller: _descriptionController,
                        hintText: 'Please describe your issue in detail...',
                      ),
                      Gap(15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Upload Document',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
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
                                child: Text('Choose File'),
                              ),
                            ],
                          ),
                          if (imageName != null) ...[
                            Gap(10),
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    selectedImage!,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Gap(10),
                                Expanded(
                                  child: Text(
                                    imageName!,
                                    style: TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.vertical(top: myRadius(20)),
              boxShadow: [
                BoxShadow(blurRadius: 6, color: black.withOpacity(0.15))
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: MyElevatedButton(
              title: _isLoading ? 'Submitting...' : 'Submit',
              onPressed: _isLoading ? null : _submitHelpRequest,
            ),
          ),
        ],
      ),
    );
  }
}