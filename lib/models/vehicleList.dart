class Vehicle {
  final String? id;
  final String make;
  final String licensePlate;
  final String model;
  final String color;
  final int year;
  final String vehicleType;
  final String vehicleCategory;
  final String bodyType;
  final String vehicleNumber;
  final String numberOfAxles;
  final String engineNumber;
  final String chassisNumber;
  final String insuredValue;
  final String numberOfTyres;
  final String payload;
  final String gcw;
  final String truckDimensions;
  bool isActive;
  List<Captain>? assignedCaptains;
  final String imageUrl;
  final String vehicleCode;
  final String rcUrl;
  final String insuranceUrl;
  final String permitAccess;
  final String registeringDistrict;
  final bool isTruck;
  final bool isBackhoe;
  final DateTime? createdAt;

  Vehicle({
    this.id,
    required this.make,
    required this.licensePlate,
    required this.model,
    required this.color,
    required this.year,
    required this.vehicleType,
    required this.vehicleCategory,
    required this.bodyType,
    required this.vehicleNumber,
    required this.numberOfAxles,
    required this.engineNumber,
    required this.chassisNumber,
    required this.insuredValue,
    required this.numberOfTyres,
    required this.payload,
    required this.gcw,
    required this.truckDimensions,
    required this.isActive,
    this.assignedCaptains,
    required this.imageUrl,
    required this.vehicleCode,
    this.rcUrl = '',
    this.insuranceUrl = '',
    this.permitAccess = '',
    this.registeringDistrict = '',
    this.isTruck = false,
    this.isBackhoe = false,
    this.createdAt,
  });

  // Helper methods
  String get vehicleTypeDisplay {
    if (isTruck) return 'Truck';
    if (isBackhoe) return 'Backhoe Loader';
    return vehicleType;
  }

  String get vehicleCodeDisplay {
    if (isTruck) return 'Truck Code: $vehicleCode';
    if (isBackhoe) return 'BHL Code: $vehicleCode';
    return 'Code: $vehicleCode';
  }

  // Copy method for updating properties
  Vehicle copyWith({
    String? id,
    String? make,
    String? licensePlate,
    String? model,
    String? color,
    int? year,
    String? vehicleType,
    String? vehicleCategory,
    String? bodyType,
    String? vehicleNumber,
    String? numberOfAxles,
    String? engineNumber,
    String? chassisNumber,
    String? insuredValue,
    String? numberOfTyres,
    String? payload,
    String? gcw,
    String? truckDimensions,
    bool? isActive,
    List<Captain>? assignedCaptains,
    String? imageUrl,
    String? vehicleCode,
    String? rcUrl,
    String? insuranceUrl,
    String? permitAccess,
    String? registeringDistrict,
    bool? isTruck,
    bool? isBackhoe,
  }) {
    return Vehicle(
      id: id ?? this.id,
      make: make ?? this.make,
      licensePlate: licensePlate ?? this.licensePlate,
      model: model ?? this.model,
      color: color ?? this.color,
      year: year ?? this.year,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      bodyType: bodyType ?? this.bodyType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      numberOfAxles: numberOfAxles ?? this.numberOfAxles,
      engineNumber: engineNumber ?? this.engineNumber,
      chassisNumber: chassisNumber ?? this.chassisNumber,
      insuredValue: insuredValue ?? this.insuredValue,
      numberOfTyres: numberOfTyres ?? this.numberOfTyres,
      payload: payload ?? this.payload,
      gcw: gcw ?? this.gcw,
      truckDimensions: truckDimensions ?? this.truckDimensions,
      isActive: isActive ?? this.isActive,
      assignedCaptains: assignedCaptains ?? this.assignedCaptains,
      imageUrl: imageUrl ?? this.imageUrl,
      vehicleCode: vehicleCode ?? this.vehicleCode,
      rcUrl: rcUrl ?? this.rcUrl,
      insuranceUrl: insuranceUrl ?? this.insuranceUrl,
      permitAccess: permitAccess ?? this.permitAccess,
      registeringDistrict: registeringDistrict ?? this.registeringDistrict,
      isTruck: isTruck ?? this.isTruck,
      isBackhoe: isBackhoe ?? this.isBackhoe,
    );
  }
  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id']?.toString(),
      make: map['make']?.toString() ?? '',
      licensePlate: map['vehicleNumber']?.toString() ?? '',
      model: map['makeModel']?.toString() ?? '',
      color: map['color']?.toString() ?? '',
      year: map['year'] is int ? map['year'] : int.tryParse(map['year']?.toString() ?? '0') ?? 0,
      vehicleType: map['vehicleType']?.toString() ?? '',
      vehicleCategory: map['vehicleCategory']?.toString() ?? '',
      bodyType: map['bodyType']?.toString() ?? '',
      vehicleNumber: map['vehicleNumber']?.toString() ?? '',
      numberOfAxles: map['numberOfAxles']?.toString() ?? '',
      engineNumber: map['engineNumber']?.toString() ?? '',
      chassisNumber: map['chassisNumber']?.toString() ?? '',
      insuredValue: map['insuredValue']?.toString() ?? '',
      numberOfTyres: map['numberOfTyres']?.toString() ?? '',
      payload: map['payload']?.toString() ?? '',
      gcw: map['gcw']?.toString() ?? '',
      truckDimensions: map['truckDimensions']?.toString() ?? '',
      isActive: (map['status'] ?? 1) == 0,
      assignedCaptains: (map['assignedCaptains'] as List?)?.map((e) => Captain.fromMap(e)).toList(),
      imageUrl: map['vehiclePhotoUrl']?.toString() ?? '',
      vehicleCode: map['vehicleCode']?.toString() ?? '',
      rcUrl: map['rcUrl']?.toString() ?? '',
      insuranceUrl: map['insuranceUrl']?.toString() ?? '',
      permitAccess: map['permitAccess']?.toString() ?? '',
      registeringDistrict: map['registeringDistrict']?.toString() ?? '',
      isTruck: map['isTruck'] ?? false,
      isBackhoe: map['isBackhoe'] ?? false,
    );
  }
}

class Captain {
  final String name;
  final String id;
  final String phone;
  final String? captainId;
  final String? email;
  final String? imageUrl;
  bool isAssigned;

  Captain({
    required this.name,
    required this.id,
    required this.phone,
    this.captainId,
    this.email,
    this.imageUrl,
    this.isAssigned = false,
  });

  // Copy method for updating properties
  Captain copyWith({
    String? name,
    String? id,
    String? phone,
    String? captainId,
    String? email,
    String? imageUrl,
    bool? isAssigned,
  }) {
    return Captain(
      name: name ?? this.name,
      id: id ?? this.id,
      phone: phone ?? this.phone,
      captainId: captainId ?? this.captainId,
      email: email ?? this.email,
      imageUrl: imageUrl ?? this.imageUrl,
      isAssigned: isAssigned ?? this.isAssigned,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'id': id,
      'phone': phone,
      if (email != null) 'email': email,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'isAssigned': isAssigned,
    };
  }

  // Factory method to create from Firestore data
  factory Captain.fromMap(Map<String, dynamic> map) {
    return Captain(
      name: map['name'] ?? '',
      id: map['id'] ?? map['userCode'] ?? '',
      phone: map['phone']?.toString() ?? map['mobile']?.toString() ?? '',
      captainId: map['captainId'],
      email: map['email'],
      imageUrl: map['imageUrl'] ?? map['profileImage'],
      isAssigned: map['isAssigned'] ?? map['is_assign'] ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Captain &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}