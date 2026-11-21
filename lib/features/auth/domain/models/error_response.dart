class ErrorResponse {
  String? responseCode;
  String? message;
  List<Errors>? errors;

  ErrorResponse(
      {this.responseCode,
        this.message,
        this.errors});

  ErrorResponse.fromJson(Map<String, dynamic> json) {
    responseCode = json['response_code'].toString();
    message = json['message'];
    final raw = json['errors'];
    if (raw is List) {
      errors = <Errors>[for (final v in raw) if (v is Map) Errors.fromJson(Map<String, dynamic>.from(v))];
    } else if (raw is Map) {
      // Laravel's own 422 shape: {"field": ["message", ...]}.
      errors = <Errors>[
        for (final e in raw.entries)
          Errors(errorCode: '${e.key}', message: e.value is List && (e.value as List).isNotEmpty ? '${(e.value as List).first}' : '${e.value}'),
      ];
    }
  }


}

class Errors {
  String? errorCode;
  String? message;

  Errors({this.errorCode, this.message});

  Errors.fromJson(Map<String, dynamic> json) {
    errorCode = json['error_code'];
    message = json['message'];
  }

}
