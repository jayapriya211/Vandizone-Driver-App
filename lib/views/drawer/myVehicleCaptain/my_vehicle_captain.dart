import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../components/my_appbar.dart';
import '../../../utils/assets.dart';
import '../../../utils/constant.dart';
import '../../../utils/icon_size.dart';
import '../../../widgets/my_textfield.dart';
import 'package:vandizone_caption/widgets/my_elevated_button.dart';

class MyVehicleCaptainListView extends StatefulWidget {
  const MyVehicleCaptainListView({super.key});

  @override
  State<MyVehicleCaptainListView> createState() => _MyVehicleCaptainListViewState();
}

class _MyVehicleCaptainListViewState extends State<MyVehicleCaptainListView> {
  final List<Map<String, dynamic>> captains = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: captains.length,
        itemBuilder: (context, index) {
          final captain = captains[index];
          final isActive = captain['isActive'];

          return Container(
            margin: EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [boxShadow1],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle Photo on the left
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    captain['vehiclePhoto'],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                Gap(12),
                // All text content on the right
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(captain['vehicleNumber'], style: primarySemiBold18),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive ? Color(0xffE8F5E9) : Color(0xffFFEBEE),
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
                        ],
                      ),
                      Gap(4),
                      Text("ID: ${captain['uniqueId']}", style: colorABRegular14),
                      Text("Owner: ${captain['owner']}", style: blackRegular16),
                      if (isActive) ...[
                        Gap(4),
                        Text("Driver: ${captain['driverName']}", style: blackRegular16),
                      ],
                      Gap(8),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: primary),
                          Gap(4),
                          Text(captain['mobile'], style: blackRegular16),
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete Icon
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteConfirmation(context, index),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Delete Vehicle Captain?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              "Are you sure you want to delete ${captains[index]['vehicleNumber']}?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel", style: TextStyle(color: Colors.black)),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      setState(() {
                        captains.removeAt(index);
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Vehicle captain deleted successfully")),
                      );
                    },
                    child: Text("Delete", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
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
              Gap(15),
              Expanded(child: Text('My Vehicles', style: blackMedium20)),
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
          decoration: BoxDecoration(
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
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Text(
                "Enter Vehicle Unique ID",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              // Input field
              MyTextfield(
                header: 'Vehicle Unique ID',
                controller: idController,
                readOnly: false,
              ),
              SizedBox(height: 30),
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
                  SizedBox(width: 15),
                  Expanded(
                    child: MyElevatedButton(
                      title: 'Add',
                      onPressed: () {
                        if (idController.text.isNotEmpty) {
                          print("ID: ${idController.text}");
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}