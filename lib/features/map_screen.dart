import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timer_gym_app/features/cubit/timer_cubit.dart';

class MapScreen extends StatefulWidget {
  final List<Duration> configuredTimes;

  MapScreen({Key? key, required this.configuredTimes}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController mapController = MapController();
  LatLng? currentLocation;
  LatLng? startLocation;
  List<LatLng> routePoints = [];
  bool isRunning = false;
  bool isPaused = false;
  Duration elapsedTime = Duration.zero;
  Duration remainingTime = Duration.zero;
  int currentTimerIndex = 0;
  Timer? timer;
  AudioPlayer audioPlayer = AudioPlayer();
  bool isConfiguredRun = false;
  double totalDistance = 0;
  double currentSpeed = 0;
  DateTime? lastLocationTime;
  List<Duration> originalConfiguredTimes = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    audioPlayer.setSource(AssetSource('beep.mp3'));
    remainingTime = Duration.zero;
    originalConfiguredTimes = List.from(widget.configuredTimes);

    if (widget.configuredTimes.isNotEmpty) {
      context.read<TimerCubit>().setTimes(widget.configuredTimes);
    }
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
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                isRunning ? _formatDuration(isConfiguredRun ? remainingTime : elapsedTime) : '00:00:00',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
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
                        if (startLocation != null)
                          Marker(
                            point: startLocation!,
                            width: 80.0,
                            height: 80.0,
                            builder: (ctx) => Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 40.0,
                            ),
                          ),
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
          if ((isPaused || !isRunning) && routePoints.isNotEmpty)
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Distancia: ${totalDistance.toStringAsFixed(2)} km'),
                    Text('Velocidad: ${currentSpeed.toStringAsFixed(2)} km/h'),
                  ],
                ),
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
      remainingTime = Duration.zero;
      isConfiguredRun = false;
      routePoints.clear();
      totalDistance = 0;
      currentSpeed = 0;
      startLocation = currentLocation;
      if (currentLocation != null) {
        routePoints.add(currentLocation!);
      }
    });
    _startLocationTracking();
    _startTimer();
  }

  void _startConfiguredRun() {
    if (originalConfiguredTimes.isEmpty) {
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
      isConfiguredRun = true;
      routePoints.clear();
      totalDistance = 0;
      currentSpeed = 0;
      startLocation = currentLocation;
      if (currentLocation != null) {
        routePoints.add(currentLocation!);
      }
      widget.configuredTimes.clear();
      widget.configuredTimes.addAll(originalConfiguredTimes);
      remainingTime = widget.configuredTimes.fold(Duration.zero, (prev, curr) => prev + curr);
    });
    _startLocationTracking();
    _startTimer();
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
          if (routePoints.isNotEmpty) {
            totalDistance += Geolocator.distanceBetween(
              routePoints.last.latitude,
              routePoints.last.longitude,
              newPoint.latitude,
              newPoint.longitude,
            ) / 1000; // Convert to kilometers
          }
          routePoints.add(newPoint);
          currentLocation = newPoint;
          mapController.move(newPoint, mapController.zoom);

          if (lastLocationTime != null) {
            Duration timeDiff = DateTime.now().difference(lastLocationTime!);
            double distanceInKm = Geolocator.distanceBetween(
              routePoints[routePoints.length - 2].latitude,
              routePoints[routePoints.length - 2].longitude,
              newPoint.latitude,
              newPoint.longitude,
            ) / 1000;
            currentSpeed = (distanceInKm / timeDiff.inSeconds) * 3600; // km/h
          }
          lastLocationTime = DateTime.now();
        });
      }
    });
  }

  void _startTimer() {
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!isPaused) {
        setState(() {
          if (isConfiguredRun) {
            if (remainingTime > Duration.zero) {
              remainingTime -= Duration(seconds: 1);
              elapsedTime += Duration(seconds: 1);

              if (widget.configuredTimes[currentTimerIndex].inSeconds <= 5 && widget.configuredTimes[currentTimerIndex].inSeconds > 0) {
                audioPlayer.play(AssetSource('beep.mp3'));
              }

              if (widget.configuredTimes[currentTimerIndex] > Duration.zero) {
                widget.configuredTimes[currentTimerIndex] -= Duration(seconds: 1);
              } else {
                currentTimerIndex++;
                if (currentTimerIndex >= widget.configuredTimes.length) {
                  _stopRun();
                }
              }
            } else {
              _stopRun();
            }
          } else {
            elapsedTime += Duration(seconds: 1);
            remainingTime = elapsedTime;
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
      lastLocationTime = DateTime.now();
    });
  }

  void _stopRun() {
    setState(() {
      isRunning = false;
      isPaused = false;
      elapsedTime = Duration.zero;
      currentTimerIndex = 0;
      remainingTime = isConfiguredRun ? originalConfiguredTimes.fold(Duration.zero, (prev, curr) => prev + curr) : Duration.zero;
      isConfiguredRun = false;
      widget.configuredTimes.clear();
      widget.configuredTimes.addAll(originalConfiguredTimes);
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