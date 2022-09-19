import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:polar/polar.dart';
import 'package:sqflite/sqflite.dart';

class IOManager {
  String devideId = "none";
  Database? database;
  final String path = "/storage/emulated/0/ECG/";

  IOManager._internal();
  static final IOManager _ioManager = IOManager._internal();

  factory IOManager() {
    return _ioManager;
  }

  //Must be called before anything else in this singleton
  Future<void> init() async {
    var status = await Permission.storage.status;
    if (status.isDenied) await Permission.storage.request();
    database = await openDatabase('${path}ecg.db', version: 1,
        onCreate: (Database db, int version) async {
      await db.execute(
          'CREATE TABLE ECG (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp INTEGER, samples TEXT);');
      await db.execute(
          'CREATE TABLE ACC (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp INTEGER, samples TEXT);');
      await db.execute(
          'CREATE TABLE MRK (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp INTEGER, description TEXT);');
    });
    queryStreamController = StreamController<String>();
    queryStream = queryStreamController!.stream;
    queryStream!.listen(_handleQueries);
  }

  Stream<String>? queryStream;
  StreamController<String>? queryStreamController;
  Batch? queryBuffer;
  int queryCounter = 0;
  int queryCounterLimit = 100;

  void _handleQueries(String query) {
    if (queryCounter == 0) queryBuffer = database!.batch();
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

  void saveECGBlock(int timestamp, List<int> samples) async {
    final query =
        "INSERT INTO ECG (timestamp, samples) VALUES ($timestamp, '${samples.toString()}')";
    queryStreamController!.add(query);
  }

  void saveACCBlock(int timestamp, List<Xyz> samples) async {
    String xyzText = "";
    for (var element in samples) {
      xyzText += "(${element.x}, ${element.y}, ${element.z}); ";
    }
    final query =
        "INSERT INTO ACC (timestamp, samples) VALUES ($timestamp, '$xyzText')";
    queryStreamController!.add(query);
  }

  void saveMarker(int timestamp, String description) {
    //Description comes from a UI input, so sanitize it
    final safeDescription = description.replaceAll("'", "''");
    queryStreamController!.add(
        "INSERT INTO MRK (timestamp, description) VALUES ($timestamp, '$safeDescription')");
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
    deleteDatabase('${path}ecg.db');
    //await init();
  }

  void close() async {
    //commit all remaining queries:
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
