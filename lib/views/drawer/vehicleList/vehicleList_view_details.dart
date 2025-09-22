import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/vehicleList.dart';
import '../../../utils/assets.dart';
import '../../../utils/constant.dart';
import '../../../utils/icon_size.dart';
import '../../../widgets/my_elevated_button.dart';

class VehicleDetailsPage extends StatelessWidget {
  final Vehicle vehicle;

  const VehicleDetailsPage({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Image and Basic Info
            _buildVehicleHeader(context),
            const Gap(20),

            // All information sections
            _buildInfoCard(
              title: 'Basic Information',
              children: [
                _infoPairRow('Make', vehicle.make, 'Model', vehicle.model),
                const Gap(10),
                _infoPairRow('License Plate', vehicle.licensePlate, 'Vehicle Number', vehicle.vehicleNumber),
                const Gap(10),
                _infoPairRow('Vehicle Type', vehicle.vehicleTypeDisplay, 'Category', vehicle.vehicleCategory),
                const Gap(10),
                _infoPairRow('Body Type', vehicle.bodyType, 'Color', vehicle.color),
                const Gap(10),
                _infoPairRow('Year', vehicle.year.toString(), 'Status', vehicle.isActive ? 'Active' : 'Inactive'),
                const Gap(10),
                _infoPairRow('Vehicle Code', vehicle.vehicleCode, 'Registration District', vehicle.registeringDistrict),
              ],
            ),
            const Gap(20),

            // Technical Specifications
            _buildInfoCard(
              title: 'Technical Specifications',
              children: [
                _infoPairRow('Engine Number', vehicle.engineNumber, 'Chassis Number', vehicle.chassisNumber),
                const Gap(10),
                _infoPairRow('Number of Axles', vehicle.numberOfAxles, 'Number of Tyres', vehicle.numberOfTyres),
                const Gap(10),
                _infoPairRow('Payload Capacity', '${vehicle.payload} kg', 'GCW', '${vehicle.gcw} kg'),
                const Gap(10),
                _infoPairRow('Dimensions', vehicle.truckDimensions, 'Insured Value', '₹${vehicle.insuredValue}'),
                const Gap(10),
                _infoPairRow('Permit Access', vehicle.permitAccess, '', ''),
              ],
            ),
            const Gap(20),

            // Documents Section
            _buildDocumentsSection(),
            const Gap(20),

            // Assigned Captains Section
            if (vehicle.assignedCaptains != null && vehicle.assignedCaptains!.isNotEmpty)
              _buildCaptainsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: _buildImageWithShimmer(vehicle.imageUrl),
          ),
        ),
        const Gap(15),
        Text(
          '${vehicle.make} ${vehicle.model}',
          style: blackSemiBold20.copyWith(fontSize: 22),
          textAlign: TextAlign.center,
        ),
        const Gap(5),
        Text(
          vehicle.licensePlate,
          style: blackMedium16.copyWith(color: grey),
        ),
      ],
    );
  }

  Widget _buildImageWithShimmer(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Image.asset(
        AssetImages.pastride1,
        fit: BoxFit.cover,
      );
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;

          // While loading, show shimmer
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Image.asset(
          AssetImages.pastride1,
          fit: BoxFit.cover,
        ),
      );
    } else {
      // For local image paths
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          AssetImages.pastride1,
          fit: BoxFit.cover,
        ),
      );
    }
  }

  Widget _buildDocumentsSection() {
    return _buildInfoCard(
      title: 'Documents',
      children: [
        if (vehicle.rcUrl.isNotEmpty)
          _buildDocumentTile('Registration Certificate', vehicle.rcUrl!),
        if (vehicle.insuranceUrl.isNotEmpty)
          _buildDocumentTile('Insurance Document', vehicle.insuranceUrl!),
        if ((vehicle.rcUrl.isEmpty) &&
            (vehicle.insuranceUrl.isEmpty))
          Text('No documents available', style: blackRegular16),
      ],
    );
  }

  Widget _buildDocumentTile(String title, String url) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child:  Icon(Icons.description, color: primary),
      ),
      title: Text(title, style: blackMedium14),
      trailing: IconButton(
        icon:  Icon(Icons.open_in_new, color: primary),
        onPressed: () => _launchUrl(url),
      ),
    );
  }

  Widget _buildCaptainsSection() {
    return _buildInfoCard(
      title: 'Assigned Captains',
      children: [
        ...vehicle.assignedCaptains!.map((captain) => _buildCaptainTile(captain)).toList(),
      ],
    );
  }

  Widget _buildCaptainTile(Captain captain) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage: (captain.imageUrl != null && captain.imageUrl!.isNotEmpty)
            ? NetworkImage(captain.imageUrl!)
            : AssetImage(AssetImages.pastride1) as ImageProvider,
      ),
      title: Text(captain.name, style: blackMedium14),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${captain.id}', style: blackRegular16),
          Text('Phone: ${captain.phone}', style: blackRegular16),
          if (captain.email != null) Text('Email: ${captain.email}', style: blackRegular16),
        ],
      ),
      trailing: IconButton(
        icon: Icon(Icons.phone, color: primary),
        onPressed: () => _callCaptain(captain.phone),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _callCaptain(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
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
              Expanded(child: Text('Vehicle Details', style: blackMedium20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [boxShadow1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: blackSemiBold16.copyWith(color: primary),
          ),
          const Gap(15),
          ...children,
        ],
      ),
    );
  }

  Widget _infoPairRow(String label1, String value1, String label2, String value2) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: _labeledText(label1, value1)),
        if (label2.isNotEmpty) const Gap(10),
        if (label2.isNotEmpty) Expanded(child: _labeledText(label2, value2)),
      ],
    );
  }

  Widget _labeledText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: colorABRegular14),
        const Gap(4),
        Text(
          value.isNotEmpty ? value : 'N/A',
          style: blackMedium14,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}