import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:vandizone_caption/views/auth/complete_profile_view.dart';
import '../models/arguments/ride_detail_args.dart';
import '../views/auth/otp_verfiy_view.dart';
import '../views/auth/otp_verify_signin_view.dart';
import '../views/auth/sign_in_view.dart';
import '../views/auth/sign_up_view.dart';
import '../views/drawer/contact_us/contact_us_view.dart';
import '../views/drawer/edit_profile/edit_profile_view.dart';
import '../views/drawer/vehicleList/vehicleList_view.dart';
import '../views/drawer/vehicleList/addvehicle.dart';
import '../views/drawer/faqs/f_a_q_view.dart';
import '../views/drawer/inv_friends/inv_friends_view.dart';
import '../views/drawer/my_rides/my_rides_view.dart';
import '../views/drawer/my_rides/ride_detail_view.dart';
import '../views/drawer/notification/notification_view.dart';
import '../views/drawer/notification/owner_notification_view.dart';
import '../views/drawer/wallet/add_money/add_money_view_owner.dart';
import '../views/drawer/wallet/add_money/card_view.dart';
import '../views/drawer/wallet/send_to_bank/send_to_bank_view_owner.dart';
import '../views/drawer/wallet/send_to_bank/success_transfer_view_owner.dart';
import '../views/drawer/wallet/wallet_view_owner.dart';
import '../views/drawer/wallet/add_money/add_money_view_captain.dart';
import '../views/drawer/wallet/send_to_bank/send_bank_view_captain.dart';
import '../views/drawer/wallet/send_to_bank/success_transfer_captain.dart';
import '../views/drawer/wallet/wallet_view_captain.dart';
import '../views/home/call/call_view.dart';
import '../views/home/chat/chat_view.dart';
import '../views/home/driver_reviews/driver_reviews_view.dart';
import '../views/home/home_view.dart';
import '../views/home/truck_home_view.dart';
import '../views/home/mainHome_view.dart';
import '../views/home/home_owner_view.dart';
import '../views/home/ride_tracking/ride_tracking_view.dart';
import '../views/home/ride_tracking/ride_tracking_truck_view.dart';
import '../views/on_board/on_board_view.dart';
import '../views/splash/splash_view.dart';
import '../views/start_work/start_work.dart';
import '../views/start_work/start_work_truck.dart';
import '../views/drawer/mycaptain/my_captain.dart';
import '../views/drawer/myVehicleCaptain/my_vehicle_captain.dart';
import '../views/drawer/bookingList/booking_list.dart';
import '../views/drawer/terms_conditions/terms_and_conditions.dart';
import '../views/drawer/privacypolicy/privacy_policy.dart';
import '../views/drawer/cancellationstatus/cancellation_status.dart';
import '../views/drawer/aboutus/aboutus.dart';

class Routes {
  static const String splash = '/splash';
  static const String onBoard = '/onBoard';
  static const String signIn = '/signIn';
  static const String signUp = '/signUp';
  static const String otp = '/otp';
  static const String otpSignin = '/otpSignin';
  static const String completeProfile = '/completeProfile';
  static const String home = '/home';
  static const String mainhome = '/mainhome';
  static const String truckhome = '/truckhome';
  static const String homeowner = '/homeOwner';
  static const String editProfile = '/editProfile';
  static const String vehicleList = '/vehiclList';
  static const String vehicleDetails = '/vehicleDetails';
  static const String myRides = '/myRides';
  static const String rideDetail = '/rideDetail';
  static const String walletOwner = '/wallet';
  static const String sendToBankOwner = '/sendToBank';
  static const String addMoneyOwner = '/addMoney';
  static const String successTransferOwner = '/successTransfer';
  static const String walletCaptain = '/walletCaptain';
  static const String sendToBankCaptain = '/sendToBankCaptain';
  static const String addMoneyCaptain = '/addMoneyCaptain';
  static const String successTransferCaptain = '/successTransferCaptain';
  static const String card = '/card';
  static const String notification = '/notification';
  static const String ownernotification = '/ownernotification';
  static const String invFriends = '/invFriends';
  static const String faq = '/faq';
  static const String contactUs = '/contactUs';
  static const String driverReviews = '/driverReviews';
  static const String callView = '/callView';
  static const String chatView = '/chatView';
  static const String rideTracking = '/rideTracking';
  static const String rideTrackingTruck = '/rideTrackingTruck';
  static const String mycaptain = '/myCaptains';
  static const String myvehiclecaptain = '/myvehicleCaptains';
  static const String startworkBHL = '/startworkBHL';
  static const String startworkTruck = '/startworkTruck';
  static const String bookingList = '/bookingList';
  static const String termsconditions = '/termsconditions';
  static const String privacypolicy = '/privacypolicy';
  static const String cancelstatus = '/cancelstatus';
  static const String aboutus = '/aboutus';

  static const String initialRoute = splash;

