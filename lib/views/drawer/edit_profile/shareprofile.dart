import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vandizone_caption/utils/constant.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import '../../../utils/constant.dart' as PdfColors;


class ShareableProfileView extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const ShareableProfileView({super.key, required this.profileData});

  @override
  State<ShareableProfileView> createState() => _ShareableProfileViewState();
}

class _ShareableProfileViewState extends State<ShareableProfileView>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _shareProfile(BuildContext context) async {
    final pdf = pw.Document();
    final profile = widget.profileData;

    final rating = profile['averageRating'] ?? 0.0;
    final ratingValue = rating is int ? rating.toDouble() : (rating as double? ?? 0.0);
    final ratingText = ratingValue > 0 ? '${ratingValue.toStringAsFixed(1)} ★' : 'No Rating';

    // final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular(); // supports unicode
    // final font = await PdfGoogleFonts.notoSansSymbols();
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final fallbackFont = await PdfGoogleFonts.openSansRegular();

    final textStyle = pw.TextStyle(
      font: baseFont,
      fontFallback: [fallbackFont],
    );


    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${profile['name']}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: font)),
            pw.SizedBox(height: 10),
            pw.Text('Role: ${profile['role']}', style: pw.TextStyle(font: font)),
            pw.Text('Location: ${profile['district']}', style: pw.TextStyle(font: font)),
            pw.Text('Mobile: ${profile['mobile']}', style: pw.TextStyle(font: font)),
            pw.Text('Rating: $ratingText', style: textStyle),
            if (profile['licenseNumber'] != null)
              pw.Text('License: ${profile['licenseNumber']}', style: pw.TextStyle(font: font)),
            pw.SizedBox(height: 20),
            pw.Text('Connect with me today!', style: pw.TextStyle(font: font)),
            pw.Spacer(),
            pw.Divider(),
            pw.Center(
              child: pw.Text('✔ Verified by Vandizone', style: textStyle),
            ),
          ],
        ),
      ),
    );

    final Uint8List pdfBytes = await pdf.save();

    await Printing.sharePdf(bytes: pdfBytes, filename: 'Profile_${profile['name']}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.3)),
            ),
            child: IconButton(
              icon: const Icon(Icons.share, color: Color(0xFF2ECC71)),
              onPressed: () => _shareProfile(context),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 120, left: 20, right: 20, bottom: 20),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 32),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildProfileCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Hero(
          tag: 'profile-image',
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: CircleAvatar(
              radius: 65,
              backgroundImage: NetworkImage(widget.profileData['profileImage'] ?? ''),
              backgroundColor: Colors.grey[300],
              child: widget.profileData['profileImage'] == null
                  ? const Icon(Icons.person, size: 60, color: Colors.white)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.profileData['name'] ?? 'No Name',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.profileData['role']?.toUpperCase() ?? 'USER',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, color: Colors.grey[600], size: 16),
            const SizedBox(width: 6),
            Text(
              widget.profileData['district']?.toString().toUpperCase() ?? 'UNKNOWN LOCATION',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final rating = widget.profileData['averageRating'] ?? 0.0;
    final ratingValue = rating is int ? rating.toDouble() : (rating as double? ?? 0.0);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.star,
            label: 'Rating',
            value: ratingValue > 0 ? ratingValue.toStringAsFixed(1) : '0.0',
            color: const Color(0xFFFFB300),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.calendar_today,
            label: 'Member Since',
            value: _getMemberSince(),
            color: const Color(0xFF2ECC71),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final dateFormat = DateFormat('MMM d, y');
    DateTime? createdAt;
    DateTime? updatedAt;

    try {
      if (widget.profileData['createdAt'] != null) {
        createdAt = (widget.profileData['createdAt'] as Timestamp).toDate();
      }
      if (widget.profileData['updatedAt'] != null) {
        updatedAt = (widget.profileData['updatedAt'] as Timestamp).toDate();
      }
    } catch (e) {
      debugPrint('Error parsing dates: $e');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Profile Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.qr_code, 'User Code', widget.profileData['userCode'] ?? 'N/A'),
            _buildInfoRow(Icons.phone, 'Mobile', widget.profileData['mobile'] ?? 'N/A'),
            if (widget.profileData['dob'] != null)
              _buildInfoRow(Icons.cake, 'Date of Birth', widget.profileData['dob']),
            if (widget.profileData['licenseNumber'] != null)
              _buildInfoRow(Icons.credit_card, 'License Number', widget.profileData['licenseNumber']),
            if (updatedAt != null)
              _buildInfoRow(Icons.update, 'Last Updated', dateFormat.format(updatedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2ECC71), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMemberSince() {
    try {
      if (widget.profileData['createdAt'] != null) {
        final createdAt = (widget.profileData['createdAt'] as Timestamp).toDate();
        return DateFormat('MMM y').format(createdAt);
      }
    } catch (e) {
      debugPrint('Error parsing date: $e');
    }
    return 'N/A';
  }

  Future<void> _launchCaller(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }
}