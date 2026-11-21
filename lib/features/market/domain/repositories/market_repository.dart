import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/market/domain/repositories/market_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class MarketRepository implements MarketRepositoryInterface {
  final ApiClient apiClient;
  MarketRepository({required this.apiClient});

  static const String _m = AppConstants.market;

  List<MultipartBody> _files(String key, List<XFile> files) =>
      [for (int i = 0; i < files.length; i++) MultipartBody('$key[$i]', files[i])];

  @override
  Future getMeta() => apiClient.getData('$_m/meta');

  @override
  Future getFeed(Map<String, dynamic> query, int offset) => apiClient.getData('$_m/feed', query: {...query, 'limit': 20, 'offset': offset});

  @override
  Future getTagSuggestions(Map<String, dynamic> query) => apiClient.getData('$_m/tags/suggest', query: query);

  @override
  Future getShop(String slug) => apiClient.getData('$_m/shops/$slug');

  @override
  Future getItem(String code) => apiClient.getData('$_m/items/$code');

  @override
  Future follow(String slug, bool on, bool? notify) =>
      apiClient.postData('$_m/shops/$slug/follow', {'on': on ? 1 : 0, if (notify != null) 'notify': notify ? 1 : 0});

  @override
  Future block(String slug, bool on) => apiClient.postData('$_m/shops/$slug/block', {'on': on ? 1 : 0});

  @override
  Future reportItem(String code, String reason, String? note, bool block) => apiClient.postData('$_m/items/$code/report',
      {'reason': reason, if (note != null && note.isNotEmpty) 'note': note, 'block': block ? 1 : 0});

  @override
  Future reportShop(String slug, String reason, String? note, bool block) => apiClient.postData('$_m/shops/$slug/report',
      {'reason': reason, if (note != null && note.isNotEmpty) 'note': note, 'block': block ? 1 : 0});

  @override
  Future claimReferral(String target) => apiClient.postData('$_m/referral', {'target': target});

  @override
  Future getMyShop() => apiClient.getData('$_m/shop');

  @override
  Future saveShop(Map<String, String> fields, XFile? logo, {XFile? shopfront}) =>
      apiClient.postMultipartData('$_m/shop', fields, MultipartBody('logo', logo), [if (shopfront != null) MultipartBody('shopfront', shopfront)]);

  @override
  Future getVenues({double? lat, double? lng}) =>
      apiClient.getData('$_m/venues${lat != null && lng != null ? '?lat=$lat&lng=$lng' : ''}');

  @override
  Future getVenue(String slug, {String query = '', bool verifiedOnly = false, String? block, String? building}) => apiClient.getData(
      '$_m/venues/$slug?q=${Uri.encodeQueryComponent(query)}${verifiedOnly ? '&verified=1' : ''}'
      '${block != null ? '&block=${Uri.encodeQueryComponent(block)}' : ''}${building != null ? '&building=${Uri.encodeQueryComponent(building)}' : ''}');

  @override
  Future requestVerification() => apiClient.postData('$_m/shop/verification', {});

  @override
  Future createItem(Map<String, String> fields, List<XFile> photos, List<XFile> previews) => apiClient.postMultipartData(
      '$_m/items', fields, MultipartBody('', null), [..._files('photos', photos), ..._files('previews', previews)]);

  @override
  Future updateItem(String code, Map<String, String> fields, List<XFile> photos, List<int> removePhotoIds, List<XFile> previews) =>
      apiClient.postMultipartData(
        '$_m/items/$code/update',
        {...fields, for (int i = 0; i < removePhotoIds.length; i++) 'remove_photo_ids[$i]': '${removePhotoIds[i]}'},
        MultipartBody('', null),
        [..._files('photos', photos), ..._files('previews', previews)],
      );

  @override
  Future setSoldOut(String code, bool soldOut) => apiClient.postData('$_m/items/$code/sold-out', {'sold_out': soldOut ? 1 : 0});

  @override
  Future deleteItem(String code) => apiClient.postData('$_m/items/$code/delete', {});

  @override
  Future getChats() => apiClient.getData('$_m/chats');

  @override
  Future startChat(String code) => apiClient.postData('$_m/items/$code/chat', {});

  @override
  Future getMessages(String chatId, String? after) =>
      apiClient.getData('$_m/chats/$chatId/messages', query: {if (after != null) 'after': after});

  @override
  Future sendMessage(String chatId, Map<String, String> fields, XFile? photo) => photo == null
      ? apiClient.postData('$_m/chats/$chatId/messages', fields)
      : apiClient.postMultipartData('$_m/chats/$chatId/messages', fields, MultipartBody('photo', photo), const []);

  @override
  Future blockBuyer(String chatId, bool on) => apiClient.postData('$_m/chats/$chatId/block-buyer', {'on': on ? 1 : 0});

  // ---------------------------------------------------------------- orders

  @override
  Future placeOrder(Map<String, dynamic> body) => apiClient.postData('$_m/orders', body);

  @override
  Future getOrders(String role, String tab, int offset) =>
      apiClient.getData('$_m/orders', query: {'role': role, 'tab': tab, 'offset': offset, 'limit': 20});

  @override
  Future getOrder(String id) => apiClient.getData('$_m/orders/$id');

  @override
  Future respondOrder(String id, List<Map<String, dynamic>> lines) => apiClient.postData('$_m/orders/$id/respond', {'lines': jsonEncode(lines)});

  @override
  Future declineOrder(String id, String reason, String? note, bool soldOut) => apiClient.postData('$_m/orders/$id/decline',
      {'reason': reason, if (note != null && note.isNotEmpty) 'note': note, 'sold_out': soldOut ? 1 : 0});

  @override
  Future agreeOrder(String id) => apiClient.postData('$_m/orders/$id/agree', {});

  @override
  Future cancelOrder(String id, String? reason) => apiClient.postData('$_m/orders/$id/cancel', {if (reason != null && reason.isNotEmpty) 'reason': reason});

  @override
  Future readyOrder(String id) => apiClient.postData('$_m/orders/$id/ready', {});

  @override
  Future attachTrip(String id, String tripId) => apiClient.postData('$_m/orders/$id/trip', {'trip_id': tripId});

  @override
  Future completeOrder(String id, String code) => apiClient.postData('$_m/orders/$id/complete', {'code': code});

  @override
  Future reviewOrder(String id, int stars, List<String> tags, String? comment) => apiClient.postData('$_m/orders/$id/review',
      {'stars': stars, 'tags': jsonEncode(tags), if (comment != null && comment.isNotEmpty) 'comment': comment});

  @override
  Future saveOrderSettings(Map<String, dynamic> body) => apiClient.postData('$_m/shop/order-settings', body);

  @override
  Future getReviews(String slug) => apiClient.getData('$_m/shops/$slug/reviews');

  // ---------------------------------------------------------------- auctions

  @override
  Future bid(String code, double amount) => apiClient.postData('$_m/items/$code/bid', {'amount': amount});

  @override
  Future getBids(String code) => apiClient.getData('$_m/items/$code/bids');

  @override
  Future auctionOfferNext(String code) => apiClient.postData('$_m/items/$code/auction/offer-next', {});

  @override
  Future auctionAnswer(String code, bool accept) => apiClient.postData('$_m/items/$code/auction/answer', {'accept': accept ? 1 : 0});

  @override
  Future auctionRelist(String code, int days) => apiClient.postData('$_m/items/$code/auction/relist', {'auction_days': days});

  @override
  Future paymentArranged(String orderId) => apiClient.postData('$_m/orders/$orderId/payment-arranged', {});

  @override
  Future noShow(String orderId) => apiClient.postData('$_m/orders/$orderId/no-show', {});

  // ---------------------------------------------------------------- services

  @override
  Future getSlots(String code, String? date, String? ignore) =>
      apiClient.getData('$_m/items/$code/slots', query: {if (date != null) 'date': date, if (ignore != null) 'ignore': ignore});

  @override
  Future book(String code, Map<String, dynamic> body) => apiClient.postData('$_m/items/$code/book', body);

  @override
  Future requestQuote(String code, Map<String, String> fields, List<XFile> photos) =>
      apiClient.postMultipartData('$_m/items/$code/quote', fields, MultipartBody('', null), _files('photos', photos));

  @override
  Future getBookings(String role, String tab, String? date) =>
      apiClient.getData('$_m/bookings', query: {'role': role, 'tab': tab, if (date != null) 'date': date});

  @override
  Future getBooking(String id) => apiClient.getData('$_m/bookings/$id');

  /// accept, decline, suggest, send-quote, agree, refuse, reschedule, cancel, complete, no-show, review
  @override
  Future bookingAction(String id, String action, Map<String, dynamic> body) => apiClient.postData('$_m/bookings/$id/$action', body);

  @override
  Future saveServiceSettings(Map<String, dynamic> body) => apiClient.postData('$_m/shop/service-settings', body);
}
