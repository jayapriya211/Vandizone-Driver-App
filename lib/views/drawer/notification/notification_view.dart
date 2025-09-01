import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../components/my_appbar.dart';
import '../../../models/notification.dart';
import '../../../utils/assets.dart';
import '../../../utils/constant.dart';
import '../../../utils/icon_size.dart';
import 'package:shimmer/shimmer.dart';

class NotificationView extends StatefulWidget {
  const NotificationView({super.key});

  @override
  State<NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<NotificationView> {
  final List<NotificationModel> _notificationList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    print('Fetching notifications for user: $uid');

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('captain_notifications')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      print('Found ${snapshot.docs.length} notifications');

      final list = snapshot.docs.map((doc) {
        print('Notification data: ${doc.data()}');
        final data = doc.data();
        return NotificationModel(
          id: doc.id,
          title: data['title'] ?? '',
          subtitle: data['message'] ?? '',
          dateTime: _formatTime(data['createdAt']),
          isRead: data['read'] ?? false,
        );
      }).toList();

      setState(() {
        _notificationList.clear();
        _notificationList.addAll(list);
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }


  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final dt = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _markAsRead(String notificationId, int index) async {
    try {
      await FirebaseFirestore.instance
          .collection('captain_notifications')
          .doc(notificationId)
          .delete(); // 🔄 DELETE the document instead of updating

      setState(() {
        _notificationList.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: primary,
          duration: Duration(seconds: 1),
          content: Text("Notification Mark as Read", style: whiteSemiBold14),
        ),
      );
    } catch (e) {
      debugPrint('[ERROR] Failed to delete notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text("Failed to delete notification", style: whiteSemiBold14),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: 'Notifications'),
      body:  _isLoading
          ? _buildShimmerLoader(): _notificationList.isEmpty
          ? SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AssetImages.emptynotification, height: 100),
              Gap(25),
              Text("No notification found", style: blackMedium18),
            ],
          ),
        ),
      )
          : ListView.separated(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.only(top: 5),
        itemCount: _notificationList.length,
        separatorBuilder: (_, __) => Gap(25),
        itemBuilder: (context, index) {
          final item = _notificationList[index];
          return Dismissible(
            key: ValueKey(item.id),
            background: Container(color: Colors.red),
            onDismissed: (_) {
              setState(() {
                _notificationList.removeAt(index);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: primary,
                  duration: Duration(seconds: 1),
                  content: Text("Notification removed", style: whiteSemiBold14),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.all(15),
              margin: EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: white,
                borderRadius: myBorderRadius(10),
                boxShadow: [boxShadow1],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications, color: Color(0xFF2ECC71), size: IconSize.regular),
                      Gap(10),
                      Expanded(child: Text(item.title, style: primaryMedium18)),
                      Text(item.dateTime, style: colorABRegular16),
                    ],
                  ),
                  Gap(10),
                  Text(item.subtitle, style: colorABRegular16),
                  Gap(10),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                      onPressed: () => _markAsRead(item.id, index),
                      child: Text("Mark as Read", style: TextStyle(color: primary)),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return ListView.separated(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: 20),
      itemCount: 5, // Number of shimmer placeholders
      separatorBuilder: (_, __) => Gap(25),
      itemBuilder: (context, index) {
        return Container(
          padding: EdgeInsets.all(15),
          margin: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: white,
            borderRadius: myBorderRadius(10),
            boxShadow: [boxShadow1],
          ),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      color: Colors.white,
                    ),
                    Gap(10),
                    Expanded(
                      child: Container(
                        height: 20,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
                Gap(10),
                Container(
                  height: 16,
                  color: Colors.white,
                ),
                Gap(10),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: 100,
                    height: 20,
                    color: Colors.white,
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
