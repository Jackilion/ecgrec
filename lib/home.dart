import 'dart:async';

import 'package:flutter/material.dart';
import 'package:polar/polar.dart';
import 'package:system_clock/system_clock.dart';

import 'home_screen_contents.dart';
import 'io_manager.dart';
import 'settings.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

enum ConnectingState {
  connecting,
  connected,
  idle,
  initRecording,
  recording,
  recordingStopped,
  error
}

class _HomeState extends State<Home> {
  final polar = Polar();
  //final identifier = "94FF4C29";
  final IOManager ioManager = IOManager();
  //state variables:
  ConnectingState connectingState = ConnectingState.idle;

  StreamSubscription<PolarDeviceInfo>? connectedStreamSubscription;
  StreamSubscription<PolarHeartRateEvent>? hearRateStreamSubscription;
  StreamSubscription<PolarEcgData>? ecgStreamSubscription;
  StreamSubscription<PolarDeviceInfo>? disconnectedStreamSubscription;
  int heartRate = 0;

  @override
  void initState() {
    super.initState();
  }

  void connect() async {
    if (ioManager.deviceId == "none") {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text("Fehler"),
                content: const Text(
                    "Es wurde keine device Id gesetzt. Bitte kontaktiere einen HU Mitarbeiter."),
                actions: [
                  TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text("Okay"))
                ],
              ));
      return;
    }
    setState(() {
      connectingState = ConnectingState.connecting;
    });
    ioManager
        .logToFile("Connecting to Polar H10 with ID: ${ioManager.deviceId}");
    polar.disconnectFromDevice(ioManager.deviceId);

    disconnectedStreamSubscription =
        polar.deviceDisconnectedStream.listen((event) async {
      ioManager.logToFile(
          "Polar DisconnectedStream fired, with isConnectable = ${event.isConnectable}");
      if (!ioManager.isDatabaseOpen()) return;

      var ecgCount = await ioManager.readECG();
      var accCount = await ioManager.readACC();
      debugPrint("Found $ecgCount entries in ECG table");
      debugPrint("Found $accCount entries in ACC table");

      ioManager.close();
      if (mounted) {
        setState(() {
          connectingState = ConnectingState.recordingStopped;
        });
      }
    }, cancelOnError: true);
    connectedStreamSubscription =
        polar.deviceConnectedStream.listen((event) async {
      ioManager.logToFile(
          "Polar ConnectedStream fired, with isConnectable = ${event.isConnectable}");

      //Case1: User started new session and wants to connect.
      if (connectingState == ConnectingState.connecting) {
        await ioManager.init();
        setState(() {
          print(
              "Setting state from within connected stream after new connect!");
          if (event.isConnectable) {
            connectingState = ConnectingState.connected;
          } else {
            connectingState = ConnectingState.error;
          }
        });
      }
      //Case2: User went out of range/ turned off sensor and reconnected.
      //In this case, don't redirect the screen
      if (connectingState == ConnectingState.recordingStopped) {}
    }, cancelOnError: true);
    await polar.connectToDevice(ioManager.deviceId);
  }

  Future<void> initRecording() async {
    //Set the sensor time and save time setting to DB
    final now = DateTime.now();
    final polarTimestamp = convertDateTimeToPolarNanos(now);
    final elapsedRealtime = SystemClock.elapsedRealtime().inMicroseconds;
    await polar.setLocalTime(ioManager.deviceId, now);

    ioManager.logToFile(
        "Setting the sensor time to: $polarTimestamp. ERT: $elapsedRealtime.");
    ioManager.saveTimeSettingEvent(polarTimestamp, elapsedRealtime);
  }

  void record() async {
    await initRecording();

    setState(() {
      connectingState = ConnectingState.initRecording;
    });
    hearRateStreamSubscription = polar.heartRateStream.listen((event) {
      if (mounted) {
        setState(() {
          heartRate = event.data.hr;
        });
      }
    });
    ecgStreamSubscription =
        polar.startEcgStreaming(ioManager.deviceId).listen((event) {
      if (connectingState != ConnectingState.recording) {
        setState(() {
          connectingState = ConnectingState.recording;
        });
      }
      ioManager.saveECGBlock(event.timeStamp, event.samples);
    });

    polar.startAccStreaming(ioManager.deviceId).listen((event) {
      ioManager.saveACCBlock(event.timeStamp, event.samples);
    });
    ioManager.logToFile("Started Polar SDK ECG, ACC and HR streams.");
  }

  void stopRecording() async {
    ioManager.logToFile("User has cancelled the recording.");
    polar.disconnectFromDevice(ioManager.deviceId);
  }

  void stopRecordingDialog() async {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              content: const Text(
                  "Die Aktuelle Messung wird gestoppt. Du kannst jederzeit eine neue starten."),
              title: const Text("Sicher?"),
              actions: [
                TextButton(
                    onPressed: () {
                      stopRecording();
                      Navigator.of(context).pop();
                    },
                    child: const Text("Stoppen")),
                TextButton(
                    onPressed: Navigator.of(context).pop,
                    child: const Text("Zurück"))
              ],
            ));
  }

  void cleanUp() async {
    //Clean up all existing streams
    ioManager.logToFile("Cleaning up all Stream Subscriptions.");
    polar.disconnectFromDevice(IOManager().deviceId);
    await connectedStreamSubscription?.cancel();
    await ecgStreamSubscription?.cancel();
    await hearRateStreamSubscription?.cancel();
    await disconnectedStreamSubscription?.cancel();

    setState(() {
      connectingState = ConnectingState.idle;
    });
  }

  int convertDateTimeToPolarNanos(DateTime dateTime) {
    const offset = 946684800000000; //microseconds since epoch on 01/01/2000 UTC
    final micros = dateTime.microsecondsSinceEpoch;
    return (micros - offset) * 1000;
  }

  void setMarker() async {
    //H10 Polar sensor measures timestamp in nanoseconds since 01/01 2000
    //The sensor ignores any timezones and always takes UTC
    final now = DateTime.now();
    final timestamp = convertDateTimeToPolarNanos(now);

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ein marker wurde erfolgreich gesetzt.")));
    ioManager.logToFile("Set a Marker at: $timestamp, with label: 'event'");
    ioManager.saveMarker(timestamp, "event");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Center(
              child: Text(ioManager.deviceId != "none"
                  ? ioManager.deviceId
                  : "No Device Id")),
          actions: [
            IconButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (BuildContext context) => const Settings()));
                },
                icon: const Icon(Icons.settings))
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                flex: 2,
                child: Container(
                  //color: Colors.green,
                  child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: howToText(context, connectingState, heartRate)),
                )),
            Expanded(
                flex: 1,
                child: Container(
                    //color: Colors.red,
                    child: Center(
                        child: bottomActions(context, connectingState, connect,
                            record, stopRecordingDialog, setMarker, cleanUp))))
            // const Flexible(
            //     flex: 1,
            //     child: Center(
            //       child: Text("No recording stream available"),
            //     )),
          ],
        ));
  }
}
