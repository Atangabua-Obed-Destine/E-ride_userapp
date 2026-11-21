/// E-Ride ID Verified: the person's ID card or passport, as E-Ride checked it (api/customer/id-verification).
class IdVerificationStatus {
  /// none | pending | verified | refused
  final String status;
  final String? docType;
  final String? docNumber;
  final String? maskedNumber;
  final String? fullName;
  final String? expiresOn;
  final String? refuseReason;
  /// staff | auto: how E-Ride checks it now.
  final String method;

  IdVerificationStatus({required this.status, this.docType, this.docNumber, this.maskedNumber, this.fullName, this.expiresOn, this.refuseReason, this.method = 'staff'});

  factory IdVerificationStatus.fromJson(Map<String, dynamic> j) {
    String? s(dynamic v) => v == null || '$v'.isEmpty || '$v' == 'null' ? null : '$v';
    return IdVerificationStatus(
      status: s(j['status']) ?? 'none',
      docType: s(j['doc_type']),
      docNumber: s(j['doc_number']),
      maskedNumber: s(j['masked_number']),
      fullName: s(j['full_name']),
      expiresOn: s(j['expires_on']),
      refuseReason: s(j['refuse_reason']),
      method: s(j['method']) ?? 'staff',
    );
  }

  bool get verified => status == 'verified';
  bool get pending => status == 'pending';
  bool get refused => status == 'refused';
  /// Sent and not refused: agencies can rely on it (verified) or look at it (pending).
  bool get usable => verified || pending;
}
