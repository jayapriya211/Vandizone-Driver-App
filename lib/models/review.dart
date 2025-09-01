class Review {
  final String profilePic;
  final String name;
  final String date;
  final String rating;
  final String review;

  Review(
      {required this.profilePic,
      required this.name,
      required this.date,
      required this.rating,
      this.review =
          "Lorem ipsum dolor sit amet consectetur. Vel volutpat turpis a senectus aliquet vghiverra. Libero neque maecenas erat aliquet "});
}
