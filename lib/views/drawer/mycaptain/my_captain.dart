import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../../../widgets/uppercase.dart';
// Replace these with your actual imports
import '../../../components/my_appbar.dart';
import '../../../utils/assets.dart';
import '../../../utils/constant.dart';
import '../../../utils/icon_size.dart';
import '../../../widgets/my_textfield.dart';
import 'package:vandizone_caption/widgets/my_elevated_button.dart';

class MyCaptainListView extends StatefulWidget {
  const MyCaptainListView({super.key});

  @override
  State<MyCaptainListView> createState() => _MyCaptainListViewState();
}

class _MyCaptainListViewState extends State<MyCaptainListView> {
  List<Map<String, dynamic>> captains = [];
  bool _isLoading = true;
  String? _ownerUserCode;

  @override
  void initState() {
    super.initState();
    _loadOwnerData();
    _loadCaptains();
  }

  Future<void> _loadOwnerData() async {
    final prefs = await SharedPreferences.getInstance();
    _ownerUserCode = prefs.getString('userCode');
  }

  Future<void> _loadCaptains() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('my_captains')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      List<Map<String, dynamic>> loadedCaptains = [];

      for (var doc in querySnapshot.docs) {
        // Get full captain details from captains collection
        final captainDoc = await FirebaseFirestore.instance
            .collection('captains')
            .doc(doc['captainId'])
            .get();

        if (captainDoc.exists) {
          loadedCaptains.add({
            ...captainDoc.data() as Map<String, dynamic>,
            'id': doc.id, // document ID from my_captains collection
            'isActive': doc['isActive'] ?? false,
          });
        }
      }

