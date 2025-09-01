import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../components/my_appbar.dart';
import '../../../utils/constant.dart';
import '../../../utils/icon_size.dart';
import 'package:shimmer/shimmer.dart';

class FAQView extends StatefulWidget {
  const FAQView({super.key});

  @override
  State<FAQView> createState() => _FAQViewState();
}

class _FAQViewState extends State<FAQView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _faqItems = [];
  bool _isLoading = true;
  String?_userType;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadUserTypeAndFAQs();
  }

  Future<void> _loadUserTypeAndFAQs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedRole = prefs.getInt('selectedRole') ?? 0;
      _userType = selectedRole == 0 ? 'driver' : 'vehicleOwner';

      await _fetchFAQsFromFirestore();
    } catch (e) {
      print('Error loading FAQs: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _fetchFAQsFromFirestore() async {
    try {
      final querySnapshot = await _firestore
          .collection('faqs')
          .where('type', isEqualTo: _userType)
          .where('active', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _faqItems = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _faqItems = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'title': data['title'] ?? 'No Title',
            'description': data['description'] ?? 'No Description Available',
            'id': doc.id,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching FAQs: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Widget _buildFAQItem(Map<String, dynamic> faq) {
    return Container(
      decoration: BoxDecoration(
        color: white,
        borderRadius: myBorderRadius(10),
        boxShadow: [boxShadow1],
      ),
      child: ExpansionTile(
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: primary,
        collapsedIconColor: primary,
        childrenPadding: EdgeInsets.all(15).copyWith(top: 2.5),
        shape: RoundedRectangleBorder(borderRadius: myBorderRadius(10)),
        title: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: Colors.green,
              size: IconSize.regular,
            ),
            Gap(10),
            Expanded(
              child: Text(
                faq['title'],
                style: primaryMedium18,
              ),
            ),
          ],
        ),
        children: [
          Text(
            faq['description'],
            style: blackMedium16,
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: 'FAQs'),
      body: _isLoading
          ? _buildShimmerLoader()
          : _hasError
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 40),
            Gap(10),
            Text(
              'Failed to load FAQs',
              style: blackMedium18,
            ),
            Gap(10),
            ElevatedButton(
              onPressed: _loadUserTypeAndFAQs,
              child: Text('Retry'),
              style: ElevatedButton.styleFrom(
                foregroundColor: white,
                backgroundColor: primary,
              ),
            ),
          ],
        ),
      )
          : _faqItems.isEmpty
          ? Center(
        child: Text(
          'No FAQs available for ${_userType == 'driver' ? 'drivers' : 'owners'}',
          style: blackMedium18,
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadUserTypeAndFAQs,
        child: ListView.separated(
          padding: EdgeInsets.all(20).copyWith(top: 5),
          physics: AlwaysScrollableScrollPhysics(),
          itemCount: _faqItems.length,
          separatorBuilder: (_, __) => Gap(25),
          itemBuilder: (context, index) {
            return _buildFAQItem(_faqItems[index]);
          },
        ),
      ),
    );
  }
}