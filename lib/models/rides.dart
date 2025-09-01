class Rides {
  final String id;
  final String profilePic;
  final String carName;
  final String price;
  final String from;
  final String to;
  final String paymentType;
  final String date;
  final String customerFare;
  final String fuelCost;
  final String tollCost;
  final String commission;
  final String wages;
  final String grossProfit;

  Rides({
    this.id = 'HP12A2975',
    required this.profilePic,
    required this.carName,
    required this.price,
    required this.from,
    required this.to,
    required this.paymentType,
    required this.date,
    this.customerFare = '₹7,200',
    this.fuelCost = '₹1,100',
    this.tollCost = '₹350',
    this.commission = '₹800',
    this.wages = '₹300',
    this.grossProfit = '₹4,500',
  });
}
