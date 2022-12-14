import 'package:ecgrec/io_manager.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final textFieldController = TextEditingController();

  @override
  void initState() {
    if (IOManager().devideId != "none") {
      textFieldController.text = IOManager().devideId;
    }
    super.initState();
  }

  @override
  void dispose() {
    textFieldController.dispose();
    super.dispose();
  }

  void setDeviceId() async {
    var text = textFieldController.text;
    if (text.isNotEmpty) {
      IOManager().devideId = text;
      (await SharedPreferences.getInstance()).setString("deviceId", text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Die Device Id wurde erfolgreich gesetzt")));
      }
    }
  }

  void resetData() async {
    if (IOManager().isDatabaseOpen()) {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                content: const Text(
                    "Die Datenbank ist geöffnet, es kann deshalb aus sicherheitsgründen kein reset durchgeführt werden."),
                title: const Text("Fehler"),
                actions: [
                  TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text("Okay"))
                ],
              ));
      return;
    }
    IOManager().devideId = "none";
    IOManager().resetDB();
    await (await SharedPreferences.getInstance()).clear();
    textFieldController.text = "";
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Das Gerät wurde erfolgreich resetted.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Einstellungen")),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                    "Achtung! Diese Einstellungen sind für Mitarbeiter der HU gedacht.",
                    style: TextStyle(fontSize: 20, color: Colors.grey[600])),
                const SizedBox(height: 20),
                Text("Bitte nimm keine Einstellungen vor.",
                    style: TextStyle(fontSize: 20, color: Colors.grey[600])),
                const SizedBox(height: 50),
                const FractionallySizedBox(
                  widthFactor: 1,
                  child: Text("Device Identifier:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Flexible(
                      flex: 4,
                      child: TextField(
                        controller: textFieldController,
                        decoration:
                            const InputDecoration(border: OutlineInputBorder()),
                      ),
                    ),
                    Flexible(
                        flex: 1,
                        child: Center(
                            child: IconButton(
                                onPressed: setDeviceId,
                                icon: Icon(
                                  Icons.check,
                                  color: Theme.of(context).primaryColorDark,
                                ))))
                  ],
                ),
                const SizedBox(height: 50),
                SizedBox(
                  width: 150,
                  child: ElevatedButton(
                      onPressed: resetData, child: const Text("Reset Data")),
                ),
                SizedBox(
                  width: 150,
                  child: ElevatedButton(
                      onPressed: () {}, child: const Text("Export Data")),
                )
              ],
            ),
          ),
        ));
  }
}
