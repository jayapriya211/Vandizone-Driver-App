import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../utils/assets.dart';
import '../../../utils/constant.dart';
import '../../../utils/icon_size.dart';
import '../../../components/my_appbar.dart';
import '../../../routes/routes.dart';
import '../../../models/vehicleList.dart';
import '../../../widgets/my_elevated_button.dart';
import '../../../widgets/my_textfield.dart';
import '../../../widgets/switch.dart';
import 'vehicleList_view_details.dart';
import '../../../widgets/uppercase.dart';

class VehicleListView extends StatefulWidget {
  const VehicleListView({super.key});

  @override
  State<VehicleListView> createState() => _VehicleListViewState();
}

class _VehicleListViewState extends State<VehicleListView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Captain> _availableCaptains = [];
  String? _ownerId;
  String? _ownerUserCode;
  bool _isAddingCaptain = false;
  bool _isCaptainListExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchOwnerId();
  }

  Future<void> _fetchVehicles() async {
    try {
      setState(() => _isLoading = true);

      final [truckSnapshot, bhlSnapshot] = await Future.wait([
        _firestore.collection('trucks').where('ownerId', isEqualTo: _ownerId).get(),
        _firestore.collection('bhl').where('ownerId', isEqualTo: _ownerId).get(),
      ]);

      final trucks = truckSnapshot.docs.map((doc) {
        final data = doc.data();
        return Vehicle(
          id: doc.id,
          isTruck: true,
          make: data['makeModel']?.split(' ').first ?? '',
          licensePlate: data['vehicleNumber'] ?? '',
          model: data['makeModel']?.split(' ').skip(1).join(' ') ?? '',
          color: data['color'] ?? 'Unknown',
          year: int.tryParse(data['year']?.toString() ?? '') ?? 0,
          vehicleType: data['vehicleType'] ?? 'Truck',
          vehicleCategory: data['vehicleCategory'] ?? '',
          bodyType: data['bodyType'] ?? '',
          vehicleNumber: data['vehicleNumber'] ?? '',
          numberOfAxles: data['numberOfAxles']?.toString() ?? '',
          engineNumber: data['engineNumber'] ?? '',
          chassisNumber: data['chassisNumber'] ?? '',
          insuredValue: data['insuredDeclaredValue']?.toString() ?? '',
          numberOfTyres: data['numberOfTyres']?.toString() ?? '',
          payload: data['payload']?.toString() ?? '',
          gcw: data['gcw']?.toString() ?? '',
          truckDimensions: data['dimensions']?.toString() ?? '',
          isActive: data['status'] == 0,
          assignedCaptains: _parseCaptains(data['assignCaptains']),
          imageUrl: data['vehiclePhotoUrl'] ?? AssetImages.pastride1,
          vehicleCode: data['truckcode'] ?? '',
          rcUrl: data['rcUrl'] ?? '',
          insuranceUrl: data['insuranceUrl'] ?? '',
          permitAccess: data['permitAccess'] ?? '',
          registeringDistrict: data['registeringDistrict'] ?? '',
        );
      }).toList();

      final bhls = bhlSnapshot.docs.map((doc) {
        final data = doc.data();
        return Vehicle(
          id: doc.id,
          isBackhoe: true,
          make: data['makeModel']?.split(' ').first ?? '',
          licensePlate: data['vehicleNumber'] ?? '',
          model: data['makeModel']?.split(' ').skip(1).join(' ') ?? '',
          color: data['color'] ?? 'Unknown',
          year: int.tryParse(data['year']?.toString() ?? '') ?? 0,
          vehicleType: data['vehicleType'] ?? 'Backhoe Loader',
          vehicleCategory: data['vehicleCategory'] ?? '',
          bodyType: data['bodyType'] ?? '',
          vehicleNumber: data['vehicleNumber'] ?? '',
          numberOfAxles: data['numberOfAxles']?.toString() ?? '',
          engineNumber: data['engineNumber'] ?? '',
          chassisNumber: data['chassisNumber'] ?? '',
          insuredValue: data['insuredDeclaredValue']?.toString() ?? '',
          numberOfTyres: data['numberOfTyres']?.toString() ?? '',
          payload: data['payload']?.toString() ?? '',
          gcw: data['gcw']?.toString() ?? '',
          truckDimensions: data['dimensions']?.toString() ?? '',
          isActive: data['status'] == 0,
          assignedCaptains: _parseCaptains(data['assignCaptains']),
          imageUrl: data['vehiclePhotoUrl'] ?? AssetImages.pastride1,
          vehicleCode: data['bhlcode'] ?? '',
          rcUrl: data['rcUrl'] ?? '',
          insuranceUrl: data['insuranceUrl'] ?? '',
          permitAccess: data['permitAccess'] ?? '',
          registeringDistrict: data['registeringDistrict'] ?? '',
        );
      }).toList();

      setState(() {
        _vehicles = [...trucks, ...bhls];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching vehicles: $e')),
      );
    }
  }

  List<Captain>? _parseCaptains(dynamic assignCaptains) {
    if (assignCaptains == null) return null;
    if (assignCaptains is! List) return null;

    return assignCaptains.map((c) => Captain(
      name: c['name'] ?? '',
      id: c['id'] ?? '',
      phone: c['phone']?.toString() ?? '',
      email: c['email'] ?? '',
    )).toList();
  }

  Future<void> _fetchOwnerId() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() => _ownerId = user.uid);
      await _fetchOwnerUserCode();
      await _fetchCaptains();
      await _fetchVehicles();
    }
  }

  Future<void> _fetchOwnerUserCode() async {
    if (_ownerId == null) return;

    try {
      final doc = await _firestore.collection('owners').doc(_ownerId).get();
      if (doc.exists) {
        setState(() => _ownerUserCode = doc['userCode']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching owner code: $e')),
      );
    }
  }

  Future<void> _fetchCaptains() async {
    if (_ownerId == null) return;

    try {
      setState(() => _isLoading = true);

      final querySnapshot = await _firestore
          .collection('my_captains')
          .where('ownerId', isEqualTo: _ownerId)
          .get();

      final captains = await Future.wait(querySnapshot.docs.map((doc) async {
        final captainDoc = await _firestore
            .collection('captains')
            .doc(doc['captainId'])
            .get();

        if (captainDoc.exists) {
          return Captain(
            name: captainDoc['name'] ?? 'Unknown',
            id: captainDoc['userCode'] ?? 'Unknown',
            phone: captainDoc['mobile'] ?? 'Unknown',
            // email: captainDoc['email'],
            imageUrl: captainDoc['profileImage'],
            captainId: doc.id,
            isAssigned: doc['is_assign'] ?? false,
          );
        }
        return null;
      }));

      setState(() {
        _availableCaptains = captains.whereType<Captain>().toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching captains: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateVehicleStatus(Vehicle vehicle, bool newStatus) async {
    try {
      final collection = vehicle.isTruck ? 'trucks' : 'bhl';
      await _firestore.collection(collection).doc(vehicle.id).update({
        'status': newStatus ? 0 : 1,
        'updated_at': FieldValue.serverTimestamp(),
      });

      setState(() {
        vehicle.isActive = newStatus;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  Future<void> _assignMultipleCaptains(Vehicle vehicle, List<Captain> captains) async {
    try {
      setState(() => _isAddingCaptain = true);

      final collection = vehicle.isTruck ? 'trucks' : 'bhl';
      final assignData = captains.map((c) => c.toMap()).toList();

      // Update vehicle document
      await _firestore.collection(collection).doc(vehicle.id).update({
        'assignCaptains': assignData,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update each captain's status
      for (final captain in captains) {
        // Update in captains collection
        final captainQuery = await _firestore
            .collection('captains')
            .where('userCode', isEqualTo: captain.id)
            .limit(1)
            .get();

        if (captainQuery.docs.isNotEmpty) {
          await captainQuery.docs.first.reference.update({
            'is_assign': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Update in my_captains collection
        final myCaptainQuery = await _firestore
            .collection('my_captains')
            .where('ownerId', isEqualTo: _ownerId)
            .where('captainUserCode', isEqualTo: captain.id)
            .limit(1)
            .get();

        if (myCaptainQuery.docs.isNotEmpty) {
          await myCaptainQuery.docs.first.reference.update({
            'is_assign': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Add to my_captains if not exists
          await _firestore.collection('my_captains').add({
            'ownerId': _ownerId,
            'ownerUserCode': _ownerUserCode,
            'captainId': captainQuery.docs.isNotEmpty ? captainQuery.docs.first.id : '',
            'captainUserCode': captain.id,
            'isActive': true,
            'is_assign': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Update local state
      setState(() {
        vehicle.assignedCaptains = captains;
        _isAddingCaptain = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captains assigned successfully')),
      );
    } catch (e) {
      setState(() => _isAddingCaptain = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning captains: $e')),
      );
    }
  }

  Future<void> _removeCaptain(Vehicle vehicle, Captain captain) async {
    try {
      setState(() => _isLoading = true);

      final collection = vehicle.isTruck ? 'trucks' : 'bhl';

      // Remove from vehicle
      await _firestore.collection(collection).doc(vehicle.id).update({
        'assignCaptains': FieldValue.arrayRemove([captain.toMap()]),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update captain status
      final captainQuery = await _firestore
          .collection('captains')
          .where('userCode', isEqualTo: captain.id)
          .limit(1)
          .get();

      if (captainQuery.docs.isNotEmpty) {
        await captainQuery.docs.first.reference.update({
          'is_assign': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update my_captains status
      final myCaptainQuery = await _firestore
          .collection('my_captains')
          .where('ownerId', isEqualTo: _ownerId)
          .where('captainUserCode', isEqualTo: captain.id)
          .limit(1)
          .get();

      if (myCaptainQuery.docs.isNotEmpty) {
        await myCaptainQuery.docs.first.reference.update({
          'is_assign': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update local state
      setState(() {
        vehicle.assignedCaptains?.removeWhere((c) => c.id == captain.id);
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captain removed successfully')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing captain: $e')),
      );
    }
  }

  Future<void> _callCaptain(Captain captain) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: captain.phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app')),
      );
    }
  }

  void _navigateToVehicleDetails(Vehicle vehicle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleDetailsPage(vehicle: vehicle),
      ),
    );
  }

  void _showCaptainAssignmentBottomSheet(Vehicle vehicle) {
    TextEditingController searchController = TextEditingController();
    List<Captain> selectedCaptains = vehicle.assignedCaptains ?? [];
    List<Captain> filteredCaptains = List.from(_availableCaptains);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Assign Captains to ${vehicle.make} ${vehicle.model}',
                        style: blackSemiBold18,
                      ),
                      const Gap(15),

                      // Search Field
                      MyTextfield(
                        header: 'Search Captains',
                        controller: searchController,
                        onChanged: (value) async {
                          if (value.length >= 3) {
                            try {
                              final querySnapshot = await _firestore
                                  .collection('captains')
                                  .where('userCode', isGreaterThanOrEqualTo: value)
                                  .where('userCode', isLessThanOrEqualTo: '$value\uf8ff')
                                  .get();

                              final fetchedCaptains = querySnapshot.docs.map((doc) {
                                final data = doc.data();
                                return Captain(
                                  name: data['name'] ?? '',
                                  id: data['userCode'] ?? '',
                                  phone: data['mobile'] ?? '',
                                  email: data['email'] ?? '',
                                  captainId: doc.id,
                                  imageUrl: data['profileImage'] ?? '',
                                );
                              }).toList();

                              setState(() {
                                filteredCaptains = fetchedCaptains;
                              });
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error fetching captains: $e")),
                              );
                            }
                          } else {
                            setState(() => filteredCaptains = List.from(_availableCaptains));
                          }
                        },
                      ),

                      const Gap(15),
                      Text('Available Captains', style: blackMedium16),
                      const Gap(10),

                      // Captain List
                      Expanded(
                        child: filteredCaptains.isEmpty
                            ? Center(child: Text("No captains found"))
                            : ListView.builder(
                          itemCount: filteredCaptains.length,
                          itemBuilder: (context, index) {
                            final captain = filteredCaptains[index];
                            final isSelected = selectedCaptains.any((c) => c.id == captain.id);

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: (captain.imageUrl != null && captain.imageUrl!.isNotEmpty)
                                    ? NetworkImage(captain.imageUrl!)
                                    : AssetImage(AssetImages.pastride1) as ImageProvider,
                              ),
                              title: Text(captain.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${captain.id} | Phone: ${captain.phone}'),
                                  if (captain.email != null)
                                    Text(captain.email!, style: TextStyle(fontSize: 12)),
                                ],
                              ),
                              tileColor: isSelected ? primary.withOpacity(0.1) : null,
                              shape: isSelected
                                  ? RoundedRectangleBorder(
                                side: BorderSide(color: primary, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              )
                                  : null,
                              trailing: Icon(
                                isSelected ? Icons.check_circle : Icons.circle_outlined,
                                color: isSelected ? primary : grey,
                              ),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    selectedCaptains.removeWhere((c) => c.id == captain.id);
                                  } else {
                                    selectedCaptains.add(captain);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),

                      // Bottom Buttons
                      Row(
                        children: [
                          Expanded(
                            child: MyElevatedButton(
                              title: 'Cancel',
                              isSecondary: true,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: MyElevatedButton(
                              title: 'Assign',
                              onPressed: () async {
                                if (selectedCaptains.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Please select at least one captain")),
                                  );
                                  return;
                                }

                                await _assignMultipleCaptains(vehicle, selectedCaptains);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(Vehicle vehicle, Captain captain) {
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
              "Remove Captain?",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "Are you sure you want to remove ${captain.name} from this vehicle?",
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
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: MyElevatedButton(
                    bgColor: Colors.red,
                    title: 'Remove',
                    onPressed: () async {
                      Navigator.pop(context);
                      await _removeCaptain(vehicle, captain);
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

  Widget _infoIconRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: grey),
        const Gap(6),
        Text(text, style: blackRegular16),
      ],
    );
  }

  Widget _buildVehicleCard(Vehicle vehicle) {
    return GestureDetector(
      onTap: () => _navigateToVehicleDetails(vehicle),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [boxShadow1],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  vehicle.isTruck ? Icons.local_shipping : Icons.construction,
                  size: 30,
                  color: primary,
                ),
                const Gap(10),
                Expanded(
                  child: Row(
                    children: [
                      Text('${vehicle.make} ${vehicle.model}', style: blackSemiBold18,overflow: TextOverflow.ellipsis,),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          vehicle.vehicleTypeDisplay,
                          style: TextStyle(
                            color: primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                CustomIosSwitch(
                  value: vehicle.isActive,
                  onChanged: (newValue) => _updateVehicleStatus(vehicle, newValue),
                ),
              ],
            ),
            const Gap(15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoIconRow(Icons.confirmation_number, vehicle.engineNumber),
                _infoIconRow(Icons.directions_car, vehicle.vehicleNumber),
              ],
            ),
            const Gap(10),
            const Divider(thickness: 1, color: grey),
            const Gap(10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (vehicle.assignedCaptains != null && vehicle.assignedCaptains!.isNotEmpty) ...[
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              ...(_isCaptainListExpanded
                                  ? vehicle.assignedCaptains!
                                  : [vehicle.assignedCaptains!.first]
                              ).map((captain) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(Icons.person, color: primary),
                                          const Gap(10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Captain: ${captain.name}",
                                                  style: blackMedium16.copyWith(color: Colors.green),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "${captain.id}",
                                                  style: blackRegular16.copyWith(color: Colors.grey[600]),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!vehicle.isActive)
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: primary.withOpacity(0.1),
                                            child: IconButton(
                                              icon: Icon(Icons.phone, size: 16, color: primary),
                                              onPressed: () => _callCaptain(captain),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Colors.red.withOpacity(0.1),
                                            child: IconButton(
                                              icon: Icon(Icons.delete, size: 16, color: Colors.red),
                                              onPressed: () => _showDeleteConfirmation(vehicle, captain),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              )).toList(),

                              if (vehicle.assignedCaptains!.length > 1)
                                Align(
                                  alignment: Alignment.center,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: primary.withOpacity(0.1),
                                    child: IconButton(
                                      icon: Icon(
                                        _isCaptainListExpanded ? Icons.expand_less : Icons.expand_more,
                                        size: 16,
                                        color: primary,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isCaptainListExpanded = !_isCaptainListExpanded;
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Icon(Icons.person, color: primary),
                            const Gap(10),
                            Expanded(
                              child: Text(
                                "No captain assigned",
                                style: blackMedium16.copyWith(color: Colors.red),
                              ),
                            ),
                            if (!vehicle.isActive)
                              TextButton(
                                onPressed: () => _showCaptainAssignmentBottomSheet(vehicle),
                                child: Text(
                                  "Assign Captain",
                                  style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleList(List<Vehicle> vehicles) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return vehicles.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Gap(25),
          Text("No vehicles found", style: blackMedium18),
          TextButton(
            onPressed: _fetchVehicles,
            child: Text("Retry", style: TextStyle(color: primary)),
          ),
        ],
      ),
    )
        : ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: vehicles.length,
      separatorBuilder: (_, __) => const Gap(20),
      itemBuilder: (context, index) => _buildVehicleCard(vehicles[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      color: black,
                      size: IconSize.regular,
                    ),
                  ),
                ),
                const Gap(15),
                Expanded(child: Text('My Vehicles', style: blackMedium20)),
                IconButton(
                  icon: Icon(Icons.add, color: primary),
                  onPressed: () {
                    Navigator.pushNamed(context, Routes.vehicleDetails);
                  },
                )
              ],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: grey,
          indicatorColor: primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Truck'),
            Tab(text: 'Backhoe'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVehicleList(_vehicles),
                _buildVehicleList(_vehicles.where((v) => v.isTruck).toList()),
                _buildVehicleList(_vehicles.where((v) => v.isBackhoe).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}