import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String bookingId;
  final String bookingCode;
  final String? bookingNo;
  final String vehicleNumber;
  final String? assignedCaptainId;
  final String? captainId;
  final String userId;
  final int status;
  final Timestamp? createdAt;
  final Timestamp? bookingDate;
  final dynamic fromLocation; // Can be Map or String
  final dynamic toLocation;   // Can be Map or String
  final String? serviceType;  // 'BHL' or 'Truck'
  final String? paymentMethod;
  final double? fare;
  final double? baseAmount;
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? captainDetails;
  final Map<String, dynamic>? ownerDetails;
  final Map<String, dynamic>? vehicleDetails;

  Booking({
    required this.bookingId,
    required this.bookingCode,
    this.bookingNo,
    required this.vehicleNumber,
    this.assignedCaptainId,
    this.captainId,
    required this.userId,
    required this.status,
    this.createdAt,
    this.bookingDate,
    required this.fromLocation,
    required this.toLocation,
    this.serviceType,
    this.paymentMethod,
    this.fare,
    this.baseAmount,
    this.customer,
    this.captainDetails,
    this.ownerDetails,
    this.vehicleDetails,
  });

  factory Booking.fromMap(Map<String, dynamic> map, String id) {
    return Booking(
      bookingId: id,
      bookingCode: map['bookingCode'] ?? '',
      bookingNo: map['bookingNo'],
      vehicleNumber: map['vehicleDetails']?['vehicleNumber'] ??
          map['vehicleNumber'] ??
          'Not assigned',
      assignedCaptainId: map['assignedCaptainId'],
      captainId: map['captainId'] ?? map['assignedCaptainId'],
      userId: map['userId'] ?? '',
      status: map['status'] ?? 0,
      createdAt: map['createdAt'],
      bookingDate: map['bookingDate'] ?? map['createdAt'],
      fromLocation: map['fromLocation'],
      toLocation: map['toLocation'],
      serviceType: map['serviceType'] ??
          (map['bhlSubType'] != null ? 'BHL' : 'Truck'),
      paymentMethod: map['paymentMethod'],
      fare: (map['fare'] ?? map['totalFare'] ?? 0).toDouble(),
      baseAmount: (map['baseamount'] ?? 0).toDouble(),
      customer: map['customer'] is Map ? map['customer'] : null,
      captainDetails: map['captainDetails'] is Map ? map['captainDetails'] : null,
      ownerDetails: map['ownerDetails'] is Map ? map['ownerDetails'] : null,
      vehicleDetails: map['vehicleDetails'] is Map ? map['vehicleDetails'] : null,
    );
  }

  String get statusText {
    switch (status) {
      case 1: return 'Requested';
      case 2: return 'Accepted';
      case 3: return 'Arrived';
      case 4: return 'In Progress';
      case 5: return 'Completed';
      case 6: return 'Cancelled';
      case 7: return 'Rejected';
      default: return 'Pending';
    }
  }

  Color get statusColor {
    switch (status) {
      case 1: return Colors.blue;
      case 2: return Colors.lightBlue;
      case 3: return Colors.teal;
      case 4: return Colors.orange;
      case 5: return Colors.green;
      case 6: return Colors.red;
      case 7: return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  String? get customerName {
    if (customer != null && customer!['name'] != null) {
      return customer!['name'];
    }
    if (ownerDetails != null && ownerDetails!['name'] != null) {
      return ownerDetails!['name'];
    }
    return 'Unknown';
  }

  String? get customerPhone {
    if (customer != null && customer!['phone'] != null) {
      return customer!['phone'];
    }
    if (ownerDetails != null && ownerDetails!['mobile'] != null) {
      return ownerDetails!['mobile'];
    }
    return 'Not provided';
  }

  String? get captainName {
    if (captainDetails != null && captainDetails!['name'] != null) {
      return captainDetails!['name'];
    }
    return 'Not assigned';
  }

  String get fromAddress {
    if (fromLocation is Map) {
      return fromLocation['address'] ?? 'Pickup location not specified';
    }
    return fromLocation?.toString() ?? 'Pickup location not specified';
  }

  String get toAddress {
    if (toLocation is Map) {
      return toLocation['address'] ?? 'Destination not specified';
    }
    return toLocation?.toString() ?? 'Destination not specified';
  }

  String get formattedBookingDate {
    final date = bookingDate?.toDate() ?? createdAt?.toDate();
    if (date == null) return 'Date not available';

    return '${date.day}-${date.month}-${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String? get vehicleType {
    if (vehicleDetails != null) {
      return vehicleDetails!['vehicleType'] ??
          vehicleDetails!['bodyType'] ??
          vehicleDetails!['makeModel'];
    }
    return serviceType;
  }
}