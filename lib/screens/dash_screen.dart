import 'dart:async';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speed_ometer/components/coolbuttion.dart';
import 'package:speed_ometer/components/speedometer.dart';

/// Current Velocity in m/s

class DashScreen extends StatefulWidget {
  const DashScreen({this.unit = 'm/s', Key? key}) : super(key: key);

  final String unit;

  @override
  _DashScreenState createState() => _DashScreenState();
}

class _DashScreenState extends State<DashScreen> {
  SharedPreferences? _sharedPreferences;
  double? _velocity;
  double chimeSpeed = 40;

  // For text to speed naration of current velocity
  /// String that the tts will read aloud, Speed + Expanded Unit
  String get speakText {
    String unit;
    switch (widget.unit) {
      case 'km/h':
        unit = 'kilometers per hour';
        break;

      case 'miles/h':
        unit = 'miles per hour';
        break;

      case 'm/s':
      default:
        unit = 'meters per second';
        break;
    }
    return '${convertedVelocity(_velocity)!.toStringAsFixed(2)} $unit';
  }

  /// Utility function to deserialize saved Duration
  Duration _secondsToDuration(int seconds) {
    int minutes = (seconds / 60).floor();
    return Duration(minutes: minutes, seconds: seconds % 60);
  }

  // For velocity Tracking
  /// Geolocator is used to find velocity
  GeolocatorPlatform locator = GeolocatorPlatform.instance;

  /// Stream that emits values when velocity updates
  late StreamController<double?> _velocityUpdatedStreamController;

  /// Highest recorded velocity so far in m/s.
  double? _highestVelocity;

  /// Velocity in m/s to km/hr converter
  double mpstokmph(double mps) => mps * 18 / 5;

  /// Velocity in m/s to miles per hour converter
  double mpstomilesph(double mps) => mps * 85 / 38;

  /// Relevant velocity in chosen unit
  double? convertedVelocity(double? velocity) {
    velocity = velocity ?? _velocity;

    if (widget.unit == 'm/s') {
      return velocity;
    } else if (widget.unit == 'km/h') {
      return mpstokmph(velocity!);
    } else if (widget.unit == 'miles/h') {
      return mpstomilesph(velocity!);
    }
    return velocity;
  }

  audioPlayer() async {
    if ((_velocity ?? 0) > chimeSpeed) {
      print("Sound Played");
      AssetsAudioPlayer.newPlayer().open(
        Audio("audio/chime.mp3"),
        autoStart: true,
      );
    }
  }

  @override
  void initState() {
    Timer.periodic(Duration(seconds: 1, milliseconds: 250), (Timer timer) {
      audioPlayer();
    });
    super.initState();
    // Speedometer functionality. Updates any time velocity chages.
    _velocityUpdatedStreamController = StreamController<double?>();
    locator
        .getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
          ),
        )
        .listen(
          (Position position) => _onAccelerate(position.speed),
        );

    // Set velocities to zero when app opens
    _velocity = 0;
    _highestVelocity = 0.0;
    // Load Saved values (or default values when no saved values)
    SharedPreferences.getInstance().then(
      (SharedPreferences prefs) {
        _sharedPreferences = prefs;
      },
    );
  }

  /// Callback that runs when velocity updates, which in turn updates stream.
  void _onAccelerate(double speed) {
    locator.getCurrentPosition().then(
      (Position updatedPosition) {
        _velocity = (speed + updatedPosition.speed) / 2;
        if (_velocity! > _highestVelocity!) _highestVelocity = _velocity;
        _velocityUpdatedStreamController.add(_velocity);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const double gaugeBegin = 0, gaugeEnd = 200;
    // audioPlayer();
    return ListView(
      scrollDirection: Axis.vertical,
      children: <Widget>[
        // StreamBuilder updates Speedometer when new velocity recieved
        StreamBuilder<Object?>(
          stream: _velocityUpdatedStreamController.stream,
          builder: (context, snapshot) {
            return Speedometer(
              gaugeBegin: gaugeBegin,
              gaugeEnd: gaugeEnd,
              velocity: convertedVelocity(_velocity),
              maxVelocity: convertedVelocity(_highestVelocity),
              velocityUnit: widget.unit,
            );
          },
        ),
        const SizedBox(
          height: 30,
        ),

        SizedButton(
          onPressed: () {},
          text: "Start Speed Set At " + chimeSpeed.toString(),
          width: 100,
          height: 30,
          fontSize: 12,
        ),
        const SizedBox(
          height: 30,
        ),
        SizedButton(
          onPressed: () async {
            chimeSpeed = chimeSpeed + 5;
            setState(() {});
          },
          text: "Increase By 5",
          width: 100,
          height: 30,
          fontSize: 12,
        ),
        const SizedBox(
          height: 30,
        ),
        SizedButton(
          onPressed: () {
            chimeSpeed = chimeSpeed - 5;
            setState(() {});
          },
          text: "Decrease By 5",
          width: 100,
          height: 30,
          fontSize: 12,
        )
      ],
    );
  }

  @override
  void dispose() {
    // Velocity Stream
    _velocityUpdatedStreamController.close();
    super.dispose();
  }
}
