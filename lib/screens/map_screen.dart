import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import "dart:math";

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  late GoogleMapController mapController;

  //   現在地を監視するためのstream
  late StreamSubscription<Position> positionStream;
  Set<Marker> markers = {};

  final CameraPosition initialCameraPosition = CameraPosition(
    target: LatLng(35.681236, 139.767125),// 東京駅
    zoom: 16.0,
  );

  // 現在地通知の設定
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high, //正確性:highはAndroid(0-100m),iOS(10m)
    distanceFilter: 0,
  );

  // 目的地の緯度・経度
  late LatLng target;

  @override
  void dispose() { //終了時に実行
    mapController.dispose();
    // Streamを閉じる
    positionStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) { //画面表示
    return Scaffold(
        body: Column(children: <Widget>[
      Container(
        width: double.infinity,
        height: 700,
        child: GoogleMap(
          initialCameraPosition: initialCameraPosition,
          onMapCreated: (GoogleMapController controller) async {
            mapController = controller;
            await _requestPermission();
            await _moveToCurrentLocation();
            _watchCurrentLocation();
          },
          onLongPress: (LatLng latLang) {
            setState(() {
              markers.add(Marker(
                markerId: const MarkerId('tapped_location'),
                position: LatLng(
                  latLang.latitude,
                  latLang.longitude,
                ),
              ));
              target = latLang;
            });
          },
          myLocationButtonEnabled: false,
          markers: markers,
        ),
      ),
      Center(
        child: OutlinedButton(
          onPressed: _showNotification, //_showNotification,
          child: Text('目的地までの距離を表示'),
        ),
      ),
    ]));
  }

  @override
  void initState() { //初期化処理
    super.initState();

    _initializePlatformsSpecifics();

    target = LatLng(0,0);
  }

  void _initializePlatformsSpecifics() { //通知の初期化
    var initializationSettingsAndroid =
        AndroidInitializationSettings("app_icon");

    var initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initializationSettings,);
  }

  void _watchCurrentLocation() { //現在地を調べる
    // 現在地を監視
    positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((position) async {
      // マーカーの位置を更新
      setState(() {
        markers.removeWhere(
            (marker) => marker.markerId == const MarkerId('current_location'));

        markers.add(Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            position.latitude,
            position.longitude,
          ),
        ));
        print("------------------------------------------");
        print(position);
        print(distanceBetween(
          // 現在地
          position.latitude,
          position.longitude,
          // 目的地
          target.latitude,
          target.longitude,
        ));
        print("------------------------------------------");
        var d = distanceBetween(
          // 現在地
          position.latitude,
          position.longitude,
          // 目的地
          target.latitude,
          target.longitude,
        );
        if (d < 100) {
          _showNotification();
        }

      });
      // 現在地にカメラを移動
      await mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16.0,
          ),
        ),
      );
    });
  }

  Future<void> _showNotification() async { //通知を表示
    var androidChannelSpecifics = AndroidNotificationDetails(
      'CHANNEL_ID',
      'CHANNEL_NAME',
      channelDescription: "CHANNEL_DESCRIPTION",
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
      timeoutAfter: 5000,
      styleInformation: DefaultStyleInformation(true, true),
    );

    var platformChannelSpecifics =
        NotificationDetails(android: androidChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      '位置情報アラームアプリ', // Notification Title
      '目的地に近づいています。', // Notification Body, set as null to remove the body
      platformChannelSpecifics,
      payload: 'New Payload', // Notification Payload
    );
  }


  Future<void> _requestPermission() async { //通知の初期化設定
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> _moveToCurrentLocation() async { //マップを現在地に移動
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      // 現在地を取得
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        markers.add(Marker(
          markerId: const MarkerId("current_location"),
          position: LatLng(
            position.latitude,
            position.longitude,
          ),
        ));
      });

      // 現在地にカメラを移動
      await mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16,
          ),
        ),
      );
    }
  }

  double distanceBetween( //緯度・経度から距離計算
      double latitude1,
      double longitude1,
      double latitude2,
      double longitude2,
      ) {
    final toRadians = (double degree) => degree * pi / 180;
    final double r = 6378137.0; // 地球の半径
    final double f1 = toRadians(latitude1);
    final double f2 = toRadians(latitude2);
    final double l1 = toRadians(longitude1);
    final double l2 = toRadians(longitude2);
    final num a = pow(sin((f2 - f1) / 2), 2);
    final double b = cos(f1) * cos(f2) * pow(sin((l2 - l1) / 2), 2);
    final double d = 2 * r * asin(sqrt(a + b));
    return d;
  }
}
