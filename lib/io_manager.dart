import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:polar/polar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:system_clock/system_clock.dart';

class IOManager {
  String deviceId = "none";
  Database? database;
  //final String path = "/data/media/0/ECG/";
  Directory? path;
  bool get isRecordingRunning {
    return database != null && database!.isOpen;
  }

  Future<bool> get doesDatabaseExist async {
    if (path == null) return false;
    return await File("${path!.path}/ecg.db").exists();
  }

  String get savePath {
    if (path != null) return path!.path;
    return "";
  }

  IOManager._internal();
  static final IOManager _ioManager = IOManager._internal();

  factory IOManager() {
    return _ioManager;
  }

  File? _logFile;
  void logToFile(String message) async {
    path ??= await getExternalStorageDirectory();
    _logFile ??= File("${path!.path}/log.txt");
    var formatted = "${DateTime.now().toIso8601String()}:\t$message\n";
    _logFile!.writeAsStringSync(formatted, mode: FileMode.append);
  }

  Future<void> exportData() async {
    File db = File("${path!.path}/ecg.db");
    final startTime =
        (await SharedPreferences.getInstance()).getString("startTime");
    db.rename("${path!.path}/${deviceId}_$startTime.db");
    logToFile(
        "DB file has been renamed to ${path!.path}/${deviceId}_$startTime.db");
  }

  //Must be called before anything else in this singleton
  Future<void> init() async {
    path = await getExternalStorageDirectory();
    //path = await getApplicationDocumentsDirectory();

    _logFile ??= File("${path!.path}/log.txt");

    var status = await Permission.storage.status;
    if (status.isDenied) await Permission.storage.request();
    database = await openDatabase('${path!.path}/ecg.db', version: 1,
        onCreate: (Database db, int version) async {
      await db.execute(
          'CREATE TABLE ECG (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp INTEGER, samples TEXT, sample_count INTEGER, sample_sum INTEGER, elapsed_realtime INTEGER);');
      await db.execute(
          'CREATE TABLE ACC (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp INTEGER, samples TEXT, sample_count INTEGER, sample_sum INTEGER, elapsed_realtime INTEGER);');
      await db.execute(
          'CREATE TABLE MRK (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp INTEGER, description TEXT, elapsed_realtime INTEGER);');
      await db.execute('CREATE TABLE CONFIG (key TEXT,  value TEXT);');
      await db.execute(
          'CREATE TABLE TIME_SETS (elapsed_realtime INTEGER, new_time INTEGER);');
      await writeConfigTable(db);
    });
    final prefs = await SharedPreferences.getInstance();
    final iso = DateTime.now().toIso8601String();
    var startTimePref = prefs.getString("startTime");
    if (startTimePref == null) prefs.setString("startTime", iso);
    queryStreamController = StreamController<String>();
    queryStream = queryStreamController!.stream;
    queryStream!.listen(_handleQueries);
    logToFile("Opened a DB connection to ${path!.path}/ecg.db");
    if (startTimePref == null) {
      logToFile(
          "It was the first time a DB connection has been established on this device, so I saved the startTime as $iso");
    }
  }

  Future<void> writeConfigTable(Database db) async {
    var batch = db.batch();
    batch.insert("CONFIG", {"key": "DB_VERSION", "value": "1"});
    batch.insert("CONFIG", {"key": "POLAR_H10_DEVICE_ID", "value": deviceId});
    batch.insert("CONFIG", {
      "key": "TIMESTAMP_UNIT",
      "value": "elapsed nanoseconds since 01/01/2000"
    });
    batch.insert("CONFIG", {
      "key": "ELAPSED_REALTIME_UNIT",
      "value": "elapsed microseconds since device boot"
    });

    batch.insert("CONFIG", {"key": "ECG_SAMPLE_RATE", "value": "130Hz +- 2%"});
    batch.insert("CONFIG", {"key": "ECG_SAMPLE_UNITS", "value": "µV"});
    batch.insert("CONFIG",
        {"key": "ECG_SAMPLE_FORMAT", "value": "[s1, s2, s3, ... , s73]"});

    batch.insert("CONFIG", {"key": "ACC_SAMPLE_RATE", "value": "52Hz"});
    batch.insert("CONFIG", {"key": "ACC_SAMPLE_UNITS", "value": "mG"});
    batch.insert("CONFIG", {"key": "ACC_SAMPLE_FORMAT", "value": "(x, y, z)"});

    await batch.commit();
    //var query = 'INSERT INTO Config (key, value) VALUES ()'
  }

