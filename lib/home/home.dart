import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timer_gym_app/features/cubit/timer_cubit.dart';
import 'package:timer_gym_app/features/drawer_menu.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:convert';
import '../constanst.dart';// Import the TimerCubit

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
  Duration totalTime = Duration.zero;
  Duration remainingTotalTime = Duration.zero;

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
        _updateTotalTime();
        context.read<TimerCubit>().setTimes(times);
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
  
    // Actualizar el TimerCubit
    context.read<TimerCubit>().setTimes(times);
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
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          backgroundColor: Colors.white.withOpacity(0.9),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Añadir tiempo',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 213, 77, 59),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Horas',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: minutesController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Minutos',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: secondsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Segundos',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: Text('Cancelar'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      child: Text('Aceptar'),
                      style: ElevatedButton.styleFrom(
                        primary: Color.fromARGB(255, 213, 77, 59),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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
                          context.read<TimerCubit>().addTime(newTime);
                          setState(() {
                            times.add(newTime);
                            originalTimes.add(newTime);
                            _updateTotalTime();
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editTime(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController editHoursController = TextEditingController(text: times[index].inHours.toString());
        TextEditingController editMinutesController = TextEditingController(text: (times[index].inMinutes % 60).toString());
        TextEditingController editSecondsController = TextEditingController(text: (times[index].inSeconds % 60).toString());

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          backgroundColor: Colors.white.withOpacity(0.9),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Editar tiempo',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 213, 77, 59),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: editHoursController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Horas',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: editMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Minutos',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: editSecondsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Segundos',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: Text('Cancelar'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      child: Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        primary: Color.fromARGB(255, 213, 77, 59),
                        shape: RoundedRectangleBorder(
                          borderRadius:  BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        int hours = int.tryParse(editHoursController.text) ?? 0;
                        int minutes = int.tryParse(editMinutesController.text) ?? 0;
                        int seconds = int.tryParse(editSecondsController.text) ?? 0;
                        
                        if (hours == 0 && minutes == 0 && seconds == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Por favor, introduce un tiempo válido')),
                          );
                        } else {
                          Duration newTime = Duration(hours: hours, minutes: minutes, seconds: seconds);
                          setState(() {
                            times[index] = newTime;
                            originalTimes[index] = newTime;
                            _updateTotalTime();
                          });
                          _saveTimersState();
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
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
      remainingTotalTime = totalTime;
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
            remainingTotalTime -= Duration(seconds: 1);
            
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
      _updateTotalTime();
    });
    _saveTimersState();
  }

  void _updateTotalTime() {
    totalTime = times.fold(Duration.zero, (prev, curr) => prev + curr);
    if (!isRunning) {
      remainingTotalTime = totalTime;
    }
  }

  void _saveTimersPermanently() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedTimers', json.encode(originalTimes.map((d) => d.inSeconds).toList()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tiempos guardados permanentemente')),
    );
  }

  void _loadSavedTimers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedTimersJson = prefs.getString('savedTimers');
    if (savedTimersJson != null) {
      setState(() {
        originalTimes = (json.decode(savedTimersJson) as List).map((item) => Duration(seconds: item)).toList();
        times = List.from(originalTimes);
        _updateTotalTime();
      });
      _saveTimersState();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tiempos cargados')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay tiempos guardados')),
      );
    }
  }

  List<Duration> getTimes() {
    return times;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimerCubit, TimerState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Gym Timer'),
            flexibleSpace: Container(
              decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
            ),
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(
                    _formatDuration(remainingTotalTime),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          drawer: DrawerMenu(), 
          body: Builder( 
            builder: (BuildContext context) {
              return Container(
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
                              trailing: !isRunning
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit, color: AppColors.secondaryColor),
                                        onPressed: () => _editTime(index),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete, color: AppColors.secondaryColor),
                                        onPressed: () {
                                          setState(() {
                                            times.removeAt(index);
                                            originalTimes.removeAt(index);
                                            _updateTotalTime();
                                          });
                                          _saveTimersState();
                                        },
                                      ),
                                    ],
                                  )
                                : null,
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
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.add),
                              label: Text('Adicionar'),
                              onPressed: _addTime,
                              style: ElevatedButton.styleFrom(
                                primary: Color.fromARGB(255, 213, 77, 59),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            )
                          ),
                        if (times.isNotEmpty && !isRunning)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.play_arrow),
                              label: Text('Iniciar'),
                              onPressed: _startTimers,
                              style: ElevatedButton.styleFrom(
                                primary: Color.fromARGB(255, 213, 77, 59),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ),
                        if (isRunning && !isPaused)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child:  ElevatedButton.icon(
                              icon: Icon(Icons.pause),
                              label: Text('Pausar'),
                              onPressed: _pauseTimer,
                              style: ElevatedButton.styleFrom(
                                primary: AppColors.secondaryColor,
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ),
                        if (isRunning && isPaused)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.play_arrow),
                              label: Text('Reanudar'),
                              onPressed: _resumeTimer,
                              style: ElevatedButton.styleFrom(
                                primary: Color.fromARGB(255, 213, 77, 59),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ),
                        if (isRunning)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.stop),
                              label: Text('Detener'),
                              onPressed: _stopTimers,
                              style: ElevatedButton.styleFrom(
                                primary: Colors.red,
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!isRunning)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.save),
                              label: Text('Guardar'),
                              onPressed: _saveTimersPermanently,
                              style: ElevatedButton.styleFrom(
                                primary: Colors.green,
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.folder_open),
                              label: Text('Cargar'),
                              onPressed: _loadSavedTimers,
                              style: ElevatedButton.styleFrom(
                                primary: Colors.blue,
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }
          ),
        );
      },
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