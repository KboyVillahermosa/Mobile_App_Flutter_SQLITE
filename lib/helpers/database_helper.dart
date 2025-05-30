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
    
    return await openDatabase(
      path,
      version: 9, // Increment version from 8 to 9
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await _createTables(db);
    
    // Create jobs table
    await db.execute('''
      CREATE TABLE jobs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        title TEXT,
        description TEXT,
        budget REAL,
        location TEXT,
        dateTime TEXT,
        imagePaths TEXT,
        status TEXT,
        createdAt TEXT,
        uploaderName TEXT,
        uploaderImage TEXT,
        currentImageIndex INTEGER,
        category TEXT
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

    // Create messages table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        senderId INTEGER NOT NULL,
        receiverId INTEGER NOT NULL,
        jobId INTEGER NOT NULL,
        message TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        isRead INTEGER DEFAULT 0
      )
    ''');

    // Create notifications table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        senderId INTEGER NOT NULL,
        type TEXT NOT NULL,
        message TEXT NOT NULL,
        details TEXT,
        createdAt TEXT NOT NULL,
        isRead INTEGER DEFAULT 0
      )
    ''');

    // Create ratings table
    await db.execute('''
      CREATE TABLE ratings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jobId INTEGER NOT NULL,
        raterId INTEGER NOT NULL,
        ratedId INTEGER NOT NULL,
        rating INTEGER NOT NULL,
        comment TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (jobId) REFERENCES jobs (id),
        FOREIGN KEY (raterId) REFERENCES users (id),
        FOREIGN KEY (ratedId) REFERENCES users (id)
      )
    ''');
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT,
        phoneNumber TEXT,
        password TEXT,
        profileImage TEXT,
        userRole TEXT,
        ageGroup TEXT,
        experienceLevel TEXT,
        services TEXT,
        interests TEXT,
        hasCompletedAssessment INTEGER,
        bio TEXT,
        achievements TEXT
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
    
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE jobs ADD COLUMN uploaderName TEXT');
        await db.execute('ALTER TABLE jobs ADD COLUMN uploaderImage TEXT');
        print('Added uploaderName and uploaderImage columns to jobs table');
      } catch (e) {
        print('Error adding columns to jobs table: $e');
      }
    }

    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE jobs ADD COLUMN currentImageIndex INTEGER');
        print('Added currentImageIndex column to jobs table');
      } catch (e) {
        print('Error adding currentImageIndex column to jobs table');
      }
    }

    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN bio TEXT');
        await db.execute('ALTER TABLE users ADD COLUMN achievements TEXT');
        print('Added bio and achievements columns to users table');
      } catch (e) {
        print('Error adding bio and achievements columns: $e');
      }
    }

    if (oldVersion < 6) {
      try {
        // Add bio and achievements columns to users table
        await db.execute('ALTER TABLE users ADD COLUMN bio TEXT');
        print('Added bio column to users table');
      } catch (e) {
        print('Error adding bio column (may already exist): $e');
      }
      
      try {
        await db.execute('ALTER TABLE users ADD COLUMN achievements TEXT');
        print('Added achievements column to users table');
      } catch (e) {
        print('Error adding achievements column (may already exist): $e');
      }
    }

    if (oldVersion < 7) { // Use appropriate version number
      try {
        // Check if additionalDetails column exists
        var columns = await db.rawQuery('PRAGMA table_info(applications)');
        bool hasAdditionalDetails = columns.any((column) => column['name'] == 'additionalDetails');
        
        if (!hasAdditionalDetails) {
          await db.execute('ALTER TABLE applications ADD COLUMN additionalDetails TEXT');
          print('Added additionalDetails column to applications table');
        }
      } catch (e) {
        print('Error updating applications schema: $e');
      }
    }

    if (oldVersion < 8) { // Use the next version number
      try {
        await db.execute('ALTER TABLE jobs ADD COLUMN category TEXT');
        print('Added category column to jobs table');
      } catch (e) {
        print('Error adding category column (may already exist): $e');
      }
    }

    if (oldVersion < 9) {
      try {
        await db.execute('''
          CREATE TABLE ratings(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            jobId INTEGER NOT NULL,
            raterId INTEGER NOT NULL,
            ratedId INTEGER NOT NULL,
            rating INTEGER NOT NULL,
            comment TEXT,
            createdAt TEXT NOT NULL,
            FOREIGN KEY (jobId) REFERENCES jobs (id),
            FOREIGN KEY (raterId) REFERENCES users (id),
            FOREIGN KEY (ratedId) REFERENCES users (id)
          )
        ''');
        print('Created ratings table');
      } catch (e) {
        print('Error creating ratings table: $e');
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

  Future<User?> getUserById(int userId) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
    
    if (results.isNotEmpty) {
      return User.fromMap(results.first);
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

  Future<int> updateBio(int userId, String bio) async {
    final db = await database;
    return await db.update(
      'users',
      {'bio': bio},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> updateAchievements(int userId, String achievements) async {
    final db = await database;
    return await db.update(
      'users',
      {'achievements': achievements},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> updateUserSkills(int userId, List<String> skills) async {
    final db = await database;
    return await db.update(
      'users',
      {'services': jsonEncode(skills)},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> markAssessmentComplete(int userId) async {
    final db = await database;
    return await db.update(
      'users',
      {'hasCompletedAssessment': 1},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<bool> hasCompletedAssessment(int userId) async {
    final db = await database;
    final result = await db.query(
      'users',
      columns: ['hasCompletedAssessment'],
      where: 'id = ?',
      whereArgs: [userId],
    );
    
    if (result.isNotEmpty) {
      return (result.first['hasCompletedAssessment'] as int?) == 1;
    }
    return false;
  }

  Future<List<String>> getUserSkills(int userId) async {
    final db = await database;
    final result = await db.query(
      'users',
      columns: ['services'],
      where: 'id = ?',
      whereArgs: [userId],
    );
    
    if (result.isNotEmpty && result.first['services'] != null) {
      try {
        final List<dynamic> decoded = jsonDecode(result.first['services'] as String);
        return decoded.map((skill) => skill.toString()).toList();
      } catch (e) {
        print('Error decoding skills: $e');
        return [];
      }
    }
    return [];
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

  Future<int> updateJobStatus(int jobId, String status) async {
    final db = await database;
    return await db.update(
      'jobs',
      {'status': status},
      where: 'id = ?',
      whereArgs: [jobId],
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
    try {
      final db = await database;
      
      // Convert additional details to JSON string
      final Map<String, dynamic> applicationData = application.toMap();
      if (applicationData.containsKey('additionalDetails') && 
          applicationData['additionalDetails'] is Map<String, dynamic>) {
        applicationData['additionalDetails'] = jsonEncode(applicationData['additionalDetails']);
      }
      
      // Insert the application and get the application ID
      final applicationId = await db.insert('applications', applicationData);
      
      // Create a notification for the job owner
      // First, get the job to find the owner
      final job = await getJobById(application.jobId);
      if (job != null) {
        // Get applicant details for notification message
        final applicant = await getUserById(application.applicantId);
        
        // Create notification for job owner
        await createNotification(
          job.userId,  // Job owner's user ID
          application.applicantId,  // Applicant's user ID
          'application',  // Notification type
          '${applicant?.fullName ?? "Someone"} applied for your job "${job.title}"',  // Message
          jsonEncode({
            'jobId': job.id,
            'applicationId': applicationId,
            'applicantName': applicant?.fullName
          }),  // Additional details as JSON
        );
      }
      
      return applicationId;
    } catch (e) {
      print('Error inserting job application: $e');
      rethrow;
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

  Future<int> updateApplicationStatus(int applicationId, String status) async {
    final db = await database;
    return await db.update(
      'applications',
      {'status': status},
      where: 'id = ?',
      whereArgs: [applicationId],
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

  // Add this method to DatabaseHelper
  Future<void> forceUpgradeDatabaseSchema() async {
    final db = await database;
    try {
      // Add missing columns if they don't exist
      await db.execute('ALTER TABLE jobs ADD COLUMN uploaderName TEXT');
      await db.execute('ALTER TABLE jobs ADD COLUMN uploaderImage TEXT');
      await db.execute('ALTER TABLE jobs ADD COLUMN category TEXT'); // Add this line
      print('Manually added columns to jobs table');
    } catch (e) {
      print('Error adding columns (may already exist): $e');
    }
  }

  // Add this method to fetch user's job applications
  Future<List<Map<String, dynamic>>> getUserApplicationHistory(int userId) async {
    final db = await database;
    
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        a.id AS applicationId,
        a.status,
        a.appliedAt,
        a.additionalDetails,
        j.id AS jobId,
        j.title,
        j.description,
        j.budget,
        j.location,
        j.dateTime,
        j.status AS jobStatus,
        j.uploaderName,
        j.uploaderImage
      FROM 
        applications a
      INNER JOIN 
        jobs j ON a.jobId = j.id
      WHERE 
        a.applicantId = ?
      ORDER BY 
        a.appliedAt DESC
    ''', [userId]);
    
    return results;
  }

  // Add this to your DatabaseHelper class initialization
  Future<void> ensureDirectoriesExist() async {
    final appDir = await getApplicationDocumentsDirectory();
    final resumeDir = Directory('${appDir.path}/resumes');
    if (!await resumeDir.exists()) {
      await resumeDir.create(recursive: true);
    }
  }

  // New methods for messaging functionality

  Future<void> createMessagesTable() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        senderId INTEGER NOT NULL,
        receiverId INTEGER NOT NULL,
        jobId INTEGER NOT NULL,
        message TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        isRead INTEGER DEFAULT 0
      )
    ''');
  }

  Future<int> insertMessage(Map<String, dynamic> message) async {
    final db = await database;
    
    // Ensure the messages table exists
    await createMessagesTable();
    
    // Check if we need to modify the messages table to include attachment columns
    await _ensureMessageTableHasAttachmentColumns();
    
    return await db.insert('messages', message);
  }

  Future<List<Map<String, dynamic>>> getMessagesByJob(int jobId, int senderId, int receiverId) async {
    final db = await database;
    
    // Ensure the messages table exists
    await createMessagesTable();
    
    return await db.query(
      'messages',
      where: 'jobId = ? AND ((senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?))',
      whereArgs: [jobId, senderId, receiverId, receiverId, senderId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getConversations(int userId) async {
    final db = await database;
    
    try {
      return db.rawQuery('''
        SELECT 
          m.jobId, 
          j.title AS jobTitle,
          CASE
            WHEN m.senderId = ? THEN m.receiverId
            ELSE m.senderId
          END AS otherUserId,
          u.fullName AS otherUserName,
          u.profileImage AS otherUserImage,
          MAX(m.timestamp) AS lastMessageTime,
          (
            SELECT message FROM messages
            WHERE jobId = m.jobId
            AND ((senderId = ? AND receiverId = CASE
                                                  WHEN m.senderId = ? THEN m.receiverId
                                                  ELSE m.senderId
                                                END) 
                 OR 
                 (senderId = CASE
                              WHEN m.senderId = ? THEN m.receiverId
                              ELSE m.senderId
                            END 
                  AND receiverId = ?))
            ORDER BY timestamp DESC LIMIT 1
          ) AS lastMessage,
          (
            SELECT COUNT(*) FROM messages
            WHERE jobId = m.jobId
            AND receiverId = ?
            AND senderId = CASE
                            WHEN m.senderId = ? THEN m.receiverId
                            ELSE m.senderId
                          END
            AND isRead = 0
          ) AS unreadCount
        FROM messages m
        JOIN jobs j ON m.jobId = j.id
        JOIN users u ON (
          CASE
            WHEN m.senderId = ? THEN m.receiverId 
            ELSE m.senderId
          END = u.id
        )
        WHERE m.senderId = ? OR m.receiverId = ?
        GROUP BY m.jobId, otherUserId
        ORDER BY lastMessageTime DESC
      ''', [
        userId, userId, userId, userId, userId, 
        userId, userId, userId, userId, userId
      ]);
    } catch (e) {
      print('Error loading conversations: $e');
      return [];
    }
  }

  Future<int> markMessageAsRead(int messageId) async {
    final db = await database;
    return await db.update(
      'messages',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> markAllMessagesAsRead(int jobId, int senderId, int receiverId) async {
    final db = await database;
    return await db.update(
      'messages',
      {'isRead': 1},
      where: 'jobId = ? AND senderId = ? AND receiverId = ? AND isRead = 0',
      whereArgs: [jobId, senderId, receiverId],
    );
  }

  Future<int> getUnreadMessagesCount(int userId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM messages
      WHERE receiverId = ? AND isRead = 0
    ''', [userId]);
    
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Add this method to delete messages
  Future<int> deleteMessages(List<int> messageIds) async {
    final db = await database;
    return await db.delete(
      'messages',
      where: 'id IN (${messageIds.map((_) => '?').join(', ')})',
      whereArgs: messageIds,
    );
  }
  
  // Add this method to clear all messages in a chat
  Future<int> clearChat(int jobId, int user1Id, int user2Id) async {
    final db = await database;
    return await db.delete(
      'messages',
      where: 'jobId = ? AND ((senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?))',
      whereArgs: [jobId, user1Id, user2Id, user2Id, user1Id],
    );
  }
  
  // Add this method to ensure the messages table has attachment columns
  Future<void> _ensureMessageTableHasAttachmentColumns() async {
    try {
      final db = await database;
      final tableInfo = await db.rawQuery('PRAGMA table_info(messages)');
      
      // Check if attachmentPath column exists
      final hasAttachmentPath = tableInfo.any((column) => column['name'] == 'attachmentPath');
      if (!hasAttachmentPath) {
        await db.execute('ALTER TABLE messages ADD COLUMN attachmentPath TEXT');
      }
      
      // Check if attachmentType column exists
      final hasAttachmentType = tableInfo.any((column) => column['name'] == 'attachmentType');
      if (!hasAttachmentType) {
        await db.execute('ALTER TABLE messages ADD COLUMN attachmentType TEXT');
      }
      
    } catch (e) {
      print('Error ensuring message table has attachment columns: $e');
    }
  }

  // New methods for notifications functionality

  Future<int> createNotification(
    int userId, 
    int senderId, 
    String type, 
    String message,
    String details,
  ) async {
    final db = await database;
    
    return await db.insert('notifications', {
      'userId': userId,
      'senderId': senderId,
      'type': type,
      'message': message,
      'details': details,
      'createdAt': DateTime.now().toIso8601String(),
      'isRead': 0,
    });
  }

  Future<void> ensureNotificationsTableExists() async {
    try {
      final db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER NOT NULL,
          senderId INTEGER NOT NULL,
          type TEXT NOT NULL,
          message TEXT NOT NULL,
          details TEXT,
          createdAt TEXT NOT NULL,
          isRead INTEGER DEFAULT 0,
          FOREIGN KEY (userId) REFERENCES users (id),
          FOREIGN KEY (senderId) REFERENCES users (id)
        )
      ''');
      print('Notifications table check completed');
    } catch (e) {
      print('Error ensuring notifications table exists: $e');
    }
  }

  Future<Map<String, dynamic>> getDatabaseDiagnostics() async {
    final db = await database;
    final diagnostics = <String, dynamic>{};
    
    try {
      // Check tables
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      diagnostics['tables'] = tables.map((t) => t['name']).toList();
      
      // Check columns for each important table
      final tablesList = ['users', 'jobs', 'applications', 'messages', 'notifications'];
      diagnostics['columns'] = {};
      
      for (final table in tablesList) {
        if (diagnostics['tables']!.contains(table)) {
          final columns = await db.rawQuery('PRAGMA table_info($table)');
          diagnostics['columns'][table] = columns.map((c) => c['name']).toList();
        }
      }
      
      // Count records in each table
      diagnostics['recordCounts'] = {};
      for (final table in tablesList) {
        if (diagnostics['tables']!.contains(table)) {
          final count = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
          diagnostics['recordCounts'][table] = Sqflite.firstIntValue(count) ?? 0;
        }
      }
      
      return diagnostics;
    } catch (e) {
      print('Error getting database diagnostics: $e');
      return {'error': e.toString()};
    }
  }

  // Get user by job ID (to find job owner)
  Future<User?> getUserByJobId(int jobId) async {
    final db = await database;
    
    // Get the job to find the uploaderId
    final jobs = await db.query(
      'jobs',
      where: 'id = ?',
      whereArgs: [jobId],
    );
    
    if (jobs.isEmpty) {
      return null;
    }
    
    final uploaderId = jobs.first['uploaderId'];
    
    // Get the user by ID
    final users = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [uploaderId],
    );
    
    if (users.isEmpty) {
      return null;
    }
    
    return User.fromMap(users.first);
  }

  // Add a new rating
  Future<int> addRating(int jobId, int raterId, int ratedId, int rating, String? comment) async {
    final db = await database;
    
    // Check if this user has already rated for this job
    final existingRating = await db.query(
      'ratings',
      where: 'jobId = ? AND raterId = ? AND ratedId = ?',
      whereArgs: [jobId, raterId, ratedId],
    );
    
    if (existingRating.isNotEmpty) {
      // Update existing rating
      return await db.update(
        'ratings',
        {
          'rating': rating,
          'comment': comment,
          'createdAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existingRating.first['id']],
      );
    } else {
      // Create new rating
      return await db.insert(
        'ratings',
        {
          'jobId': jobId,
          'raterId': raterId,
          'ratedId': ratedId,
          'rating': rating,
          'comment': comment,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  // Check if user can rate (if they haven't rated yet)
  Future<bool> canRateUser(int jobId, int raterId, int ratedId) async {
    final db = await database;
    
    // First check if the job is completed
    final job = await getJobById(jobId);
    if (job == null || job.status != 'completed') {
      return false;
    }
    
    // Check if rating already exists
    final existingRating = await db.query(
      'ratings',
      where: 'jobId = ? AND raterId = ? AND ratedId = ?',
      whereArgs: [jobId, raterId, ratedId],
    );
    
    return existingRating.isEmpty;
  }

  // Get ratings received by a user
  Future<List<Map<String, dynamic>>> getUserRatings(int userId) async {
    final db = await database;
    
    return await db.rawQuery('''
      SELECT 
        r.*,
        u.fullName as raterName,
        u.profileImage as raterImage,
        j.title as jobTitle
      FROM ratings r
      JOIN users u ON r.raterId = u.id
      JOIN jobs j ON r.jobId = j.id
      WHERE r.ratedId = ?
      ORDER BY r.createdAt DESC
    ''', [userId]);
  }

  // Get average rating for a user
  Future<double> getUserAverageRating(int userId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT AVG(rating) as average
      FROM ratings
      WHERE ratedId = ?
    ''', [userId]);
    
    if (result.first['average'] == null) {
      return 0.0;
    }
    
    return (result.first['average'] as num).toDouble();
  }

  // Get jobs that can be rated by a user
  Future<List<Map<String, dynamic>>> getRatableJobs(int userId) async {
    final db = await database;
    
    // Find completed jobs where the user was either the owner or the hired applicant
    return await db.rawQuery('''
      SELECT 
        j.id as jobId,
        j.title,
        j.userId as ownerId,
        a.applicantId as workerId,
        u1.fullName as ownerName,
        u2.fullName as workerName,
        CASE WHEN j.userId = ? THEN a.applicantId ELSE j.userId END as ratedId
      FROM jobs j
      JOIN applications a ON j.id = a.jobId
      JOIN users u1 ON j.userId = u1.id
      JOIN users u2 ON a.applicantId = u2.id
      WHERE j.status = 'completed'
      AND a.status = 'accepted'
      AND (j.userId = ? OR a.applicantId = ?)
      AND NOT EXISTS (
        SELECT 1 FROM ratings r 
        WHERE r.jobId = j.id 
        AND r.raterId = ? 
        AND r.ratedId = CASE WHEN j.userId = ? THEN a.applicantId ELSE j.userId END
      )
    ''', [userId, userId, userId, userId, userId]);
  }

  Future<int> markJobAsCompleted(int jobId) async {
    final db = await database;
    
    // Update job status
    final result = await db.update(
      'jobs',
      {'status': 'completed'},
      where: 'id = ?',
      whereArgs: [jobId],
    );
    
    // Create notifications for both employer and worker
    if (result > 0) {
      final job = await getJobById(jobId);
      if (job != null) {
        final applications = await db.query(
          'applications',
          where: 'jobId = ? AND status = ?',
          whereArgs: [jobId, 'accepted'],
        );
        
        if (applications.isNotEmpty) {
          final applicantId = applications.first['applicantId'] as int;
          
          // Notify both parties that they can now rate each other
          await createNotification(
            job.userId,  // Notify employer
            applicantId,
            'job_completed',
            'Your job "${job.title}" is completed. You can now rate the worker.',
            jsonEncode({'jobId': jobId, 'ratedId': applicantId}),
          );
          
          await createNotification(
            applicantId,  // Notify worker
            job.userId,
            'job_completed',
            'Job "${job.title}" is marked as completed. You can now rate the employer.',
            jsonEncode({'jobId': jobId, 'ratedId': job.userId}),
          );
        }
      }
    }
    
    return result;
  }
}