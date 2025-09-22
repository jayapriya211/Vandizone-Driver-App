// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:gap/gap.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sizer/sizer.dart';
import '../../../models/arguments/ride_detail_args.dart';
import '../../../utils/assets.dart';
import '../../../utils/constant.dart';
import '../../../utils/icon_size.dart';
import '../../../utils/key.dart';
import '../../../widgets/my_elevated_button.dart';

class RideDetailView extends StatefulWidget {
  final RideDetailArgs? args;
  const RideDetailView({super.key, required this.args});

  @override
  State<RideDetailView> createState() => _RideDetailViewState();
}

List _imageList = [AssetImages.pastride1, AssetImages.youhere];
final List<Marker> _markers = [];
final List<LatLng> _latlng = [
  const LatLng(37.776482, -122.416988),
  const LatLng(37.754620, -122.408510),
];

class _RideDetailViewState extends State<RideDetailView> {
  final Completer<GoogleMapController> googleMapController = Completer();
  static const CameraPosition _sourceLocation =
      CameraPosition(target: LatLng(37.754620, -122.408510), zoom: 13.5);
  LatLng soureLocation = const LatLng(37.776482, -122.416988);
  LatLng destination = const LatLng(37.756385, -122.408876);
  List<LatLng> polylineCoordinates = [];

  @override
  void initState() {
    super.initState();
    _getPolyPoints();
    _loadData();
  }

  Future<void> _getPolyPoints() async {
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: googleMapApiKey,
        request: PolylineRequest(
          origin: PointLatLng(soureLocation.latitude, soureLocation.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.walking,
        ));
    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        setState(() {});
      }
    }
  }

  Future<void> _loadData() async {
    for (int i = 0; i < _imageList.length; i++) {
      final isMyLocation = i == 0;
      final Uint8List markerIcon = await getBytesFromAssets(_imageList[i], !isMyLocation ? 35 : 65);
      _markers.add(
        Marker(
          icon: BitmapDescriptor.bytes(markerIcon),
          markerId: MarkerId(i.toString()),
          position: _latlng[i],
        ),
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<Uint8List> getBytesFromAssets(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetHeight: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _body());
  }

  Stack _body() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        _map(),
        _backButton(),
        _riderInfo(),
      ],
    );
  }

  Positioned _backButton() {
    return Positioned(
      top: 0,
      left: 20,
      child: SafeArea(
        child: InkWell(
          onTap: () => Navigator.pop(context),
          child: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: white,
              borderRadius: myBorderRadius(10),
              boxShadow: [boxShadow1],
            ),
            child: Icon(Icons.arrow_back_ios_new, color: black),
          ),
        ),
      ),
    );
  }

  Container _riderInfo() {
    bool isUpComingRide = !(widget.args?.isUpComingRide ?? false);
    return Container(
      width: 100.w,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.vertical(top: myRadius(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rider Info', style: blackMedium18),
              Visibility(
                  maintainState: true,
                  visible: !isUpComingRide,
                  child: Text('3 mins left', style: colorABMedium16)),
            ],
          ),
          Gap(20),
          IntrinsicHeight(
            child: Row(
              children: [
                Image.asset(AssetImages.pastride1, height: 60, width: 60),
                Gap(15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Kalai", style: primaryMedium18),
                      Text("+91 9876543211", style: colorABRegular16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Gap(26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Trip Route", style: blackMedium18),
              Text("10 km (10 min)", style: primarySemiBold16),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 25, bottom: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(AssetImages.fromaddress, height: IconSize.regular),
                    Gap(5),
                    Text('Trichy', style: blackRegular16),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 5),
                  child: Column(
                    children: List.generate(
                        3, (index) => Text("\u2022", style: blackRegular16.copyWith(height: 0.5))),
                  ),
                ),
                Row(
                  children: [
                    Image.asset(AssetImages.toaddress, height: IconSize.regular),
                    Gap(5),
                    Text('Ariyalur', style: blackRegular16),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Payment", style: blackMedium18),
              Text("\₹50.00", style: primarySemiBold16),
            ],
          ),
          Gap(20),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: white,
              boxShadow: [boxShadow1],
              borderRadius: myBorderRadius(10),
            ),
            child: Row(
              children: [
                Image.asset(AssetImages.visa, height: 36),
                Gap(10),
                Expanded(child: Text('Gpay', style: blackRegular16)),
                Icon(Icons.check_circle_outline_outlined, color: primary)
              ],
            ),
          ),
          if (isUpComingRide)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 25).copyWith(bottom: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Booked on", style: blackMedium18),
                  Text("12 June,2025 | 11:04 AM", style: colorABRegular16),
                ],
              ),
            )
          else
            Gap(30),
          if (!isUpComingRide)
            MyElevatedButton(
              title: 'Start Ride',
              onPressed: () async {},
            )
        ],
      ),
    );
  }

  GoogleMap _map() {
    return GoogleMap(
      zoomControlsEnabled: false,
      initialCameraPosition: _sourceLocation,
      mapType: MapType.normal,
      onMapCreated: (c) => googleMapController.complete(c),
      myLocationButtonEnabled: false,
      myLocationEnabled: false,
      markers: Set<Marker>.of(_markers),
      polylines: {
        Polyline(
          color: primary,
          width: 4,
          polylineId: PolylineId(DateTime.now().microsecondsSinceEpoch.toString()),
          points: polylineCoordinates,
        ),
      },
    );
  }
}
