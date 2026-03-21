import 'package:isar/isar.dart';

part 'contact_model.g.dart';

@collection
class ContactModel {
  Id id = Isar.autoIncrement;
  
  String? contactId; // Backend user ID
  
  @Index(unique: true)
  String? phoneNumber; // Unique identifier
  
  String? name;
  
  bool isRegistered = false; // True only when backend accountStatus is active
  
  DateTime? createdAt;
  DateTime? updatedAt;

  ContactModel({
    this.contactId,
    this.name,
    this.phoneNumber,
    this.isRegistered = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    final status = (json['accountStatus'] ?? '').toString().trim().toLowerCase();
    final isReg = status == 'active';
    // ignore: avoid_print
    print('[ContactModel.fromJson] phone=${json['phoneNumber']} accountStatus="$status" -> isRegistered=$isReg');
    return ContactModel(
      contactId: json['_id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      isRegistered: isReg,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': contactId,
      'name': name,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
