abstract class TripShareRepositoryInterface {
  Future<dynamic> getShareLink(String tripId);
  Future<dynamic> stopSharing(String tripId);
  Future<dynamic> getContacts();
  Future<dynamic> addContact(String name, String phone);
  Future<dynamic> updateContact(String id, String name, String phone);
  Future<dynamic> deleteContact(String id);
}