      setState(() {
        captains = loadedCaptains;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading captains: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(child: _buildShimmerLoader()),
        ),
      );
    }

    return Scaffold(
      appBar: _appBar(context),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: captains.length,
        itemBuilder: (context, index) {
          final captain = captains[index];
          final isActive = captain['isActive'] ?? false;

          // Determine which image to use
          final profileImageUrl = (captain['profileImage'] ?? '').trim();
          final image = profileImageUrl.isNotEmpty
              ? NetworkImage(profileImageUrl)
              : AssetImage(AssetImages.pastride1) as ImageProvider;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [boxShadow1],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Captain Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image(
                    image: image,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const Gap(12),
                // Captain Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Unique ID
                      Text("${captain['userCode']}", style: colorABRegular16),
                      const Gap(4),
                      // Captain name
                      Text(captain['name'], style: primarySemiBold18),
                      const Gap(4),
                      // Mobile number
                      Text("${captain['mobile']}", style: blackRegular16),
                      if (isActive && captain['vehicleNumber'] != null)
                        Text("${captain['vehicleNumber']}", style: blackRegular16),
                      const Gap(4),
                      // Star Rating with numeric value
                      Row(
                        children: [
                          StarRating(
                            rating: (captain['rating'] ?? 0.0).toDouble(),
                            starSize: 16,
                          ),
                          const Gap(4),
                          Text(
                            '(${(captain['rating'] ?? 0.0).toStringAsFixed(1)})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Active status and delete button
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? Color(0xffE8F5E9) : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isActive ? "Active" : "Inactive",
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteConfirmation(context, index),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  AppBar _appBar(BuildContext context) {
    return AppBar(
      backgroundColor: white,
      elevation: 0,
      toolbarHeight: kToolbarHeight + 20,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: myBorderRadius(10),
                    boxShadow: [boxShadow1],
                  ),
                  child: Icon(Icons.arrow_back_ios_new, color: black, size: IconSize.regular),
                ),
              ),
              const Gap(15),
              Expanded(child: Text('My Captains', style: blackMedium20)),
              IconButton(
                icon: Icon(Icons.add, color: primary),
                onPressed: () {
                  _showUniqueIdBottomSheet(context);
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.separated(
        padding: EdgeInsets.all(20).copyWith(top: 5),
        physics: NeverScrollableScrollPhysics(),
        itemCount: 5, // Show 5 shimmer items as placeholder
        separatorBuilder: (_, __) => Gap(25),
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: white,
              borderRadius: myBorderRadius(10),
              boxShadow: [boxShadow1],
            ),
            child: Column(
              children: [
                // Header with icon and title
                Container(
                  padding: EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Container(
                        width: IconSize.regular,
                        height: IconSize.regular,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Gap(10),
                      Expanded(
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Divider
                Container(
                  height: 1,
                  color: Colors.grey[300],
                ),
                // Content
                Container(
                  padding: EdgeInsets.all(15).copyWith(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Gap(8),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Gap(8),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Delete Captain?",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "Are you sure you want to delete ${captains[index]['name']}?",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: MyElevatedButton(
                    title: 'Cancel',
                    isSecondary: true,
                    bgColor: Colors.red.shade100, // Light red background
                    textStyle: TextStyle(
                      color: Colors.red, // Red text
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: MyElevatedButton(
                    bgColor: Colors.red,
                    title: 'Delete',
                    onPressed: () {
                      _deleteCaptain(index);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCaptain(int index) async {
    final captain = captains[index];
    setState(() => _isLoading = true);

    try {
      // Delete from my_captains collection
      await FirebaseFirestore.instance
          .collection('my_captains')
          .doc(captain['id'])
          .delete();

      // Update local list
      setState(() {
        captains.removeAt(index);
      });

      Navigator.pop(context); // Close the bottom sheet

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captain removed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing captain: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showUniqueIdBottomSheet(BuildContext context) {
    final TextEditingController idController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              const Text(
                "Enter Captain Unique ID",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // Input field
              MyTextfield(
                header: 'Captain Unique ID',
                controller: idController,
                inputFormatters: [
                  UpperCaseTextFormatter(),
                ],
                readOnly: false,
              ),
              const SizedBox(height: 30),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: MyElevatedButton(
                      title: 'Cancel',
                      isSecondary: true,
                      onPressed: () async {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: MyElevatedButton(
                      title: 'Submit',
                      onPressed: () {
                        if (idController.text.isNotEmpty) {
                          _addCaptain(idController.text.trim());
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addCaptain(String uniqueId) async {
    if (uniqueId.isEmpty) return;
    if (_ownerUserCode == null) return;

    Navigator.pop(context); // Close bottom sheet
    setState(() => _isLoading = true);

    try {
      // 1. Find captain by uniqueId in captains collection
      final querySnapshot = await FirebaseFirestore.instance
          .collection('captains')
          .where('userCode', isEqualTo: uniqueId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Captain not found with this ID');
      }

      final captainData = querySnapshot.docs.first;
      final captainId = captainData.id;
      final currentUser = FirebaseAuth.instance.currentUser;

      // 2. Check if already added
      final existing = await FirebaseFirestore.instance
          .collection('my_captains')
          .where('ownerId', isEqualTo: currentUser?.uid)
          .where('captainId', isEqualTo: captainId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception('This captain is already in your list');
      }

      // 3. Add to my_captains collection
      await FirebaseFirestore.instance.collection('my_captains').add({
        'ownerId': currentUser?.uid,
        'ownerUserCode': _ownerUserCode,
        'captainId': captainId,
        'captainUserCode': uniqueId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Reload the list
      await _loadCaptains();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captain added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding captain: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleCaptainStatus(int index) async {
    final captain = captains[index];
    final newStatus = !(captain['isActive'] ?? false);
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('my_captains')
          .doc(captain['id'])
          .update({
        'isActive': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local list
      setState(() {
        captains[index]['isActive'] = newStatus;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// Star Rating Widget
class StarRating extends StatelessWidget {
  final double rating;
  final double starSize;
  final Color color;

  const StarRating({
    super.key,
    required this.rating,
    this.starSize = 16,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor()
              ? Icons.star
              : (index < rating ? Icons.star_half : Icons.star_border),
          size: starSize,
          color: color,
        );
      }),
    );
  }
}