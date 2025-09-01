import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:vandizone_caption/utils/icon_size.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vandizone_caption/views/drawer/edit_profile/shareprofile.dart';
import '../../../helper/ui_helper.dart';
import '../../../utils/assets.dart';
import '../../../utils/constant.dart';
import '../../../widgets/my_elevated_button.dart';
import '../../../widgets/my_textfield.dart';
import '../../../widgets/my_dropdown.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  bool isLoading = false;
  bool isInitialLoading = true;
  int selectedRole = 0;
  String? selectedGender;
  String? profileImageUrl;
  final List<String> genderType = ['Male', 'Female', 'Others'];
  final TextEditingController uniqueIDController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();
  final TextEditingController districtController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    await _loadSelectedRole();
    await _loadUserProfile();
    setState(() => isInitialLoading = false);
  }

  void _shareProfile() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final collectionName = selectedRole == 1 ? 'owners' : 'captains';
      final userDoc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return;

      final profileData = userDoc.data()!;
      profileData['role'] = selectedRole == 1 ? 'Owner' : 'Captain';

      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShareableProfileView(profileData: profileData),
          ));
      } catch (e) {
        print('Error sharing profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share profile')),
        );
      }
    }

  Future<void> _loadSelectedRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedRole = prefs.getInt('selectedRole') ?? 0;
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() => isLoading = true);
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final collectionName = selectedRole == 1 ? 'owners' : 'captains';

      final userDoc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return;

      final data = userDoc.data()!;

      setState(() {
        uniqueIDController.text = data['userCode'] ?? '';
        nameController.text = data['name'] ?? '';
        dobController.text = data['dob'] ?? '';
        mobileController.text = data['mobile'] ?? '';
        emailController.text = data['email'] ?? '';
        selectedGender = data['gender'];
        addressController.text = data['address'] ?? '';
        cityController.text = data['city'] ?? '';
        stateController.text = data['state'] ?? '';
        pincodeController.text = data['pincode'] ?? '';
        licenseController.text = data['licenseNumber'] ?? '';
        districtController.text = data['district'] ?? '';
        profileImageUrl = data['profileImage'];
      });
    } catch (e) {
      print('Error loading profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    try {
      setState(() => isLoading = true);
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final collectionName = selectedRole == 1 ? 'owners' : 'captains';

      final data = {
        'name': nameController.text.trim(),
        'dob': dobController.text.trim(),
        'email': emailController.text.trim(),
        'gender': selectedGender,
        'address': addressController.text.trim(),
        'city': cityController.text.trim(),
        'state': stateController.text.trim(),
        'pincode': pincodeController.text.trim(),
        'district': districtController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (selectedRole == 0) {
        data['licenseNumber'] = licenseController.text.trim();
      }

      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(currentUser.uid)
          .update(data);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    try {
      setState(() => isLoading = true);
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final collectionName = selectedRole == 1 ? 'owners' : 'captains';

      // Upload image to Firebase Storage
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${currentUser.uid}.jpg');

      await storageRef.putFile(imageFile);
      final String downloadURL = await storageRef.getDownloadURL();

      // Update Firestore with the new image URL
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(currentUser.uid)
          .update({
        'profileImage': downloadURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        profileImageUrl = downloadURL;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile image updated successfully')),
      );
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: myBorderRadius(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 25),
              margin: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Choose Option', style: blackMedium20),
                  Gap(25),
                  InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        await _uploadProfileImage(File(pickedFile.path));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Image.asset(AssetImages.option2, height: IconSize.regular),
                          Gap(15),
                          Text('Gallery', style: primaryMedium18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20).copyWith(top: 0, bottom: 25),
              child: MyElevatedButton(
                title: 'Cancel',
                bgColor: white,
                textStyle: primaryMedium18,
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildShimmerTextField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 16,
            width: 100,
            color: Colors.grey[300],
            margin: const EdgeInsets.only(bottom: 8),
          ),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerAvatar() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: CircleAvatar(
        radius: 58.5,
        backgroundColor: Colors.grey[300],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: GestureDetector(
        onTap: () => dismissKeyBoard(context),
        child: Scaffold(
          body: Stack(
            children: [
              SizedBox(
                height: 100.h,
                width: 100.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // appBar
                    // In your build method, replace the current app bar section with:
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
                        child: Padding(
                          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      height: 40,
                                      width: 40,
                                      decoration: BoxDecoration(
                                        color: white,
                                        borderRadius: myBorderRadius(10),
                                      ),
                                      child: Icon(Icons.arrow_back_ios_new, color: primary),
                                    ),
                                  ),
                                  Gap(15),
                                  Text('Profile', style: whiteSemiBold22),
                                  Spacer(),
                                  IconButton(
                                    icon: Icon(Icons.share, color: white),
                                    onPressed: _shareProfile,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // form
                    Positioned.fill(
                      top: 21.h,
                      child: Container(
                        height: 80.h,
                        width: 100.w,
                        decoration: BoxDecoration(
                          color: white,
                          borderRadius: BorderRadius.vertical(top: myRadius(20)),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(top: 57.5),
                                child: isInitialLoading
                                    ? Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: ListView(
                                    padding: EdgeInsets.only(top: 38),
                                    physics: NeverScrollableScrollPhysics(),
                                    children: [
                                      _buildShimmerTextField(),
                                      _buildShimmerTextField(),
                                      _buildShimmerTextField(),
                                      _buildShimmerTextField(),
                                      _buildShimmerTextField(),
                                      _buildShimmerTextField(),
                                      _buildShimmerTextField(),
                                      _buildShimmerTextField(),
                                      _buildShimmerTextField(),
                                      _buildShimmerTextField(),
                                      if (selectedRole == 0) _buildShimmerTextField(),
                                      _buildShimmerTextField(),
                                    ],
                                  ),
                                )
                                    : isLoading
                                    ? Center(child: CircularProgressIndicator())
                                    : ListView(
                                  padding: EdgeInsets.only(top: 38),
                                  physics: BouncingScrollPhysics(),
                                  children: [
                                    // MyTextfield(header: 'Unique ID', controller: uniqueIDController, readOnly: true),
                                    // Gap(25),
                                    MyTextfield(header: 'User Name', controller: nameController),
                                    Gap(25),
                                    MyTextfield(
                                      header: 'DOB',
                                      controller: dobController,
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
                                    Gap(25),
                                    MyTextfield(
                                      header: 'Mobile Number',
                                      keyboardType: TextInputType.number,
                                      controller: mobileController,
                                      readOnly: true,
                                    ),
                                    Gap(25),
                                    MyTextfield(header: 'Email ID', controller: emailController),
                                    Gap(25),
                                    MyDropdownField<String>(
                                      header: "Gender",
                                      value: selectedGender,
                                      hintText: "Select Gender",
                                      items: genderType.map((type) {
                                        return DropdownMenuItem<String>(
                                          value: type,
                                          child: Text(type),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedGender = value;
                                        });
                                      },
                                    ),
                                    Gap(25),
                                    MyTextfield(header: 'Address', controller: addressController),
                                    Gap(25),
                                    MyTextfield(header: 'City', controller: cityController),
                                    Gap(25),
                                    MyTextfield(header: 'State', controller: stateController),
                                    Gap(25),
                                    MyTextfield(
                                      header: 'Pincode',
                                      keyboardType: TextInputType.number,
                                      controller: pincodeController,
                                    ),
                                    Gap(25),
                                    if (selectedRole == 0)
                                      MyTextfield(
                                        header: 'Commercial License Number',
                                        controller: licenseController,
                                      ),
                                    if (selectedRole == 0) Gap(15),
                                    MyTextfield(
                                      header: 'Registering from District',
                                      controller: districtController,
                                    ),
                                    Gap(15),
                                  ],
                                ),
                              ),
                            ),
                            if (!isInitialLoading)
                              Container(
                                decoration: BoxDecoration(
                                    color: white,
                                    borderRadius: BorderRadius.vertical(top: myRadius(20)),
                                    boxShadow: [
                                      BoxShadow(blurRadius: 6, color: black.withOpacity(0.15))
                                    ]),
                                padding: const EdgeInsets.all(20),
                                child: MyElevatedButton(
                                  title: "Save",
                                  onPressed: isLoading ? null : _updateProfile,
                                ),
                              )
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 21.h - 58.5,
                      child: isInitialLoading
                          ? _buildShimmerAvatar()
                          : Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _showImagePickerOptions(),
                            child: CircleAvatar(
                              radius: 58.5,
                              backgroundColor: primary,
                              backgroundImage: profileImageUrl != null
                                  ? NetworkImage(profileImageUrl!)
                                  : AssetImage(AssetImages.drawerprofile) as ImageProvider,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _showImagePickerOptions(),
                              child: Container(
                                padding: EdgeInsets.all(10),
                                height: 45,
                                width: 45,
                                decoration: BoxDecoration(
                                  color: primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: white, width: 2),
                                ),
                                child: Image.asset(AssetImages.option1, color: white),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}