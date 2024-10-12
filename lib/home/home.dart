import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:convert';
import '../constanst.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native called background task: $task");
    await _updateTimersState();
    return Future.value(true);
  });
}

 Future<void> _updateTimersState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? timersJson = prefs.getString('timers');
    String? originalTimersJson = prefs.getString('originalTimers');
    bool? running = prefs.getBool('isRunning');
    bool? paused = prefs.getBool('isPaused');
    int? currentIndex = prefs.getInt('currentTimerIndex');
    String? lastUpdateTimeString = prefs.getString('lastUpdateTime');

    if (timersJson != null && originalTimersJson != null && running != null && paused != null && currentIndex != null && lastUpdateTimeString != null) {
      List<Duration> times = (json.decode(timersJson) as List).map((item) => Duration(seconds: item)).toList();
      List<Duration> originalTimes = (json.decode(originalTimersJson) as List).map((item) => Duration(seconds: item)).toList();
      bool isRunning = running;
      bool isPaused = paused;
      int currentTimerIndex = currentIndex;
      DateTime lastUpdateTime = DateTime.parse(lastUpdateTimeString);

      if (isRunning && !isPaused) {
        Duration elapsedTime = DateTime.now().difference(lastUpdateTime);
        int elapsedSeconds = elapsedTime.inSeconds;

        while (elapsedSeconds > 0 && currentTimerIndex < times.length) {
          if (times[currentTimerIndex].inSeconds <= elapsedSeconds) {
            elapsedSeconds -= times[currentTimerIndex].inSeconds;
            currentTimerIndex++;
          } else {
            times[currentTimerIndex] -= Duration(seconds: elapsedSeconds);
            break;
          }
        }

        if (currentTimerIndex >= times.length) {
          isRunning = false;
          isPaused = false;
          currentTimerIndex = 0;
          times = List.from(originalTimes);
        }

        await prefs.setString('timers', json.encode(times.map((d) => d.inSeconds).toList()));
        await prefs.setBool('isRunning', isRunning);
        await prefs.setBool('isPaused', isPaused);
        await prefs.setInt('currentTimerIndex', currentTimerIndex);
        await prefs.setString('lastUpdateTime', DateTime.now().toIso8601String());
      }
    }
  }
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Duration> times = [];
  List<Duration> originalTimes = [];
  TextEditingController hoursController = TextEditingController();
  TextEditingController minutesController = TextEditingController();
  TextEditingController secondsController = TextEditingController();
  bool isRunning = false;
  bool isPaused = false;
  int currentTimerIndex = 0;
  Timer? timer;
  AudioPlayer audioPlayer = AudioPlayer();
  DateTime? lastUpdateTime;

  @override
  void initState() {
    super.initState();
    audioPlayer.setSource(AssetSource('beep.mp3'));
    _loadTimersState();
    _initWorkManager();
  }

  void _initWorkManager() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true
    );
    await Workmanager().registerPeriodicTask(
      "1",
      "updateTimers",
      frequency: Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  Future<void> _loadTimersState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? timersJson = prefs.getString('timers');
    String? originalTimersJson = prefs.getString('originalTimers');
    bool? running = prefs.getBool('isRunning');
    bool? paused = prefs.getBool('isPaused');
    int? currentIndex = prefs.getInt('currentTimerIndex');
    String? lastUpdateTimeString = prefs.getString('lastUpdateTime');

    if (timersJson != null && originalTimersJson != null && running != null && paused != null && currentIndex != null && lastUpdateTimeString != null) {
      setState(() {
        times = (json.decode(timersJson) as List).map((item) => Duration(seconds: item)).toList();
        originalTimes = (json.decode(originalTimersJson) as List).map((item) => Duration(seconds: item)).toList();
        isRunning = running;
        isPaused = paused;
        currentTimerIndex = currentIndex;
        lastUpdateTime = DateTime.parse(lastUpdateTimeString);
      });

      if (isRunning && !isPaused) {
        _resumeTimersFromLastUpdate();
      }
    }
  }

  Future<void> _saveTimersState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('timers', json.encode(times.map((d) => d.inSeconds).toList()));
    await prefs.setString('originalTimers', json.encode(originalTimes.map((d) => d.inSeconds).toList()));
    await prefs.setBool('isRunning', isRunning);
    await prefs.setBool('isPaused', isPaused);
    await prefs.setInt('currentTimerIndex', currentTimerIndex);
    await prefs.setString('lastUpdateTime', DateTime.now().toIso8601String());
  }

  void _resumeTimersFromLastUpdate() {
    if (lastUpdateTime != null) {
      Duration elapsedTime = DateTime.now().difference(lastUpdateTime!);
      int elapsedSeconds = elapsedTime.inSeconds;

      while (elapsedSeconds > 0 && currentTimerIndex < times.length) {
        if (times[currentTimerIndex].inSeconds <= elapsedSeconds) {
          elapsedSeconds -= times[currentTimerIndex].inSeconds;
          currentTimerIndex++;
        } else {
          times[currentTimerIndex] -= Duration(seconds: elapsedSeconds);
          break;
        }
      }

      if (currentTimerIndex < times.length) {
        _runTimer();
      } else {
        _resetTimers();
      }
    }
  }

  void _addTime() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Añadir tiempo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: hoursController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 14.0),
                      decoration: InputDecoration(labelText: 'Horas'),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 14.0),
                      decoration: InputDecoration(labelText: 'Minutos'),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: secondsController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 14.0),
                      decoration: InputDecoration(labelText: 'Segundos'),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Aceptar'),
              onPressed: () {
                int hours = int.tryParse(hoursController.text) ?? 0;
                int minutes = int.tryParse(minutesController.text) ?? 0;
                int seconds = int.tryParse(secondsController.text) ?? 0;
                
                if (hours == 0 && minutes == 0 && seconds == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Por favor, introduce un tiempo válido')),
                  );
                } else {
                  Duration newTime = Duration(hours: hours, minutes: minutes, seconds: seconds);
                  setState(() {
                    times.add(newTime);
                    originalTimes.add(newTime);
                  });
                  _saveTimersState();
                  Navigator.of(context).pop();
                }
                
                hoursController.clear();
                minutesController.clear();
                secondsController.clear();
              },
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitHours = twoDigits(duration.inHours);
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _startTimers() {
    if (times.isEmpty) return;
    
    setState(() {
      isRunning = true;
      isPaused = false;
      currentTimerIndex = 0;
      lastUpdateTime = DateTime.now();
    });

    _saveTimersState();
    _runTimer();
  }

  void _runTimer() {
    if (currentTimerIndex >= times.length) {
      _resetTimers();
      return;
    }

    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!isPaused) {
        setState(() {
          if (times[currentTimerIndex] > Duration.zero) {
            times[currentTimerIndex] -= Duration(seconds: 1);
            
            if (times[currentTimerIndex].inSeconds <= 5 && times[currentTimerIndex].inSeconds > 0) {
              audioPlayer.play(AssetSource('beep.mp3'));
            }
          } else {
            timer.cancel();
            currentTimerIndex++;
            if (currentTimerIndex < times.length) {
              _runTimer();
            } else {
              _resetTimers();
            }
          }
        });
        _saveTimersState();
      }
    });
  }

  void _pauseTimer() {
    setState(() {
      isPaused = true;
    });
    _saveTimersState();
  }

  void _resumeTimer() {
    setState(() {
      isPaused = false;
      lastUpdateTime = DateTime.now();
    });
    _saveTimersState();
  }

  void _stopTimers() {
    timer?.cancel();
    _resetTimers();
  }

  void _resetTimers() {
    setState(() {
      isRunning = false;
      isPaused = false;
      currentTimerIndex = 0;
      for (int i = 0; i < times.length; i++) {
        times[i] = originalTimes[i];
      }
    });
    _saveTimersState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gym Timer'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: times.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: ListTile(
                      title: Text(
                        _formatDuration(times[index]),
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold,
                          color: index == currentTimerIndex && isRunning 
                            ? AppColors.primaryColor 
                            : Colors.black,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: AppColors.secondaryColor),
                        onPressed: isRunning ? null : () {
                          setState(() {
                            times.removeAt(index);
                            originalTimes.removeAt(index);
                          });
                          _saveTimersState();
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isRunning)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.add),
                      label: Text('Adicionar'),
                      onPressed: _addTime,
                      style: ElevatedButton.styleFrom(
                        primary: Color.fromARGB(255, 213, 77, 59),
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    )
                  ),
                if (times.isNotEmpty && !isRunning)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.play_arrow),
                      label: Text('Iniciar'),
                      onPressed: _startTimers,
                      style: ElevatedButton.styleFrom(
                        primary: Color.fromARGB(255, 213, 77, 59),
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ),
                if (isRunning && !isPaused)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child:  ElevatedButton.icon(
                      icon: Icon(Icons.pause),
                      label: Text('Pausar'),
                      onPressed: _pauseTimer,
                      style: ElevatedButton.styleFrom(
                        primary: AppColors.secondaryColor,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ),
                if (isRunning && isPaused)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.play_arrow),
                      label: Text('Reanudar'),
                      onPressed: _resumeTimer,
                      style: ElevatedButton.styleFrom(
                        primary: AppColors.primaryColor,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ),
                if (isRunning)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.stop),
                      label: Text('Detener'),
                      onPressed: _stopTimers,
                      style: ElevatedButton.styleFrom(
                        primary: Colors.red,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    hoursController.dispose();
    minutesController.dispose();
    secondsController.dispose();
    timer?.cancel();
    audioPlayer.dispose();
    Workmanager().cancelAll();
    super.dispose();
  }
}