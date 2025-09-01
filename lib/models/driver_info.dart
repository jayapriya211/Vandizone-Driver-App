class DriverInfo {
  final String image;
  final String id;
  final String carName;
  final String price;
  final String info;
  final String totalRide;
  final String arrivalTime;
  final String rating;
  final String trips;
  final String reviews;

  DriverInfo(
      {required this.image,
      this.id = "HP12A2975",
      this.carName = 'Alto 800',
      required this.price,
      required this.info,
      required this.totalRide,
      required this.arrivalTime,
      required this.rating,
      required this.trips,
      required this.reviews});
}
