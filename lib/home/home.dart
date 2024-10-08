import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../constanst.dart';

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
  int currentTimerIndex = 0;
  Timer? timer;
  AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    audioPlayer.setSource(AssetSource('beep.mp3'));
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
                      decoration: InputDecoration(labelText: 'Horas'),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Minutos'),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: secondsController,
                      keyboardType: TextInputType.number,
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
      currentTimerIndex = 0;
    });

    _runTimer();
  }

  void _runTimer() {
    if (currentTimerIndex >= times.length) {
      setState(() {
        isRunning = false;
        currentTimerIndex = 0;
        // Restaurar todos los timers a sus valores originales
        for (int i = 0; i < times.length; i++) {
          times[i] = originalTimes[i];
        }
      });
      return;
    }

    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (times[currentTimerIndex] > Duration.zero) {
          times[currentTimerIndex] -= Duration(seconds: 1);
          
          // Reproducir sonido en los últimos 5 segundos
          if (times[currentTimerIndex].inSeconds <= 5 && times[currentTimerIndex].inSeconds > 0) {
            audioPlayer.play(AssetSource('beep.mp3'));
          }
        } else {
          timer.cancel();
          currentTimerIndex++;
          if (currentTimerIndex < times.length) {
            _runTimer();
          } else {
            isRunning = false;
            currentTimerIndex = 0;
            // Restaurar todos los timers a sus valores originales
            for (int i = 0; i < times.length; i++) {
              times[i] = originalTimes[i];
            }
          }
        }
      });
    });
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
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Adicionar'),
                    onPressed: isRunning ? null : _addTime,
                    style: ElevatedButton.styleFrom(
                      primary: AppColors.primaryColor,
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
                      primary: AppColors.primaryColor,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                )
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
    super.dispose();
  }
}