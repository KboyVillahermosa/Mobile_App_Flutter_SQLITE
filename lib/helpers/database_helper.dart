import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../models/user.dart';
import '../models/job.dart';
import '../models/job_application.dart'; // Add this import

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
    
    // Force delete existing database to create fresh one
    try {
      File dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
        print('Deleted existing database to force recreation');
      }
    } catch (e) {
      print('Error deleting database: $e');
    }
    
    return await openDatabase(
      path,
      version: 4,
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
        profileImage TEXT,
        userRole TEXT,
        ageGroup TEXT,
        experienceLevel TEXT,
        services TEXT,
        interests TEXT,
        hasCompletedAssessment INTEGER
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

    // Create applications table
    await db.execute('''
      CREATE TABLE applications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jobId INTEGER NOT NULL,
        applicantId INTEGER NOT NULL,
        applicantName TEXT NOT NULL,
        applicantPhone TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        appliedAt TEXT NOT NULL,
        FOREIGN KEY (jobId) REFERENCES jobs (id),
        FOREIGN KEY (applicantId) REFERENCES users (id)
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');
    
    if (oldVersion == 1 && newVersion >= 2) {
      print('Adding profileImage column');
      // Add the missing profileImage column
      await db.execute('ALTER TABLE users ADD COLUMN profileImage TEXT');
    }
    
    if (oldVersion <= 2 && newVersion >= 3) {
      print('Creating jobs table');
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
    
    if (oldVersion <= 3 && newVersion >= 4) {
      print('Adding new user columns for version 4');
      // Add the new user columns
      await db.execute('ALTER TABLE users ADD COLUMN userRole TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN ageGroup TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN experienceLevel TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN services TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN interests TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN hasCompletedAssessment INTEGER');
      print('Database upgrade to version 4 completed');
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

  Future<List<Map<String, dynamic>>> getJobsWithUserInfo() async {
    Database db = await database;
    
    // Join users and jobs tables to get user name with each job
    final List<Map<String, dynamic>> jobsWithUserInfo = await db.rawQuery('''
      SELECT jobs.*, users.fullName 
      FROM jobs 
      INNER JOIN users ON jobs.userId = users.id 
      ORDER BY jobs.dateTime DESC
    ''');
    
    return jobsWithUserInfo;
  }

  // New methods for job application functionality

  Future<int> insertJobApplication(JobApplication application) async {
    Database db = await database;
    return await db.insert('applications', application.toMap());
  }

  Future<List<Map<String, dynamic>>> getJobApplications(int jobId) async {
    Database db = await database;
    return await db.query(
      'applications',
      where: 'jobId = ?',
      whereArgs: [jobId],
      orderBy: 'appliedAt DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getUserNotifications(int userId) async {
    Database db = await database;
    
    // Get jobs posted by this user
    final userJobs = await db.query(
      'jobs',
      columns: ['id'],
      where: 'userId = ?',
      whereArgs: [userId],
    );
    
    if (userJobs.isEmpty) {
      return [];
    }
    
    // Extract job IDs
    final jobIds = userJobs.map((job) => job['id'] as int).toList();
    
    // Get applications for those jobs
    return await db.rawQuery('''
      SELECT applications.*, jobs.title as jobTitle 
      FROM applications 
      JOIN jobs ON applications.jobId = jobs.id 
      WHERE applications.jobId IN (${jobIds.map((_) => '?').join(',')})
      ORDER BY applications.appliedAt DESC
    ''', [...jobIds]);
  }

  Future<int> getUnreadNotificationsCount(int userId) async {
    final notifications = await getUserNotifications(userId);
    return notifications.where((n) => n['status'] == 'pending').length;
  }

  Future<int> updateApplicationStatus(int id, String status) async {
    Database db = await database;
    return await db.update(
      'applications',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}