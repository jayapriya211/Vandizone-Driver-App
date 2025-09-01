import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../components/my_appbar.dart';
import '../../../utils/constant.dart';
import '../../../utils/icon_size.dart';
import 'package:shimmer/shimmer.dart';

class TermsConditionsView extends StatefulWidget {
  const TermsConditionsView({super.key});

  @override
  State<TermsConditionsView> createState() => _TermsConditionsViewState();
}

class _TermsConditionsViewState extends State<TermsConditionsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _termsItems = [];
  bool _isLoading = true;
  String? _userType; // Default to driver
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadUserTypeAndTerms();
  }

  Future<void> _loadUserTypeAndTerms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedRole = prefs.getInt('selectedRole') ?? 0;
      _userType = selectedRole == 0 ? 'driver' : 'vehicleOwner'; // Changed to match your Firestore 'type'

      await _fetchTermsFromFirestore();
    } catch (e) {
      print('Error loading terms: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _fetchTermsFromFirestore() async {
    try {
      final querySnapshot = await _firestore
          .collection('termsAndConditions')
          .where('type', isEqualTo: _userType)
          .where('active', isEqualTo: true) // Changed to match your Firestore field
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _termsItems = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _termsItems = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'title': data['title'] ?? 'No Title',
            'description': data['description'] ?? 'No Description',
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching terms: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Widget _buildTermItem(Map<String, dynamic> term) {
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
              Icons.description_outlined,
              color: Colors.blue,
              size: IconSize.regular,
            ),
            Gap(10),
            Expanded(
              child: Text(
                term['title'],
                style: primaryMedium18,
              ),
            ),
          ],
        ),
        children: [
          Text(
            term['description'],
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
      child: ListView(
        padding: EdgeInsets.all(20),
        physics: NeverScrollableScrollPhysics(),
        children: List.generate(5, (index) => Padding(
          padding: const EdgeInsets.only(bottom: 25),
          child: Container(
            decoration: BoxDecoration(
              color: white,
              borderRadius: myBorderRadius(10),
              boxShadow: [boxShadow1],
            ),
            padding: EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      color: Colors.white,
                    ),
                    Gap(10),
                    Container(
                      width: 200,
                      height: 24,
                      color: Colors.white,
                    ),
                  ],
                ),
                Gap(10),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: Colors.grey[300],
                ),
                Gap(10),
                Container(
                  width: double.infinity,
                  height: 16,
                  color: Colors.white,
                ),
                Gap(8),
                Container(
                  width: double.infinity,
                  height: 16,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: 'Terms and Conditions'),
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
              'Failed to load terms',
              style: blackMedium18,
            ),
            Gap(10),
            ElevatedButton(
              onPressed: _loadUserTypeAndTerms,
              child: Text('Retry'),
            ),
          ],
        ),
      )
          : _termsItems.isEmpty
          ? Center(
        child: Text(
          'No terms available for $_userType',
          style: blackMedium18,
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadUserTypeAndTerms,
        child: ListView.separated(
          padding: EdgeInsets.all(20).copyWith(top: 5),
          physics: AlwaysScrollableScrollPhysics(),
          itemCount: _termsItems.length,
          separatorBuilder: (_, __) => Gap(15),
          itemBuilder: (context, index) {
            return _buildTermItem(_termsItems[index]);
          },
        ),
      ),
    );
  }
}