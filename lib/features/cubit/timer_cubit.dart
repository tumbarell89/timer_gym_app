import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

class TimerState extends Equatable {
  final List<Duration> times;

  const TimerState(this.times);

  @override
  List<Object> get props => [times];
}

class TimerCubit extends Cubit<TimerState> {
  TimerCubit() : super(TimerState([]));

  void setTimes(List<Duration> times) {
    emit(TimerState(times));
  }

  List<Duration> getTimes() {
    return state.times;
  }
}