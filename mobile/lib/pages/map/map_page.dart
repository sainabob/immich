import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart'; // 引入 mapbox_gl 库

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late MapboxMapController mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Page'),
      ),
      body: MapboxMap(
        accessToken: 'YOUR_MAPBOX_ACCESS_TOKEN', // 替换为您的 Mapbox Access Token
        initialCameraPosition: const CameraPosition(
          target: LatLng(37.7749, -122.4194), // 初始中心点坐标
          zoom: 11.0,
        ),
        onMapCreated: (controller) {
          mapController = controller; // 地图创建完成后保存控制器
        },
        onStyleLoadedCallback: () {
          // 地图样式加载完成后的回调
          print('Map style loaded');
        },
      ),
    );
  }
}