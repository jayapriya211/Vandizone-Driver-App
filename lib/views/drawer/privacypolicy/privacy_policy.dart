import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../../../components/my_appbar.dart';
import '../../../utils/constant.dart';

class PrivacyPolicyView extends StatefulWidget {
  const PrivacyPolicyView({super.key});

  @override
  State<PrivacyPolicyView> createState() => _PrivacyPolicyViewState();
}

class _PrivacyPolicyViewState extends State<PrivacyPolicyView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _policyItems = [];
  bool _isLoading = true;
  String? _userType;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadUserTypeAndPolicies();
  }

  Future<void> _loadUserTypeAndPolicies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedRole = prefs.getInt('selectedRole') ?? 0;
      _userType = selectedRole == 0 ? 'driver' : 'vehicleOwner';

      await _fetchPoliciesFromFirestore();
    } catch (e) {
      print('Error loading policies: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _fetchPoliciesFromFirestore() async {
    try {
      final querySnapshot = await _firestore
          .collection('privacyPolicies')
          .where('type', isEqualTo: _userType)
          .where('active', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _policyItems = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _policyItems = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'title': data['title'] ?? 'No Title',
            'description': data['description'] ?? 'No Content Available',
            'id': doc.id,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching policies: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Widget _buildPolicyItem(Map<String, dynamic> policy) {
    return Container(
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
              Icon(
                Icons.privacy_tip_outlined,
                color: Colors.blue,
                size: 16,
              ),
              Gap(10),
              Text(
                policy['title'],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ],
          ),
          Gap(10),
          Divider(color: Colors.grey[300]),
          Gap(10),
          Text(
            policy['description'],
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
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
      appBar: MyAppBar(title: 'Privacy Policy'),
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
              'Failed to load privacy policy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Gap(10),
            ElevatedButton(
              onPressed: _loadUserTypeAndPolicies,
              child: Text('Retry'),
              style: ElevatedButton.styleFrom(
                foregroundColor: white,
                backgroundColor: primary,
              ),
            ),
          ],
        ),
      )
          : _policyItems.isEmpty
          ? Center(
        child: Text(
          'No privacy policy available for ${_userType == 'driver' ? 'drivers' : 'vehicle owners'}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadUserTypeAndPolicies,
        child: ListView(
          padding: EdgeInsets.all(20),
          physics: BouncingScrollPhysics(),
          children: [
            ..._policyItems.map((policy) => Padding(
              padding: const EdgeInsets.only(bottom: 25),
              child: _buildPolicyItem(policy),
            )),
          ],
        ),
      ),
    );
  }
}