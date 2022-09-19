import 'package:ecgrec/io_manager.dart';
import 'package:ecgrec/settings.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/fontelico_icons.dart';
import 'package:polar/polar.dart';

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
  error
}

class _HomeState extends State<Home> {
  final polar = Polar();
  //final identifier = "94FF4C29";
  final IOManager ioManager = IOManager();
  //state variables:
  ConnectingState connectingState = ConnectingState.idle;
  int heartRate = 0;

  final TextStyle titleText = TextStyle(
    fontWeight: FontWeight.w500,
    color: Colors.grey[800],
    fontSize: 25,
  );

  final TextStyle bodyText = TextStyle(
    color: Colors.grey[800],
    fontSize: 16,
  );

  @override
  void initState() {
    super.initState();
  }

  void connect() async {
    if (ioManager.devideId == "none") {
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
    print("Connecting...");

    polar.disconnectFromDevice(ioManager.devideId);
    polar.deviceConnectedStream.listen((event) {
      setState(() {
        if (event.isConnectable) {
          connectingState = ConnectingState.connected;
        } else {
          connectingState = ConnectingState.error;
        }
      });
      //print('Heart rate: ${event.deviceId}');
    });
    await polar.connectToDevice(ioManager.devideId);

    ioManager.init();

    // polar.
  }

  void record() async {
    print("lets go");
    await polar.setLocalTime(ioManager.devideId, DateTime.now());
    //polar.di
    setState(() {
      connectingState = ConnectingState.initRecording;
    });
    polar.heartRateStream.listen((event) {
      setState(() {
        heartRate = event.data.hr;
      });
    });
    polar.startEcgStreaming(ioManager.devideId).listen((event) {
      if (connectingState != ConnectingState.recording) {
        setState(() {
          connectingState = ConnectingState.recording;
        });
      }
      ioManager.saveECGBlock(event.timeStamp, event.samples);
    });

    polar.startAccStreaming(ioManager.devideId).listen((event) {
      ioManager.saveACCBlock(event.timeStamp, event.samples);
    });
  }

  void stopRecording() async {
    polar.disconnectFromDevice(ioManager.devideId);

    setState(() {
      connectingState = ConnectingState.idle;
    });
    //This is here because there is a bug, where sometimes if "stop recording"
    //is clicked, the connection closes, recording stops, but the screen doesn't update
    //It happens rarely enough that I don't want to spend the time chasing it right now,
    //So this should fix the app crashing. The user will just assume he hasn't clicked it
    //properly, and click it again.
    //I suspect this is because of some async shennanigangs
    if (!ioManager.isDatabaseOpen()) return;

    //print some debug info
    var ecgCount = await ioManager.readECG();
    var accCount = await ioManager.readACC();
    debugPrint("Found $ecgCount entries in ECG table");
    debugPrint("Found $accCount entries in ACC table");

    ioManager.close();
  }

  void setMarker() async {
    //H10 Polar sensor measures timestamp in nanoseconds since 01/01 2000
    //The sensor ignores any timezones and always takes UTC
    final date = DateTime.now().microsecondsSinceEpoch;
    final date2000 = DateTime(2000)
        .toUtc()
        .add(const Duration(hours: 1))
        .microsecondsSinceEpoch; //toUtc subtracted an hour.

    final timestamp = (date - date2000) * 1000;
    print("Set Marker at: $timestamp");
    ioManager.saveMarker(timestamp, "event");
  }

  Widget howToText(BuildContext context) {
    if (connectingState == ConnectingState.idle ||
        connectingState == ConnectingState.connecting) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Fontelico.emo_happy,
            size: 100,
            color: Theme.of(context).primaryColorDark,
          ),
          const SizedBox(height: 20),
          SizedBox(
              height: 70,
              child: Center(child: Text("Hallo!", style: titleText))),
          const SizedBox(height: 10),
          Text(
            "Um eine Messung zu starten, lege bitte als erstes den H10 Polar Gurt um.",
            textAlign: TextAlign.center,
            style: bodyText,
          ),
          const SizedBox(height: 10),
          Text(
            'Nach ca. 30 sekunden, klick auf "Verbinden"',
            textAlign: TextAlign.center,
            style: bodyText,
          ),
          const SizedBox(height: 50),
          Center(
              child: Text(
            "Verbinde . . . ",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: connectingState == ConnectingState.connecting
                    ? Colors.black
                    : Colors.white),
          )),
        ],
      );
    }
    if (connectingState == ConnectingState.connected ||
        connectingState == ConnectingState.initRecording) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Fontelico.emo_wink,
            size: 100,
            color: Theme.of(context).primaryColorDark,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 70,
            child: Center(
              child: Text(
                "Ich habe deinen Gurt gefunden!",
                style: titleText,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Bitte lass den Gurt für die nächsten 48h um.",
            textAlign: TextAlign.center,
            style: bodyText,
          ),
          const SizedBox(height: 10),
          Text(
            'Um eine Messung zu starten, klicke auf "Messung starten"',
            textAlign: TextAlign.center,
            style: bodyText,
          ),
          const SizedBox(height: 50),
          Center(
              child: Text(
            "Starte Messung . . . ",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: connectingState == ConnectingState.initRecording
                    ? Colors.black
                    : Colors.white),
          )),
        ],
      );
    }
    if (connectingState == ConnectingState.recording) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Fontelico.emo_squint,
            size: 100,
            color: Theme.of(context).primaryColorDark,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 70,
            child: Center(
              child: Text(
                "Messung ist im Gange.",
                style: titleText,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Bitte nimm den Gurt nicht ab während die Messung läuft.",
            textAlign: TextAlign.center,
            style: bodyText,
          ),
          const SizedBox(height: 10),
          Text(
            'Wenn du einen Zeitpunkt merken möchtest, klicke auf "Marker setzen"',
            textAlign: TextAlign.center,
            style: bodyText,
          ),
          const SizedBox(height: 50),
          Center(
              child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monitor_heart_outlined),
              Text("Herzrate: ${heartRate.toString()}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ))
        ],
      );
    }
    if (connectingState == ConnectingState.error) {
      return const Text("error");
    }
    return const Text("error");
  }

  Widget bottomActions(BuildContext context) {
    if (connectingState == ConnectingState.idle ||
        connectingState == ConnectingState.connecting) {
      return ElevatedButton(
          onPressed: connectingState == ConnectingState.idle ? connect : null,
          child: const Text("Verbinden"));
    }
    if (connectingState == ConnectingState.connected ||
        connectingState == ConnectingState.initRecording) {
      return ElevatedButton(
          onPressed:
              connectingState == ConnectingState.connected ? record : null,
          child: const Text("Messung starten"));
    }
    if (connectingState == ConnectingState.recording) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
              style: ElevatedButton.styleFrom(fixedSize: const Size(150, 20)),
              onPressed: stopRecording,
              child: const Text("Messung stoppen")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(fixedSize: const Size(150, 20)),
              onPressed: setMarker,
              child: const Text("Marker setzen")),
        ],
      );
      // return Column(
      //   children: [
      //     ElevatedButton(
      //         onPressed: stopRecording, child: const Text("Messung stoppen")),
      //     const SizedBox(height: 10),
      //     ElevatedButton(onPressed: () {}, child: const Text("Marker setzen")),
      //   ],
      // );
    }
    return const Text("Error");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Center(child: Text("ECG")),
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
                      child: howToText(context)),
                )),
            Expanded(
                flex: 1,
                child: Container(
                    //color: Colors.red,
                    child: Center(child: bottomActions(context))))
            // const Flexible(
            //     flex: 1,
            //     child: Center(
            //       child: Text("No recording stream available"),
            //     )),
          ],
        ));
  }
}
