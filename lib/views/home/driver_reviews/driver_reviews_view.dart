import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../components/my_appbar.dart';
import '../../../models/review.dart';
import '../../../utils/assets.dart';
import '../../../utils/constant.dart';

class DriverReviewsView extends StatefulWidget {
  const DriverReviewsView({super.key});

  @override
  State<DriverReviewsView> createState() => _DriverReviewsViewState();
}

class _DriverReviewsViewState extends State<DriverReviewsView> {
  String? selectedRating; // null means all ratings are shown

  final List<Review> allReviews = [
    Review(
      profilePic: AssetImages.review1,
      name: "Peter Willims",
      date: "2 jan 2024",
      rating: "4.5",
      review: "Great driver, very professional and punctual.",
    ),
    Review(
      profilePic: AssetImages.review2,
      name: "Jakson Fox",
      date: "2 feb 2024",
      rating: "4.0",
      review: "Good experience overall, would recommend.",
    ),
    Review(
      profilePic: AssetImages.review3,
      name: "Miranda Josheph",
      date: "20 jun 2024",
      rating: "4.5",
      review: "Excellent service, very comfortable ride.",
    ),
    Review(
      profilePic: AssetImages.review4,
      name: "Shivin Auluwala",
      date: "2 jan 2025",
      rating: "3.5",
      review: "Decent ride but could be improved.",
    ),
    Review(
      profilePic: AssetImages.review5,
      name: "Amrit Pathon",
      date: "10 jan 2025",
      rating: "3.0",
      review: "Average experience, nothing special.",
    ),
    Review(
      profilePic: AssetImages.review5,
      name: "Amrit Pathon",
      date: "10 jan 2025",
      rating: "5.0",
      review: "Perfect in every way! Best driver ever!",
    ),
    Review(
      profilePic: AssetImages.review6,
      name: "Gay Hawkins",
      date: "15 dec 2024",
      rating: "4.0",
      review: "Reliable and safe driver.",
    ),
    Review(
      profilePic: AssetImages.review7,
      name: "Jenny Wilson",
      date: "2 jan 2025",
      rating: "4.5",
      review: "Very pleasant journey, would book again.",
    ),
    Review(
      profilePic: AssetImages.review7,
      name: "Jenny Wilson",
      date: "2 jan 2025",
      rating: "1.0",
      review: "Terrible experience, would not recommend.",
    ),
    Review(
      profilePic: AssetImages.review7,
      name: "Jenny Wilson",
      date: "2 jan 2025",
      rating: "2.0",
      review: "Below average service.",
    ),
  ];

  List<Review> get filteredReviews {
    if (selectedRating == null) return allReviews;
    return allReviews.where((review) {
      final rating = double.tryParse(review.rating) ?? 0;
      return rating >= double.parse(selectedRating!) &&
          rating < double.parse(selectedRating!) + 1;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: 'Rating'),
      body: Column(
        children: [
          // Rating filter cards
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                // All ratings card
                _buildRatingFilterCard(null, 'All'),
                // 5-star card
                _buildRatingFilterCard('5', '5 ★'),
                // 4-star card
                _buildRatingFilterCard('4', '4 ★'),
                // 3-star card
                _buildRatingFilterCard('3', '3 ★'),
                // 2-star card
                _buildRatingFilterCard('2', '2 ★'),
                // 1-star card
                _buildRatingFilterCard('1', '1 ★'),
              ],
            ),
          ),
          // Reviews list
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 20),
              physics: BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final review = filteredReviews[index];
                return Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: myBorderRadius(10),
                    boxShadow: [boxShadow1],
                  ),
                  child: Column(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Image.asset(review.profilePic, height: 40),
                            Gap(10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(review.name, style: blackRegular16),
                                  Text(review.date, style: colorABRegular14),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.star, color: amber),
                                Gap(2),
                                Text(review.rating, style: blackRegular16)
                              ],
                            )
                          ],
                        ),
                      ),
                      Gap(10),
                      Text(review.review, style: colorABRegular14)
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) => Gap(25),
              itemCount: filteredReviews.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingFilterCard(String? ratingValue, String label) {
    final isSelected = selectedRating == ratingValue;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedRating = isSelected ? null : ratingValue;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primary : white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? primary : Colors.grey.shade300,
            ),
            boxShadow: [boxShadow1],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}