/// Someone the customer shares their trips with in one tap (WhatsApp).
class TrustedContact {
  final String id;
  final String name;
  final String phone;
  /// Follows every ride the customer takes at night (only one contact at a time).
  final bool nightShare;

  const TrustedContact({required this.id, required this.name, required this.phone, this.nightShare = false});

  factory TrustedContact.fromJson(Map<String, dynamic> json) => TrustedContact(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    phone: '${json['phone'] ?? ''}',
    nightShare: json['night_share'] == true || '${json['night_share']}' == '1',
  );
}
