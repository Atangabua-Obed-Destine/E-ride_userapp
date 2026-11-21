abstract class DepositRepositoryInterface {
  Future<dynamic> getDeposit(String tripId);
  Future<dynamic> payWithWallet(String tripId);
  Future<dynamic> getPayUrl(String tripId, String paymentMethod);
  Future<dynamic> getReportReasons();
  Future<dynamic> reportDriver(String tripId, String reason, String comment);
}
