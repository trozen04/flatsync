import 'package:isar/isar.dart';

part 'contact_model.g.dart';

@collection
class ContactModel {
  Id id = Isar.autoIncrement;
  
  String? contactId; // Backend user ID
  
  @Index(unique: true)
  String? phoneNumber; // Unique identifier
  
  String? name;
  String? avatar;
  
  bool isRegistered = false; // Whether user is registered on backend
  
  DateTime? createdAt;
  DateTime? updatedAt;

  ContactModel({
    this.contactId,
    this.name,
    this.phoneNumber,
    this.avatar,
    this.isRegistered = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      contactId: json['_id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      avatar: json['avatar'],
      isRegistered: true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': contactId,
      'name': name,
      'phoneNumber': phoneNumber,
      'avatar': avatar,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