  Stream<String>? queryStream;
  StreamController<String>? queryStreamController;
  Batch? queryBuffer;
  int queryCounter = 0;
  int queryCounterLimit = 100;

  void _handleQueries(String query) {
    if (queryCounter == 0 || queryBuffer == null) {
      queryBuffer = database!.batch();
    }
    queryBuffer!.rawInsert(query);
    queryCounter++;
    if (queryCounter == queryCounterLimit) {
      queryBuffer!.commit();
      debugPrint("Wrote to database");
      queryCounter = 0;
    }
  }

  bool isDatabaseOpen() {
    return database != null && database!.isOpen;
  }

  void saveTimeSettingEvent(int timestamp, int elapsedRealtime) async {
    database!.insert("TIME_SETS",
        {"elapsed_realtime": elapsedRealtime, "new_time": timestamp});
  }

  int oldTimestamp = 0;

  void saveECGBlock(int timestamp, List<int> samples) async {
    if (oldTimestamp == timestamp) {
      debugPrint("FOUND THE SAME TIMESTAMP IN 2 PACKAGES!!!");
      logToFile(
          "[ALERT!] Found the same timestamp in 2 packages! Timestamp was: $timestamp");
    }
    oldTimestamp = timestamp;
    final elapsedRealtime = SystemClock.elapsedRealtime().inMicroseconds;
    final sampleCount = samples.length;
    final sampleSum = samples.reduce((value, element) => value + element);
    final query =
        "INSERT INTO ECG (timestamp, samples, sample_count, sample_sum, elapsed_realtime) VALUES ($timestamp, '${samples.toString()}', $sampleCount, $sampleSum, $elapsedRealtime)";
    queryStreamController!.add(query);
  }

  void saveACCBlock(int timestamp, List<Xyz> samples) async {
    final elapsedRealtime = SystemClock.elapsedRealtime().inMicroseconds;
    final sampleCount = samples.length;
    var sum = 0.0;
    for (var element in samples) {
      sum += element.x;
      sum += element.y;
      sum += element.z;
    }
    String xyzText = "";
    for (var element in samples) {
      xyzText += "(${element.x}, ${element.y}, ${element.z}); ";
    }
    final query =
        "INSERT INTO ACC (timestamp, samples, sample_count, sample_sum, elapsed_realtime) VALUES ($timestamp, '$xyzText', $sampleCount, $sum, $elapsedRealtime)";
    queryStreamController!.add(query);
  }

  void saveMarker(int timestamp, String description) {
    //Description comes from a UI input, so sanitize it
    final elapsedRealtime = SystemClock.elapsedRealtime().inMicroseconds;
    final safeDescription = description.replaceAll("'", "''");
    queryStreamController!.add(
        "INSERT INTO MRK (timestamp, description, elapsed_realtime) VALUES ($timestamp, '$safeDescription', '$elapsedRealtime')");
  }

  Future<int> readECG() async {
    final ecgData = await database!.rawQuery("SELECT * FROM ECG");
    return ecgData.length;
  }

  Future<int> readACC() async {
    final accData = await database!.rawQuery("SELECT * FROM ACC");
    return accData.length;
  }

  Future<int> readMarkers() async {
    final mrkData = await database!.rawQuery("SELECT * FROM MRK");
    return mrkData.length;
  }

  void resetDB() async {
    deleteDatabase('${path!.path}/ecg.db');
    logToFile(
        "Device has been reset. ECG Database deleted and polar ID reset.");
    //await init();
  }

  void close() async {
    //commit all remaining queries:
    logToFile("Closing the DB connection.");
    if (database == null || !database!.isOpen) return;
    await queryBuffer!.commit();
    queryCounter = 0;
    var map =
        await database!.rawQuery("SELECT * FROM ECG ORDER BY id DESC LIMIT 1");
    print(map);
    await database!.close();
    //Clean up streams:
    queryStreamController!.close();
    //queryStream!.
  }
}
