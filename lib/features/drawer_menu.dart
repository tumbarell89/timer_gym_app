import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timer_gym_app/features/cubit/timer_cubit.dart';

class DrawerMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Text(
              'Gym Timer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('Inicio'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
          ListTile(
            leading: Icon(Icons.map),
            title: Text('Mapa de Carrera'),
            onTap: () {
              Navigator.pop(context);
              final timerCubit = context.read<TimerCubit>();
              Navigator.pushNamed(
                context,
                '/map',
                arguments: timerCubit.state.times,
              );
            },
          ),
        ],
      ),
    );
  }
}