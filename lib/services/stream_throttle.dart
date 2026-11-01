import 'dart:async';

/// A StreamTransformer that throttles stream events so they are not emitted
/// faster than the specified [duration] interval.
class StreamThrottle<T> extends StreamTransformerBase<T, T> {
  final Duration duration;

  StreamThrottle(this.duration);

  @override
  Stream<T> bind(Stream<T> stream) {
    DateTime? lastEmitted;
    return stream.where((event) {
      final now = DateTime.now();
      if (lastEmitted == null || now.difference(lastEmitted!) >= duration) {
        lastEmitted = now;
        return true;
      }
      return false;
    });
  }
}

