import 'package:flutter_test/flutter_test.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/need_finder.dart';

void main() {
  const all = {'ride', 'health', 'parcel', 'move', 'food', 'bus', 'explore', 'hotels', 'market', 'jobs'};
  final finder = NeedFinder(const NeedContext(
    services: all,
    exploreKeys: {'pharmacy', 'health', 'bank', 'stay', 'homes', 'bus'},
    busPlaces: [
      BusPlace(city: 'Douala', from: 'Bamenda', fare: 5000, departures: 6),
      BusPlace(city: 'Yaoundé', from: 'Bamenda', fare: 6000, departures: 4),
      BusPlace(city: 'Buea', from: 'Bamenda', fare: 4500, departures: 3),
    ],
    stores: [
      StorePlace(id: 's1', name: 'Romz'),
      StorePlace(id: 's2', name: 'Le Bon Goût', openNow: false),
      StorePlace(id: 's3', name: 'Candy Shop'),
    ],
    extraWords: [SearchWords(type: 'food', words: ['Corn chaff', 'Nkui'])],
  ));

  String top(String q) => finder.find(q).map((h) => '${h.type}${h.id != null ? ':${h.id}' : ''}${h.city != null ? '>${h.city}' : ''}${h.storeId != null ? '#${h.storeId}' : ''}').join(', ');

  test('normalize drops accents, case and punctuation', () {
    expect(NeedFinder.normalize('  Pharmacie  de GARDE! '), 'pharmacie de garde');
    expect(NeedFinder.normalize("Hôpital, l'Hôtel"), 'hopital l hotel');
    expect(NeedFinder.normalize('Œuvre'), 'oeuvre');
  });

  test('pharmacy in three languages, with a ride there second', () {
    expect(top('pharmacie'), startsWith('explore:pharmacy, health_ride'));
    expect(top('pharmacy'), startsWith('explore:pharmacy'));
    expect(top('Pharmacie de garde'), startsWith('explore:pharmacy'));
    expect(top('pharmcie'), startsWith('explore:pharmacy')); // one slip
    expect(top('phar'), startsWith('explore:pharmacy')); // still typing
  });

  test('hospitals, banks, hotels, homes', () {
    expect(top('hôpital'), startsWith('explore:health'));
    expect(top('i no well'), contains('explore:health'));
    expect(top('ATM'), startsWith('explore:bank'));
    expect(top('afriland'), startsWith('explore:bank'));
    expect(top('auberge'), startsWith('explore:stay'));
    expect(top('chambre a louer'), startsWith('explore:homes'));
    expect(top('urgence'), startsWith('health_ride'));
  });

  test('bus to a city, with the day', () {
    final hits = finder.find('bus Douala demain');
    expect(hits.first.type, 'bus');
    expect(hits.first.city, 'Douala');
    expect(hits.first.from, 'Bamenda');
    expect(hits.first.dayOffset, 1);
    expect(hits.any((h) => h.type == 'ride_later'), isFalse);
    expect(hits.where((h) => h.type == 'bus').length, 1);
    expect(finder.find('yaounde').first.city, 'Yaoundé');
    expect(finder.find('dla').first.city, 'Douala');
    expect(finder.find('Douala after tomorrow').first.dayOffset, 2);
    expect(finder.find('bus').first.city, isNull);
  });

  test('food words, dishes and stores by name', () {
    expect(top('chop'), startsWith('food'));
    expect(top('ndolé'), startsWith('food'));
    expect(top('j ai faim'), startsWith('food'));
    expect(top('Romz'), startsWith('store#s1'));
    expect(top('rom'), startsWith('store#s1'));
    expect(top('bon gout'), startsWith('store#s2'));
    expect(finder.find('bon gout').first.open, isFalse);
    expect(top('candy'), startsWith('store#s3'));
  });

  test('market and jobs search for what is left', () {
    final phone = finder.find('buy phone').firstWhere((h) => h.type == 'market');
    expect(phone.query, 'phone');
    expect(finder.find('sell').firstWhere((h) => h.type == 'market').query, isNull);
    final driver = finder.find('driver job').firstWhere((h) => h.type == 'jobs');
    expect(driver.query, 'driver');
    expect(top('travail'), startsWith('jobs'));
  });

  test('parcel, move, later, id, activity, support', () {
    expect(top('colis'), startsWith('parcel'));
    expect(top('déménagement'), startsWith('move'));
    expect(top('camion'), startsWith('move'));
    expect(top('demain'), startsWith('ride_later'));
    expect(top('passport'), startsWith('id_verify'));
    expect(top('where is my order'), contains('activity'));
    expect(top('service client'), startsWith('support'));
  });

  test('words the admin added', () {
    expect(top('corn chaff'), startsWith('food'));
    expect(top('nkui'), startsWith('food'));
  });

  test('services that are off are never offered', () {
    final noBus = NeedFinder(const NeedContext(services: {'ride', 'food'}, busPlaces: [BusPlace(city: 'Douala', from: 'Bamenda')]));
    expect(noBus.find('bus Douala'), isEmpty);
    expect(noBus.find('pharmacie'), isEmpty); // Explore off
    final noPharmacyCategory = NeedFinder(const NeedContext(services: {'explore', 'health'}, exploreKeys: {'bank'}));
    expect(noPharmacyCategory.find('pharmacie').map((h) => h.type), ['health_ride']);
  });

  test('addresses stay addresses', () {
    expect(finder.find('Up Station'), isEmpty);
    expect(finder.find('Mile 4 Nkwen'), isEmpty);
    expect(finder.find('Commercial Avenue'), isEmpty);
    expect(finder.find('a'), isEmpty);
  });

  test('questions for Ask E-Ride', () {
    expect(finder.looksLikeQuestion('how do I pay for food?'), isTrue);
    expect(finder.looksLikeQuestion('comment payer'), isTrue);
    expect(finder.looksLikeQuestion('wetin be health ride'), isTrue);
    expect(finder.looksLikeQuestion('Up Station'), isFalse);
  });
}