  static final List<MyRoutes> routes = [
    MyRoutes(routeName: splash, routeChild: SplashView()),
    MyRoutes(routeName: onBoard, routeChild: OnBoardView()),
    MyRoutes(routeName: signIn, routeChild: SignInView()),
    MyRoutes(routeName: signUp, routeChild: SignUpView()),
    MyRoutes(routeName: completeProfile, routeChild: CompleteProfileView()),
    MyRoutes(routeName: otp, routeChild: OtpVerfiyView()),
    MyRoutes(routeName: otpSignin, routeChild: OwnerOtpVerfiyView()),
    MyRoutes(routeName: home, routeChild: HomeView()),
    MyRoutes(routeName: mainhome, routeChild: MainHomePage()),
    MyRoutes(routeName: truckhome, routeChild: TruckHomePage()),
    MyRoutes(routeName: homeowner, routeChild: HomeOwnerView()),
    MyRoutes(routeName: editProfile, routeChild: EditProfileView()),
    MyRoutes(routeName: vehicleList, routeChild: VehicleListView()),
    MyRoutes(routeName: vehicleDetails, routeChild: VehicleFormPage()),
    MyRoutes(routeName: myRides, routeChild: MyRidesView()),
    MyRoutes(routeName: rideDetail, routeChild: RideDetailView(args: RideDetailArgs())),
    MyRoutes(routeName: walletOwner, routeChild: WalletView()),
    MyRoutes(routeName: sendToBankOwner, routeChild: SendToBankView()),
    MyRoutes(routeName: addMoneyOwner, routeChild: AddMoneyView()),
    MyRoutes(routeName: successTransferOwner, routeChild: SuccessTransferView()),
    MyRoutes(routeName: walletCaptain, routeChild: WalletViewCaptain()),
    MyRoutes(routeName: sendToBankCaptain, routeChild: SendToBankViewCaptain()),
    MyRoutes(routeName: addMoneyCaptain, routeChild: AddMoneyViewCaptain()),
    MyRoutes(routeName: successTransferCaptain, routeChild: SuccessTransferViewCaptain()),
    MyRoutes(routeName: card, routeChild: CardView()),
    MyRoutes(routeName: notification, routeChild: NotificationView()),
    MyRoutes(routeName: ownernotification, routeChild: OwnerNotificationView()),
    MyRoutes(routeName: invFriends, routeChild: InvFriendsView()),
    MyRoutes(routeName: faq, routeChild: FAQView()),
    MyRoutes(routeName: contactUs, routeChild: ContactUsView()),
    MyRoutes(routeName: driverReviews, routeChild: DriverReviewsView()),
    MyRoutes(routeName: callView, routeChild: CallView()),
    MyRoutes(routeName: chatView, routeChild: ChatView()),
    MyRoutes(routeName: rideTracking, routeChild: RideTrackingView()),
    MyRoutes(routeName: rideTrackingTruck, routeChild: RideTrackingTruckView(args:{})),
    MyRoutes(routeName: mycaptain, routeChild: MyCaptainListView()),
    MyRoutes(routeName: myvehiclecaptain, routeChild: MyVehicleCaptainListView()),
    MyRoutes(routeName: startworkBHL, routeChild: StartWorkView()),
    MyRoutes(routeName: startworkTruck, routeChild: StartWorkTruckView()),
    MyRoutes(routeName: bookingList, routeChild: BookingListView()),
    MyRoutes(routeName: termsconditions, routeChild: TermsConditionsView()),
    MyRoutes(routeName: privacypolicy, routeChild: PrivacyPolicyView()),
    MyRoutes(routeName: cancelstatus, routeChild: CancellationStatusScreen()),
    MyRoutes(routeName: aboutus, routeChild: AboutUsPage()),
  ];

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    final args = settings.arguments;
    try {
      final route = routes.firstWhere((r) => settings.name == r.routeName);
      return route.toPageTransition(args: args);
    } catch (e) {
      return null;
    }
  }
}

class MyRoutes extends PageTransition {
  final String routeName;
  final Widget routeChild;
  final PageTransitionType? transitionType;
  final dynamic args;

  MyRoutes({
    required this.routeName,
    required this.routeChild,
    this.transitionType,
    this.args,
  }) : super(
          child: routeChild,
          type: transitionType ?? PageTransitionType.rightToLeft,
          duration: Duration(milliseconds: 200),
          isIos: true,
        );

  PageTransition<dynamic> toPageTransition({dynamic args}) {
    return PageTransition(
      type: type,
      child: routeChildWithArgs(args),
      duration: Duration(milliseconds: 200),
      isIos: true,
    );
  }

  Widget routeChildWithArgs(dynamic args) {
    if (routeChild is RideDetailView) {
      return RideDetailView(args: args);
    }
    if (routeChild is OtpVerfiyView) {
      return OtpVerfiyView(args: args);
    }
    if (routeChild is OwnerOtpVerfiyView) {
      return OwnerOtpVerfiyView(args: args);
    }
    if (routeChild is RideTrackingView) {
      return RideTrackingView(args: args);
    }
    if (routeChild is RideTrackingTruckView) {
      return RideTrackingTruckView(args: args);
    }
    return routeChild;
  }

}
