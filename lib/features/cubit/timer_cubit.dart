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

  void addTime(Duration time) {
    final currentTimes = List<Duration>.from(state.times);
    currentTimes.add(time);
    emit(TimerState(currentTimes));
  }

  void removeTime(int index) {
    final currentTimes = List<Duration>.from(state.times);
    if (index >= 0 && index < currentTimes.length) {
      currentTimes.removeAt(index);
      emit(TimerState(currentTimes));
    }
  }

  void updateTime(int index, Duration newTime) {
    final currentTimes = List<Duration>.from(state.times);
    if (index >= 0 && index < currentTimes.length) {
      currentTimes[index] = newTime;
      emit(TimerState(currentTimes));
    }
  }

  List<Duration> getTimes() {
    return state.times;
  }
}