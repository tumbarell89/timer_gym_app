import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class MapScreen extends StatefulWidget {
  final List<Duration> configuredTimes;

  MapScreen({Key? key, required this.configuredTimes}) : super(key: key);

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
  Duration totalConfiguredTime = Duration.zero;
  int currentTimerIndex = 0;
  Timer? timer;
  AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    audioPlayer.setSource(AssetSource('beep.mp3'));
    totalConfiguredTime = widget.configuredTimes.fold(Duration.zero, (prev, curr) => prev + curr);
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
                  _formatDuration(elapsedTime),
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
                    onPressed: _startConfiguredRun,
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
      isPaused = false;
      elapsedTime = Duration.zero;
      routePoints.clear();
      if (currentLocation != null) {
        routePoints.add(currentLocation!);
      }
    });
    _startLocationTracking();
    _startTimer();
  }

  void _startConfiguredRun() {
    if (widget.configuredTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay tiempos configurados. Por favor, configura los tiempos en la pantalla principal.')),
      );
      return;
    }
    setState(() {
      isRunning = true;
      isPaused = false;
      elapsedTime = Duration.zero;
      currentTimerIndex = 0;
      routePoints.clear();
      if (currentLocation != null) {
        routePoints.add(currentLocation!);
      }
    });
    _startLocationTracking();
    _startConfiguredTimer();
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

  void _startTimer() {
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!isPaused) {
        setState(() {
          elapsedTime += Duration(seconds: 1);
        });
      }
    });
  }

  void _startConfiguredTimer() {
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!isPaused) {
        setState(() {
          if (widget.configuredTimes[currentTimerIndex] > Duration.zero) {
            widget.configuredTimes[currentTimerIndex] -= Duration(seconds: 1);
            elapsedTime += Duration(seconds: 1);
            
            if (widget.configuredTimes[currentTimerIndex].inSeconds <= 5 && widget.configuredTimes[currentTimerIndex].inSeconds > 0) {
              audioPlayer.play(AssetSource('beep.mp3'));
            }
          } else {
            currentTimerIndex++;
            if (currentTimerIndex >= widget.configuredTimes.length) {
              _stopRun();
            }
          }
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
      currentTimerIndex = 0;
      widget.configuredTimes.forEach((element) => element = Duration.zero);
    });
    timer?.cancel();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitHours = twoDigits(duration.inHours);
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    timer?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }
}