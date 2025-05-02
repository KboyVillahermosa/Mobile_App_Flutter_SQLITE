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
    
    bool exists = await File(path).exists();
    print('Database exists before opening: $exists');
    
    return await openDatabase(
      path,
      version: 2, // Increment this version number
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Make sure this is added
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
        additionalDetails TEXT,
        FOREIGN KEY (jobId) REFERENCES jobs (id),
        FOREIGN KEY (applicantId) REFERENCES users (id)
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        // Add additionalDetails column if it doesn't exist
        await db.execute('ALTER TABLE applications ADD COLUMN additionalDetails TEXT');
        print('Added additionalDetails column to applications table');
      } catch (e) {
        print('Error adding column (may already exist): $e');
      }
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

  Future<User?> getUserById(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
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

  Future<List<Map<String, dynamic>>> getAllJobsWithUserInfo() async {
    Database db = await database;
    
    // Join jobs with users to get uploader name
    final List<Map<String, dynamic>> jobsWithUserInfo = await db.rawQuery('''
      SELECT jobs.*, users.fullName as uploaderName, users.profileImage as uploaderImage
      FROM jobs 
      INNER JOIN users ON jobs.userId = users.id 
      ORDER BY jobs.dateTime DESC
    ''');
    
    return jobsWithUserInfo;
  }

  // New methods for job application functionality

  Future<int> insertJobApplication(JobApplication application) async {
    final db = await database;
    try {
      print("Inserting into applications table: ${application.toMap()}");
      return await db.insert(
        'applications',  // Make sure this is the correct table name
        application.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print("Database insertion error: $e");
      throw e;  // Re-throw to show in UI
    }
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
    
    // Get applications for those jobs with complete details
    return await db.rawQuery('''
      SELECT 
        applications.*, 
        jobs.title as jobTitle,
        jobs.budget as jobBudget,
        users.profileImage as applicantImage,
        users.userRole as applicantRole,
        users.experienceLevel as applicantExperience
      FROM applications 
      JOIN jobs ON applications.jobId = jobs.id 
      JOIN users ON applications.applicantId = users.id
      WHERE applications.jobId IN (${jobIds.map((_) => '?').join(',')})
      ORDER BY applications.appliedAt DESC
    ''', [...jobIds]);
  }

  Future<int> getUnreadNotificationsCount(int userId) async {
    final db = await database;
    
    // Get jobs posted by this user
    final userJobs = await db.query(
      'jobs',
      columns: ['id'],
      where: 'userId = ?',
      whereArgs: [userId],
    );
    
    if (userJobs.isEmpty) {
      return 0;
    }
    
    // Extract job IDs
    final jobIds = userJobs.map((job) => job['id'] as int).toList();
    
    // Count unread notifications (pending applications)
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM applications 
      WHERE jobId IN (${jobIds.map((_) => '?').join(',')})
      AND status = 'pending'
    ''', [...jobIds]);
    
    return result.first['count'] as int;
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

  // Add this diagnostic method to your DatabaseHelper class

  Future<void> checkAndFixApplicationsTable() async {
    final db = await database;
    try {
      // Check if the additionalDetails column exists
      var columns = await db.rawQuery('PRAGMA table_info(applications)');
      bool hasAdditionalDetails = columns.any((column) => column['name'] == 'additionalDetails');
      
      if (!hasAdditionalDetails) {
        print("Adding missing additionalDetails column to applications table");
        await db.execute('ALTER TABLE applications ADD COLUMN additionalDetails TEXT');
      }
    } catch (e) {
      print("Error checking/fixing database schema: $e");
    }
  }
}