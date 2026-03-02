import 'package:isar/isar.dart';

part 'user_model.g.dart';

@collection
class UserModel {
  Id id = Isar.autoIncrement;
  
  @Index(unique: true)
  String? userId;
  
  String? phoneNumber;
  String? name;
  
  String? accessToken;
  String? refreshToken;
  
  String? hashedPin; // Store hashed PIN for offline login
  
  DateTime? createdAt;
  DateTime? updatedAt;
  
  bool isLoggedIn = false;

  UserModel({
    this.userId,
    this.phoneNumber,
    this.name,
    this.accessToken,
    this.refreshToken,
    this.hashedPin,
    this.createdAt,
    this.updatedAt,
    this.isLoggedIn = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['_id'],
      phoneNumber: json['phoneNumber'],
      name: json['name'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': userId,
      'phoneNumber': phoneNumber,
      'name': name,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
