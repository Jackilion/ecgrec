//Helper file, because the homescreen has quite a few different states
//That should be displayed while on the same screen (to handle the polar
// stream subscriptions. So I outsourced the UI to this file to make it more
// readable)

import 'package:ecgrec/home.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/fontelico_icons.dart';

final TextStyle titleText = TextStyle(
  fontWeight: FontWeight.w500,
  color: Colors.grey[800],
  fontSize: 25,
);

final TextStyle bodyText = TextStyle(
  color: Colors.grey[800],
  fontSize: 16,
);

Widget howToText(
    BuildContext context, ConnectingState connectingState, int? heartrate) {
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
            height: 70, child: Center(child: Text("Hallo!", style: titleText))),
        const SizedBox(height: 10),
        Text(
          "Um eine Messung zu starten, lege bitte als erstes den H10 Polar Gurt um.",
          textAlign: TextAlign.center,
          style: bodyText,
        ),
        const SizedBox(height: 10),
        Text(
          'Nach ca. 30 sekunden, klick auf "Verbinden". Bitte stelle sicher das Bluetooth aktiviert ist.',
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
            Text("Herzrate: ${heartrate.toString()}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                )),
          ],
        ))
      ],
    );
  }
  if (connectingState == ConnectingState.recordingStopped) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Fontelico.emo_surprised,
          size: 100,
          color: Theme.of(context).primaryColorDark,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 70,
          child: Center(
            child: Text(
              "Messung beendet!",
              style: titleText,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Deine Messung wurde beendet.",
          textAlign: TextAlign.center,
          style: bodyText,
        ),
        const SizedBox(height: 10),
        Text(
          'Wenn du eine neue Messung starten möchtest, klicke hier"',
          textAlign: TextAlign.center,
          style: bodyText,
        ),
        const SizedBox(height: 50),
        // Center(
        //     child: Row(
        //   mainAxisAlignment: MainAxisAlignment.center,
        //   children: [
        //     const Icon(Icons.monitor_heart_outlined),
        //     Text("Herzrate: ${heartrate.toString()}",
        //         style: const TextStyle(
        //           fontWeight: FontWeight.bold,
        //         )),
        //   ],
        // ))
      ],
    );
  }

  if (connectingState == ConnectingState.error) {
    return const Text("error");
  }
  return const Text("error");
}

Widget bottomActions(
  BuildContext context,
  ConnectingState connectingState,
  void Function() onConnect,
  void Function() onRecord,
  void Function() onCancel,
  void Function() onMarker,
  void Function() onReconnect,
) {
  if (connectingState == ConnectingState.idle ||
      connectingState == ConnectingState.connecting) {
    return ElevatedButton(
        onPressed: connectingState == ConnectingState.idle ? onConnect : null,
        child: const Text("Verbinden"));
  }
  if (connectingState == ConnectingState.connected ||
      connectingState == ConnectingState.initRecording) {
    return ElevatedButton(
        onPressed:
            connectingState == ConnectingState.connected ? onRecord : null,
        child: const Text("Messung starten"));
  }
  if (connectingState == ConnectingState.recording) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
            style: ElevatedButton.styleFrom(fixedSize: const Size(150, 20)),
            onPressed: onCancel,
            child: const Text("Messung stoppen")),
        ElevatedButton(
            style: ElevatedButton.styleFrom(fixedSize: const Size(150, 20)),
            onPressed: onMarker,
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
  if (connectingState == ConnectingState.recordingStopped) {
    return ElevatedButton(
        onPressed: connectingState == ConnectingState.recordingStopped
            ? onReconnect
            : null,
        child: const Text("Erneut Starten"));
  }

  return const Text("Error");
}
