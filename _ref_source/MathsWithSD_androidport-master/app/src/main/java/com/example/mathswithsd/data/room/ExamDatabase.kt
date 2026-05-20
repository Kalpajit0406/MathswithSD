package com.example.mathswithsd.data.room

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(database: SupportSQLiteDatabase) {
        database.execSQL("""
            CREATE TABLE IF NOT EXISTS `announcements` (
                `id` TEXT NOT NULL PRIMARY KEY,
                `title` TEXT NOT NULL,
                `message` TEXT NOT NULL,
                `image` TEXT,
                `targetClass` TEXT NOT NULL,
                `createdAt` INTEGER NOT NULL,
                `isRead` INTEGER NOT NULL DEFAULT 0
            )
        """.trimIndent())
    }
}

val MIGRATION_2_3 = object : Migration(2, 3) {
    override fun migrate(database: SupportSQLiteDatabase) {
        database.execSQL("""
            CREATE TABLE IF NOT EXISTS `test_results` (
                `sessionId` TEXT NOT NULL PRIMARY KEY,
                `testId` TEXT NOT NULL,
                `testTitle` TEXT NOT NULL,
                `score` INTEGER NOT NULL,
                `totalQuestions` INTEGER NOT NULL,
                `timeTakenMillis` INTEGER NOT NULL,
                `completedAt` INTEGER NOT NULL
            )
        """.trimIndent())
    }
}

@Database(
    entities = [SavedAnswerEntity::class, OngoingTestEntity::class, AnnouncementEntity::class, TestResultEntity::class],
    version = 3,
    exportSchema = false
)
abstract class ExamDatabase : RoomDatabase() {
    abstract fun examDao(): ExamDao
    abstract fun announcementDao(): AnnouncementDao

    companion object {
        @Volatile private var INSTANCE: ExamDatabase? = null

        fun getDatabase(context: android.content.Context): ExamDatabase {
            return INSTANCE ?: synchronized(this) {
                androidx.room.Room.databaseBuilder(
                    context.applicationContext,
                    ExamDatabase::class.java,
                    "exam_database"
                )
                    .addMigrations(MIGRATION_1_2, MIGRATION_2_3)
                    .fallbackToDestructiveMigration()
                    .build()
                    .also { INSTANCE = it }
            }
        }
    }
}
