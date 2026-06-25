package com.example.mycalendarmemo

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class DatabaseHelper(context: Context) :
    SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "CalendarMemo.db"
        private const val DATABASE_VERSION = 3
        const val TABLE_NAME = "memos"
        const val COLUMN_DATE = "memo_date"
        const val COLUMN_COLOR = "memo_color"
        const val COLUMN_REMARK = "memo_remark"
        const val COLUMN_PREDICT = "memo_predict"
        const val COLUMN_YELLOW_WHITE = "memo_yellow_white"
        const val COLUMN_IOPV = "memo_iopv"
        const val COLUMN_MARKET_COUNT = "memo_market_count"
        const val COLUMN_ACTION = "memo_action"
        const val COLUMN_NORTH = "memo_north"
    }

    override fun onCreate(db: SQLiteDatabase?) {
        val createTable = "CREATE TABLE $TABLE_NAME (" +
                "$COLUMN_DATE TEXT PRIMARY KEY, " +
                "$COLUMN_COLOR INTEGER, " +
                "$COLUMN_REMARK TEXT, " +
                "$COLUMN_PREDICT INTEGER DEFAULT 0, " +
                "$COLUMN_YELLOW_WHITE INTEGER DEFAULT 0, " +
                "$COLUMN_IOPV INTEGER DEFAULT 0, " +
                "$COLUMN_MARKET_COUNT INTEGER DEFAULT 0, " +
                "$COLUMN_ACTION INTEGER DEFAULT 0, " +
                "$COLUMN_NORTH INTEGER DEFAULT 0)"
        db?.execSQL(createTable)
    }

    override fun onUpgrade(db: SQLiteDatabase?, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db?.execSQL("ALTER TABLE $TABLE_NAME ADD COLUMN $COLUMN_PREDICT INTEGER DEFAULT 0")
        }
        if (oldVersion < 3) {
            db?.execSQL("ALTER TABLE $TABLE_NAME ADD COLUMN $COLUMN_YELLOW_WHITE INTEGER DEFAULT 0")
            db?.execSQL("ALTER TABLE $TABLE_NAME ADD COLUMN $COLUMN_IOPV INTEGER DEFAULT 0")
            db?.execSQL("ALTER TABLE $TABLE_NAME ADD COLUMN $COLUMN_MARKET_COUNT INTEGER DEFAULT 0")
            db?.execSQL("ALTER TABLE $TABLE_NAME ADD COLUMN $COLUMN_ACTION INTEGER DEFAULT 0")
            db?.execSQL("ALTER TABLE $TABLE_NAME ADD COLUMN $COLUMN_NORTH INTEGER DEFAULT 0")
        }
    }

    // 🔥 完整保存（包含做T字段）
    fun saveMemoFull(
        date: String,
        color: Int,
        remark: String,
        predict: Int,
        yellowWhite: Int,
        iopv: Int,
        marketCount: Int,
        action: Int,
        north: Int
    ): Boolean {
        val db = this.writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_DATE, date)
            put(COLUMN_COLOR, color)
            put(COLUMN_REMARK, remark)
            put(COLUMN_PREDICT, predict)
            put(COLUMN_YELLOW_WHITE, yellowWhite)
            put(COLUMN_IOPV, iopv)
            put(COLUMN_MARKET_COUNT, marketCount)
            put(COLUMN_ACTION, action)
            put(COLUMN_NORTH, north)
        }
        val result = db.insertWithOnConflict(
            TABLE_NAME, null, values, SQLiteDatabase.CONFLICT_REPLACE
        )
        db.close()
        return result != -1L
    }

    // 🔥 兼容旧方法
    fun saveMemoFull(date: String, color: Int, remark: String, predict: Int): Boolean {
        return saveMemoFull(date, color, remark, predict, 0, 0, 0, 0, 0)
    }

    // 保存旧数据（兼容）
    fun saveMemo(date: String, color: Int, remark: String): Boolean {
        return saveMemoFull(date, color, remark, 0, 0, 0, 0, 0, 0)
    }

    // 🔥 只更新预测
    fun updatePredict(date: String, predict: Int): Boolean {
        val db = this.writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_PREDICT, predict)
        }
        val result = db.update(TABLE_NAME, values, "$COLUMN_DATE = ?", arrayOf(date))
        db.close()
        return result > 0
    }

    // 🔥 查询某天的数据（去掉 override）
    fun getMemo(date: String): Memo? {
        val db = this.readableDatabase
        val cursor = db.query(
            TABLE_NAME,
            arrayOf(
                COLUMN_COLOR,
                COLUMN_REMARK,
                COLUMN_PREDICT,
                COLUMN_YELLOW_WHITE,
                COLUMN_IOPV,
                COLUMN_MARKET_COUNT,
                COLUMN_ACTION,
                COLUMN_NORTH
            ),
            "$COLUMN_DATE = ?",
            arrayOf(date),
            null,
            null,
            null
        )
        var memo: Memo? = null
        if (cursor.moveToFirst()) {
            val color = cursor.getInt(cursor.getColumnIndexOrThrow(COLUMN_COLOR))
            val remark = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_REMARK))
            val predict = cursor.getInt(cursor.getColumnIndexOrThrow(COLUMN_PREDICT))
            val yellowWhite = cursor.getInt(cursor.getColumnIndexOrThrow(COLUMN_YELLOW_WHITE))
            val iopv = cursor.getInt(cursor.getColumnIndexOrThrow(COLUMN_IOPV))
            val marketCount = cursor.getInt(cursor.getColumnIndexOrThrow(COLUMN_MARKET_COUNT))
            val action = cursor.getInt(cursor.getColumnIndexOrThrow(COLUMN_ACTION))
            val north = cursor.getInt(cursor.getColumnIndexOrThrow(COLUMN_NORTH))
            memo = Memo(
                date,
                color,
                remark,
                predict,
                yellowWhite,
                iopv,
                marketCount,
                action,
                north
            )
        }
        cursor.close()
        db.close()
        return memo
    }

    // 删除某天数据
    fun deleteMemo(date: String) {
        val db = this.writableDatabase
        db.delete(TABLE_NAME, "$COLUMN_DATE = ?", arrayOf(date))
        db.close()
    }
}