import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController mapController = MapController();
  LatLng? currentLocation;
  List<LatLng> routePoints = [];
  bool isRunning = false;
  bool isPaused = false;
  Duration elapsedTime = Duration.zero;
  Duration configuredTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
      if (mapController != null) {
        mapController.move(currentLocation!, 15.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mapa de Carrera'),
        actions: [
          if (isRunning)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Text(
                  _formatDuration(configuredTime > Duration.zero ? configuredTime - elapsedTime : elapsedTime),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!isRunning)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _startFreeRun,
                    child: Text('Iniciar Libre'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _startConfiguredRun(Duration(minutes: 30));
                    },
                    child: Text('Iniciar Configurado'),
                  ),
                ],
              ),
            ),
          if (isRunning)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: isPaused ? _resumeRun : _pauseRun,
                    child: Text(isPaused ? 'Reanudar' : 'Pausar'),
                  ),
                  ElevatedButton(
                    onPressed: _stopRun,
                    child: Text('Detener'),
                    style: ElevatedButton.styleFrom(primary: Colors.red),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                center: currentLocation ?? LatLng(0, 0),
                zoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    if (currentLocation != null)
                      Marker(
                        point: currentLocation!,
                        width: 80.0,
                        height: 80.0,
                        builder: (ctx) => Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40.0,
                        ),
                      ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4.0,
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startFreeRun() {
    setState(() {
      isRunning = true;
      routePoints.clear();
      if (currentLocation != null) {
        routePoints.add(currentLocation!);
      }
    });
    _startLocationTracking();
  }

  void _startConfiguredRun(Duration configuredTime) {
    setState(() {
      isRunning = true;
      this.configuredTime = configuredTime;
      routePoints.clear();
      if (currentLocation != null) {
        routePoints.add(currentLocation!);
      }
    });
    _startLocationTracking();
  }

  void _startLocationTracking() {
    Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (isRunning && !isPaused) {
        setState(() {
          LatLng newPoint = LatLng(position.latitude, position.longitude);
          routePoints.add(newPoint);
          mapController.move(newPoint, mapController.zoom);
        });
      }
    });
  }

  void _pauseRun() {
    setState(() {
      isPaused = true;
    });
  }

  void _resumeRun() {
    setState(() {
      isPaused = false;
    });
  }

  void _stopRun() {
    setState(() {
      isRunning = false;
      isPaused = false;
      elapsedTime = Duration.zero;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}