import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timer_gym_app/features/cubit/timer_cubit.dart';
import 'package:timer_gym_app/features/map_screen.dart';
import 'package:timer_gym_app/home/home.dart';
import 'package:timer_gym_app/home/splash.dart';

void main() {
  runApp(
    BlocProvider(
      create: (context) => TimerCubit(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Timer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/home': (context) => HomeScreen(),
        '/map': (context) {
          final timerCubit = context.read<TimerCubit>();
          return MapScreen(configuredTimes: timerCubit.state.times);
        },
      },
    );
  }
}