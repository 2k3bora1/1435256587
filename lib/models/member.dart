import 'dart:typed_data';

class Member {
  final String aadhaar;
  final String name;
  final String phone;
  final String address;
  final String joinDate;
  final Uint8List? photo;
  final Uint8List? aadhaarDoc;
  final String? coAadhaar;
  final String? coName;
  final String? coPhone;
  final Uint8List? coPhoto;
  final Uint8List? coAadhaarDoc;

  Member({
    required this.aadhaar,
    required this.name,
    required this.phone,
    required this.address,
    required this.joinDate,
    this.photo,
    this.aadhaarDoc,
    this.coAadhaar,
    this.coName,
    this.coPhone,
    this.coPhoto,
    this.coAadhaarDoc,
  });

  // Convert Member object to a Map
  Map<String, dynamic> toMap() {
    return {
      'aadhaar': aadhaar,
      'name': name,
      'phone': phone,
      'address': address,
      'join_date': joinDate,
      'photo': photo,
      'aadhaar_doc': aadhaarDoc,
      'co_aadhaar': coAadhaar,
      'co_name': coName,
      'co_phone': coPhone,
      'co_photo': coPhoto,
      'co_aadhaar_doc': coAadhaarDoc,
    };
  }

  // Create Member object from a Map
  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      aadhaar: map['aadhaar'],
      name: map['name'],
      phone: map['phone'],
      address: map['address'],
      joinDate: map['join_date'],
      photo: map['photo'],
      aadhaarDoc: map['aadhaar_doc'],
      coAadhaar: map['co_aadhaar'],
      coName: map['co_name'],
      coPhone: map['co_phone'],
      coPhoto: map['co_photo'],
      coAadhaarDoc: map['co_aadhaar_doc'],
    );
  }

  // Create a copy of Member with modified fields
  Member copyWith({
    String? aadhaar,
    String? name,
    String? phone,
    String? address,
    String? joinDate,
    Uint8List? photo,
    Uint8List? aadhaarDoc,
    String? coAadhaar,
    String? coName,
    String? coPhone,
    Uint8List? coPhoto,
    Uint8List? coAadhaarDoc,
  }) {
    return Member(
      aadhaar: aadhaar ?? this.aadhaar,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      joinDate: joinDate ?? this.joinDate,
      photo: photo ?? this.photo,
      aadhaarDoc: aadhaarDoc ?? this.aadhaarDoc,
      coAadhaar: coAadhaar ?? this.coAadhaar,
      coName: coName ?? this.coName,
      coPhone: coPhone ?? this.coPhone,
      coPhoto: coPhoto ?? this.coPhoto,
      coAadhaarDoc: coAadhaarDoc ?? this.coAadhaarDoc,
    );
  }
}