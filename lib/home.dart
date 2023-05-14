import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    addCustomIcon();
    super.initState();
  }

  Completer<GoogleMapController> mapController = Completer();
  // late GoogleMapController mapController;
  TextEditingController searchController = TextEditingController();
  Placemark? addressData;
  BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarker;
  // static final CameraPosition _kGoogle = const CameraPosition(
  //   target: LatLng(20.42796133580664, 80.885749655962),
  //   zoom: 14.4746,
  // );
  final Map<String, Marker> _markers = {};
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        label: Row(
          children: const [
            Text('My current location'),
            Icon(
              Icons.location_on,
              size: 18,
            )
          ],
        ),
        onPressed: () async {
          Position position = await getUserCurrentLocation();
          updateCameraPositionwithlatlong(
              position.latitude, position.longitude);
        },
      ),
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(left: 15),
                    hintText: "Search your location here....",
                    hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.normal)),
                maxLines: 1,
                controller: searchController,
              ),
            ),
            IconButton(
              onPressed: () async {
                var place = await getPlace(searchController.text);
                updateCameraPosition(place);
              },
              icon: const Icon(
                Icons.search,
              ),
            )
          ],
        ),
        centerTitle: true,
      ),
      body: FutureBuilder(
          future: getUserCurrentLocation(),
          builder: (context, AsyncSnapshot<Position> snap) {
            if (snap.hasData) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Container(
                        height: 40,
                        width: MediaQuery.of(context).size.width,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                        ),
                        child: Center(
                          child: Text(
                            addressData == null
                                ? ''
                                : "${addressData!.locality},${addressData!.street}${addressData!.subLocality},${addressData!.postalCode},${addressData!.country}",
                            style: const TextStyle(
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      )),
                      IconButton(
                          onPressed: () async {},
                          icon: const Icon(Icons.location_searching))
                    ],
                  ),
                  Expanded(
                    child: GoogleMap(
                      onTap: (argument) {
                        addMarker(
                          'test',
                          LatLng(
                            argument.latitude,
                            argument.longitude,
                          ),
                        );
                      },
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          snap.data!.latitude,
                          snap.data!.longitude,
                        ),
                        zoom: 14,
                      ),
                      onMapCreated: (controller) {
                        mapController.complete(controller);
                        addCustomMarker(
                          'CurrentLocation',
                          LatLng(
                            snap.data!.latitude,
                            snap.data!.longitude,
                          ),
                        );
                      },
                      markers: _markers.values.toSet(),
                    ),
                  ),
                ],
              );
            } else {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
          }),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future<Position> getUserCurrentLocation() async {
    await Geolocator.requestPermission()
        .then((value) {})
        .onError((error, stackTrace) async {
      await Geolocator.requestPermission();
      log("ERROR$error");
    });

    return await Geolocator.getCurrentPosition();
  }

  void addCustomIcon() {
    getBytesFromAsset('assets/new_icon.png', 140).then((onValue) {
      setState(() {
        markerIcon = BitmapDescriptor.fromBytes(onValue);
      });
    });
    // BitmapDescriptor.fromAssetImage(
    //         const ImageConfiguration(), "assets/new_icon.png")
    //     .then(
    //   (icon) {
    //     setState(() {
    //       markerIcon = icon;
    //     });
    //   },
    // );
  }

  addressSetting(String latitude, String lontitude) async {
    double latData = double.parse(latitude);
    double lonData = double.parse(lontitude);
    try {
      //       final coordinates = Coordinates(latData, lonData);

      // var address =
      //     await Geocoder.google('AIzaSyCYic5G8NQS1tnvzKNzARmOlTsUbZHNxKs')
      //         .findAddressesFromCoordinates(coordinates);
      await placemarkFromCoordinates(latData, lonData)
          .then((List<Placemark> placemarks) {
        Placemark place = placemarks.first;

        setState(() {
          addressData = place;
        });
      });
    } catch (e) {
      log("Error Occured $e");
    }
  }

  Future<void> updateCameraPositionwithlatlong(lat, lon) async {
    final GoogleMapController googleMapController = await mapController.future;
    googleMapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lon),
          zoom: 14,
        ),
      ),
    );
    await addressSetting(
      lat.toString(),
      lon.toString(),
    );
    addCustomMarker(
      'CurrentLocation',
      LatLng(
        lat,
        lon,
      ),
    );
  }

  Future<void> updateCameraPosition(Map<String, dynamic> place) async {
    final double lat = place['geometry']['location']['lat'];
    final double lon = place['geometry']['location']['lng'];
    final GoogleMapController googleMapController = await mapController.future;
    googleMapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lon),
          zoom: 14,
        ),
      ),
    );
    await addressSetting(
      lat.toString(),
      lon.toString(),
    );
    addMarker(
      'test',
      LatLng(
        lat,
        lon,
      ),
    );
  }

  getPlaceId(String query) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=$query&inputtype=textquery&key=AIzaSyCYic5G8NQS1tnvzKNzARmOlTsUbZHNxKs';
    var response = await http.get(Uri.parse(url));
    var json = jsonDecode(response.body);
    var placeId = json['candidates'][0]['place_id'] as String;
    log("message$placeId");
    return placeId;
  }

  Future<Map<String, dynamic>> getPlace(String input) async {
    String placeId = await getPlaceId(input);
    final String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=AIzaSyCYic5G8NQS1tnvzKNzARmOlTsUbZHNxKs';
    var response = await http.get(Uri.parse(url));
    var json = jsonDecode(response.body);
    var results = json['result'] as Map<String, dynamic>;
    log("Result $results");
    return results;
  }

  addMarker(String id, LatLng location) async {
    await addressSetting(
      location.latitude.toString(),
      location.longitude.toString(),
    );
    var marker = Marker(
        markerId: MarkerId(id),
        position: location,
        infoWindow: InfoWindow(
          title: addressData == null
              ? ''
              : "${addressData!.locality},${addressData!.street}${addressData!.subLocality},${addressData!.postalCode},${addressData!.country}",
        ));
    _markers[id] = marker;
  }

  static Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  addCustomMarker(String id, LatLng location) async {
    await addressSetting(
      location.latitude.toString(),
      location.longitude.toString(),
    );
    var marker = Marker(
        icon: markerIcon,
        markerId: MarkerId(id),
        position: location,
        infoWindow: InfoWindow(
          title: addressData == null
              ? ''
              : "${addressData!.locality},${addressData!.street}${addressData!.subLocality},${addressData!.postalCode},${addressData!.country}",
        ));
    _markers[id] = marker;
  }
}
