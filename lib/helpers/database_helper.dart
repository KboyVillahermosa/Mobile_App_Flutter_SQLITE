import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../models/user.dart';
import '../models/job.dart'; // You'll need to create this model

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'auth.db');
    return await openDatabase(
      path,
      version: 3, // Increase version from 2 to 3
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT NOT NULL,
        phoneNumber TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        profileImage TEXT
      )
    ''');
    
    // Create jobs table
    await db.execute('''
      CREATE TABLE jobs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        budget REAL NOT NULL,
        location TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        imagePaths TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        createdAt TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');
  }

  // Update the onUpgrade method to handle version 3
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion == 1 && newVersion >= 2) {
      // Add the missing profileImage column
      await db.execute('ALTER TABLE users ADD COLUMN profileImage TEXT');
    }
    
    if (oldVersion <= 2 && newVersion >= 3) {
      // Create jobs table
      await db.execute('''
        CREATE TABLE jobs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER NOT NULL,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          budget REAL NOT NULL,
          location TEXT NOT NULL,
          dateTime TEXT NOT NULL,
          imagePaths TEXT,
          status TEXT NOT NULL DEFAULT 'open',
          createdAt TEXT NOT NULL,
          FOREIGN KEY (userId) REFERENCES users (id)
        )
      ''');
    }
  }

  Future<int> insertUser(User user) async {
    Database db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUserByPhone(String phoneNumber) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'phoneNumber = ?',
      whereArgs: [phoneNumber],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<bool> checkLogin(String phoneNumber, String password) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'phoneNumber = ? AND password = ?',
      whereArgs: [phoneNumber, password],
    );
    return maps.isNotEmpty;
  }

  Future<int> updateUserProfile(int id, String fullName) async {
    Database db = await database;
    return await db.update(
      'users',
      {'fullName': fullName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateUserPassword(int id, String newPassword) async {
    Database db = await database;
    return await db.update(
      'users',
      {'password': newPassword},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateProfileImage(int id, String imagePath) async {
    Database db = await database;
    return await db.update(
      'users',
      {'profileImage': imagePath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> getDatabasePath() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'auth.db');
    print('Database location: $path');
    return path;
  }

  // New methods for job posting functionality

  Future<int> insertJob(Job job) async {
    Database db = await database;
    final id = await db.insert('jobs', job.toMap());
    print('Inserted job with ID: $id into database'); // Add logging
    return id;
  }

  Future<Job?> getJobById(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'jobs',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Job.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Job>> getJobsByUserId(int userId) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'jobs',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'dateTime DESC',
    );

    return maps.map((map) => Job.fromMap(map)).toList();
  }

  Future<List<Job>> getAllJobs() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'jobs',
      orderBy: 'dateTime DESC',
    );
    
    print('Retrieved ${maps.length} jobs from database'); // Add logging
    
    return maps.map((map) => Job.fromMap(map)).toList();
  }

  Future<int> updateJobStatus(int id, String status) async {
    Database db = await database;
    return await db.update(
      'jobs',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteJob(int id) async {
    Database db = await database;
    return await db.delete(
      'jobs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}