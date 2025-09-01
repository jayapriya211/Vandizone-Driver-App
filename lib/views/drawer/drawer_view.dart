import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vandizone_caption/helper/ui_helper.dart';
import '../../models/drawer.dart';
import '../../routes/routes.dart';
import '../../utils/assets.dart';
import '../../utils/constant.dart';
import '../../utils/icon_size.dart';

class DrawerView extends StatefulWidget {
  const DrawerView({super.key});

  @override
  State<DrawerView> createState() => _DrawerViewState();
}

class _DrawerViewState extends State<DrawerView> {
  int selectedRole = 0;
  String name = "";
  String mobile = "";
  String? profileImageUrl;


  @override
  void initState() {
    super.initState();
    _loadSelectedRole();
  }

  Future<void> _loadSelectedRole() async {
    final prefs = await SharedPreferences.getInstance();
    selectedRole = prefs.getInt('selectedRole') ?? 0;
    name = prefs.getString('name') ?? "";
    mobile = prefs.getString('mobile') ?? "";

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final collectionName = selectedRole == 1 ? 'owners' : 'captains';
      final userDoc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          mobile = userDoc.data()?['mobile'];
          name = userDoc.data()?['name'];
          profileImageUrl = userDoc.data()?['profileImage'];
        });
      }
    }
  }


  List<DrawerItem> getDrawerItems() {
    List<DrawerItem> items = [];

    // Show Home or HomeOwner based on role
    if (selectedRole == 0) {
      items.add(DrawerItem(
        title: 'Home',
        icon: AssetImages.drawer1,
        navigateTo: Routes.home,
      ));
    } else {
      items.add(DrawerItem(
        title: 'Home',
        icon: AssetImages.drawer1,
        navigateTo: Routes.homeowner,
      ));
    }

    items.addAll([
      DrawerItem(
        title: 'Profile',
        icon: AssetImages.drawer2,
        navigateTo: Routes.editProfile,
      ),
      if (selectedRole == 1)
      DrawerItem(
        title: 'Vehicle List',
        icon: AssetImages.drawer3,
        navigateTo: Routes.vehicleList,
      ),
      if (selectedRole == 1)
      DrawerItem(
        title: 'My Captain',
        icon: AssetImages.drawer3,
        navigateTo: Routes.mycaptain,
      ),
      if (selectedRole == 0)
      DrawerItem(
        title: 'My Jobs',
        icon: AssetImages.drawer3,
        navigateTo: Routes.myRides,
      ),
      // if (selectedRole == 0)
      // DrawerItem(
      //   title: 'My Vehicle',
      //   icon: AssetImages.drawer3,
      //   navigateTo: Routes.myvehiclecaptain,
      // ),
      // if (selectedRole == 0)
      // DrawerItem(
      //   title: 'Ratings',
      //   icon: AssetImages.drawer4,
      //   navigateTo: Routes.driverReviews,
      // ),
      if (selectedRole == 1)
      DrawerItem(
        title: 'Bookings',
        icon: AssetImages.drawer4,
        navigateTo: Routes.bookingList,
      ),
      if (selectedRole == 1)
      DrawerItem(
        title: 'Wallet',
        icon: AssetImages.drawer5,
        navigateTo: Routes.walletOwner,
      ),
      // if (selectedRole == 0)
      // DrawerItem(
      //   title: 'Wallet',
      //   icon: AssetImages.drawer5,
      //   navigateTo: Routes.walletCaptain,
      // ),
      if (selectedRole == 0)
      DrawerItem(
        title: 'Notifications',
        icon: AssetImages.drawer6,
        navigateTo: Routes.notification,
      ),
      if (selectedRole == 1)
      DrawerItem(
        title: 'Notifications',
        icon: AssetImages.drawer6,
        navigateTo: Routes.ownernotification,
      ),
      DrawerItem(
        title: 'Faqs',
        icon: AssetImages.drawer8,
        navigateTo: Routes.faq,
      ),
      DrawerItem(
        title: 'Help Desk',
        icon: AssetImages.drawer9,
        navigateTo: Routes.contactUs,
      ),
      DrawerItem(
        title: 'About Us',
        icon: AssetImages.drawer9,
        navigateTo: Routes.aboutus,
      ),
      DrawerItem(
        title: 'Terms & Conditions',
        icon: AssetImages.drawer9,
        navigateTo: Routes.termsconditions,
      ),
      DrawerItem(
        title: 'Privacy Policy',
        icon: AssetImages.drawer9,
        navigateTo: Routes.privacypolicy,
      ),
      DrawerItem(
        title: 'Cancellation Status',
        icon: AssetImages.drawer9,
        navigateTo: Routes.cancelstatus,
      ),
      DrawerItem(
        title: 'Logout',
        icon: AssetImages.drawer10,
      ),
    ]);

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final drawerItems = getDrawerItems();

    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: primary,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.5),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: white),
                ),
              ),
              Center(
                child: Column(
                  children: [
                    Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        color: white,
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: profileImageUrl != null
                              ? NetworkImage(profileImageUrl!)
                              : AssetImage(AssetImages.drawerprofile) as ImageProvider,
                        ),
                      ),
                    ),
                    Gap(15),
                    Text(name, style: whiteSemiBold20),
                    Gap(5),
                    Text(
                      mobile,
                      style: whiteMedium14.copyWith(
                        color: white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  physics: BouncingScrollPhysics(),
                  itemBuilder: (_, index) {
                    final item = drawerItems[index];
                    bool isLastItem = index == drawerItems.length - 1;

                    return ListTile(
                      onTap: () {
                        if (isLastItem) {
                          UiHelper.showLogoutDialog(context);
                        } else {
                          Navigator.of(context).pop();
                          if (item.onPressed != null) {
                            item.onPressed!();
                          } else {
                            if (item.navigateTo != null) {
                              Navigator.of(context).pushNamed(item.navigateTo!);
                            }
                          }
                        }
                      },
                      contentPadding: EdgeInsets.symmetric(horizontal: 20),
                      leading: Image.asset(item.icon, height: IconSize.regular),
                      title: Transform.translate(
                        offset: Offset(-10, 0),
                        child: Text(item.title, style: whiteMedium18),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => SizedBox(),
                  itemCount: drawerItems.length,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
