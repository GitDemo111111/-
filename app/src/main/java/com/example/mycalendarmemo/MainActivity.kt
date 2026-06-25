package com.example.mycalendarmemo

import android.graphics.Color
import android.media.AudioManager
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.GridView
import android.widget.RadioGroup
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import java.text.SimpleDateFormat
import java.util.ArrayList
import java.util.Calendar
import java.util.Date
import java.util.Locale

class MainActivity : AppCompatActivity() {

    companion object {
        val STOCK_RED = Color.parseColor("#E74C3C")
        val STOCK_GREEN = Color.parseColor("#27AE60")
    }

    private lateinit var dbHelper: DatabaseHelper
    private var selectedDateStr: String = ""
    private var currentCalendar: Calendar = Calendar.getInstance()
    private var selectedGridPosition: Int = -1

    private lateinit var tvMonthYear: TextView
    private lateinit var calendarGrid: GridView
    private lateinit var tvSelectedDate: TextView
    private lateinit var viewColorIndicator: View
    private lateinit var tvRemarkContent: TextView
    private lateinit var calendarAdapter: CalendarAdapter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        dbHelper = DatabaseHelper(this)

        tvMonthYear = findViewById(R.id.tvMonthYear)
        calendarGrid = findViewById(R.id.calendarGrid)
        tvSelectedDate = findViewById(R.id.tvSelectedDate)
        viewColorIndicator = findViewById(R.id.viewColorIndicator)
        tvRemarkContent = findViewById(R.id.tvRemarkContent)

        val btnPrevMonth = findViewById<Button>(R.id.btnPrevMonth)
        val btnNextMonth = findViewById<Button>(R.id.btnNextMonth)
        val btnEditRemark = findViewById<Button>(R.id.btnEditRemark)
        val btnSummary = findViewById<Button>(R.id.btnSummary)

        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        selectedDateStr = sdf.format(Calendar.getInstance().time)
        tvSelectedDate.text = "选中日期：$selectedDateStr"

        updateCalendarGrid()
        loadDateData(selectedDateStr)

        btnPrevMonth.setOnClickListener {
            currentCalendar.add(Calendar.MONTH, -1)
            selectedGridPosition = -1
            updateCalendarGrid()
        }

        btnNextMonth.setOnClickListener {
            currentCalendar.add(Calendar.MONTH, 1)
            selectedGridPosition = -1
            updateCalendarGrid()
        }

        // 🔥 日总结（原添加备注）
        btnEditRemark.setOnClickListener {
            playClickSound()
            showRemarkDialog()
        }

        // 🔥 月总结（原总结）
        btnSummary.setOnClickListener {
            playClickSound()
            showSummaryDialog()
        }
    }

    private fun playClickSound() {
        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        audioManager.playSoundEffect(AudioManager.FX_KEY_CLICK)
    }

    private fun onDateSelected(position: Int) {
        playClickSound()

        val clickedDate = calendarGrid.adapter.getItem(position) as Date
        val cal = Calendar.getInstance().apply { time = clickedDate }
        selectedDateStr = String.format(
            Locale.getDefault(), "%04d-%02d-%02d",
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH)
        )
        tvSelectedDate.text = "选中日期：$selectedDateStr"

        selectedGridPosition = position
        calendarAdapter.setSelectedPosition(position)

        loadDateData(selectedDateStr)
    }

    private fun onPredictChanged(date: String, predict: Int) {
        val predictText = when (predict) {
            1 -> "✓"
            -1 -> "✗"
            else -> "无"
        }
        Toast.makeText(this, "预测已更新: $predictText", Toast.LENGTH_SHORT).show()
        if (date == selectedDateStr) {
            loadDateData(date)
        }
    }

    private fun updateCalendarGrid() {
        val dates = ArrayList<Date>()
        val monthCal = currentCalendar.clone() as Calendar
        monthCal.set(Calendar.DAY_OF_MONTH, 1)

        val firstDayOfWeek = monthCal.get(Calendar.DAY_OF_WEEK) - 1
        monthCal.add(Calendar.DAY_OF_MONTH, -firstDayOfWeek)

        repeat(42) {
            dates.add(monthCal.time)
            monthCal.add(Calendar.DAY_OF_MONTH, 1)
        }

        val sdf = SimpleDateFormat("yyyy年 MM月", Locale.getDefault())
        tvMonthYear.text = sdf.format(currentCalendar.time)

        calendarAdapter = CalendarAdapter(
            this,
            dates,
            currentCalendar,
            dbHelper,
            this::onPredictChanged,
            this::onDateSelected
        )
        if (selectedGridPosition != -1) {
            calendarAdapter.setSelectedPosition(selectedGridPosition)
        }
        calendarGrid.adapter = calendarAdapter
    }

    private fun loadDateData(date: String) {
        val memo = dbHelper.getMemo(date)

        if (memo != null) {
            viewColorIndicator.setBackgroundColor(memo.color)

            val sb = StringBuilder()

            if (memo.yellowWhite != 0 || memo.iopv != 0 || memo.marketCount > 0 ||
                memo.action != 0 || memo.north != 0) {
                sb.appendLine("📊 【做T记录】")

                val ywText = when (memo.yellowWhite) {
                    1 -> "🟡 黄上白下"
                    2 -> "⬜ 白上黄下"
                    else -> ""
                }
                if (ywText.isNotEmpty()) sb.appendLine("  黄白线: $ywText")

                val iopvText = when (memo.iopv) {
                    1 -> "📈 溢价"
                    2 -> "📉 折价"
                    else -> ""
                }
                if (iopvText.isNotEmpty()) sb.appendLine("  IOPV: $iopvText")

                if (memo.marketCount > 0) {
                    sb.appendLine("  涨跌家数: ${memo.marketCount}")
                }

                val actionText = when (memo.action) {
                    1 -> "📈 正T (先买后卖)"
                    2 -> "📉 倒T (先卖后买)"
                    else -> ""
                }
                if (actionText.isNotEmpty()) sb.appendLine("  操作: $actionText")

                val northText = when (memo.north) {
                    1 -> "🟢 流入"
                    2 -> "🔴 流出"
                    3 -> "🔄 拐头"
                    else -> ""
                }
                if (northText.isNotEmpty()) sb.appendLine("  北向资金: $northText")
            }

            val predictStr = when (memo.predict) {
                1 -> " [✓]"
                -1 -> " [✗]"
                else -> ""
            }

            if (memo.remark.isNotEmpty()) {
                if (sb.isNotEmpty()) sb.appendLine()
                sb.appendLine("📝 【详细记录】")
                sb.append(memo.remark)
            }

            val finalText = sb.toString().trim()
            if (finalText.isNotEmpty()) {
                tvRemarkContent.text = finalText + predictStr
                tvRemarkContent.hint = ""
            } else {
                tvRemarkContent.text = ""
                tvRemarkContent.hint = "这一天还没有写下任何备注，可以涂色和记录哦..."
            }
        } else {
            viewColorIndicator.setBackgroundColor(Color.parseColor("#CCCCCC"))
            tvRemarkContent.text = ""
            tvRemarkContent.hint = "这一天还没有写下任何备注，可以涂色和记录哦..."
        }
    }

    // 🔥 月总结
    private fun showSummaryDialog() {
        val year = currentCalendar.get(Calendar.YEAR)
        val month = currentCalendar.get(Calendar.MONTH)

        val monthCal = Calendar.getInstance().apply {
            set(year, month, 1)
        }
        val daysInMonth = monthCal.getActualMaximum(Calendar.DAY_OF_MONTH)

        var colorRed = 0
        var colorGreen = 0
        var predictTrue = 0
        var predictFalse = 0
        var validDays = 0
        var totalActions = 0
        var longTCount = 0
        var shortTCount = 0

        for (day in 1..daysInMonth) {
            val dateStr = String.format(Locale.getDefault(), "%04d-%02d-%02d", year, month + 1, day)
            val memo = dbHelper.getMemo(dateStr)

            if (memo != null) {
                when (memo.color) {
                    STOCK_RED -> colorRed++
                    STOCK_GREEN -> colorGreen++
                }

                when (memo.predict) {
                    1 -> predictTrue++
                    -1 -> predictFalse++
                }

                val hasColor = memo.color != Color.TRANSPARENT
                val hasPredict = memo.predict != 0
                if (hasColor && hasPredict) {
                    validDays++
                }

                when (memo.action) {
                    1 -> { totalActions++; longTCount++ }
                    2 -> { totalActions++; shortTCount++ }
                }
            }
        }

        val accuracy = if (predictTrue + predictFalse > 0) {
            (predictTrue.toDouble() / (predictTrue + predictFalse) * 100).toInt()
        } else {
            0
        }

        val summaryText = """
            📅 ${year}年 ${month + 1}月

            【颜色统计】
              🔴 红色: $colorRed 天
              🟢 绿色: $colorGreen 天

            【预测统计】
              ✅ 正确 (✓): $predictTrue 天
              ❌ 错误 (✗): $predictFalse 天

            【操作统计】
              📈 正T: $longTCount 次
              📉 倒T: $shortTCount 次
              总操作: $totalActions 次

            【汇总】
              有效数据天数: $validDays 天
              预测准确率: $accuracy%
        """.trimIndent()

        AlertDialog.Builder(this)
            .setTitle("📊 月总结")
            .setMessage(summaryText)
            .setPositiveButton("确定") { dialog, _ -> dialog.dismiss() }
            .show()
    }

    // 🔥 日总结（原添加备注，包含颜色和做T表单）
    private fun showRemarkDialog() {
        val builder = AlertDialog.Builder(this)
        builder.setTitle("📝 日总结 - $selectedDateStr")

        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_edit_memo, null)
        builder.setView(dialogView)

        val etRemarkInput = dialogView.findViewById<EditText>(R.id.etRemarkInput)
        val etMarketCount = dialogView.findViewById<EditText>(R.id.etMarketCount)

        val rgColors = dialogView.findViewById<RadioGroup>(R.id.rgColors)
        val rgYellowWhite = dialogView.findViewById<RadioGroup>(R.id.rgYellowWhite)
        val rgIopv = dialogView.findViewById<RadioGroup>(R.id.rgIopv)
        val rgAction = dialogView.findViewById<RadioGroup>(R.id.rgAction)
        val rgNorth = dialogView.findViewById<RadioGroup>(R.id.rgNorth)

        val existingMemo = dbHelper.getMemo(selectedDateStr)
        if (existingMemo != null) {
            when (existingMemo.color) {
                STOCK_RED -> rgColors.check(R.id.rbRed)
                STOCK_GREEN -> rgColors.check(R.id.rbGreen)
                else -> rgColors.check(R.id.rbNone)
            }
            etRemarkInput.setText(existingMemo.remark)

            when (existingMemo.yellowWhite) {
                1 -> rgYellowWhite.check(R.id.rbYellowUp)
                2 -> rgYellowWhite.check(R.id.rbWhiteUp)
                else -> rgYellowWhite.check(R.id.rbYellowWhiteNone)
            }

            when (existingMemo.iopv) {
                1 -> rgIopv.check(R.id.rbPremium)
                2 -> rgIopv.check(R.id.rbDiscount)
                else -> rgIopv.check(R.id.rbIopvNone)
            }

            if (existingMemo.marketCount > 0) {
                etMarketCount.setText(existingMemo.marketCount.toString())
            }

            when (existingMemo.action) {
                1 -> rgAction.check(R.id.rbLongT)
                2 -> rgAction.check(R.id.rbShortT)
                else -> rgAction.check(R.id.rbActionNone)
            }

            when (existingMemo.north) {
                1 -> rgNorth.check(R.id.rbNorthIn)
                2 -> rgNorth.check(R.id.rbNorthOut)
                3 -> rgNorth.check(R.id.rbNorthTurn)
                else -> rgNorth.check(R.id.rbNorthNone)
            }
        } else {
            rgColors.check(R.id.rbNone)
            rgYellowWhite.check(R.id.rbYellowWhiteNone)
            rgIopv.check(R.id.rbIopvNone)
            rgAction.check(R.id.rbActionNone)
            rgNorth.check(R.id.rbNorthNone)
        }

        builder.setPositiveButton("保存") { dialog, _ ->
            val chosenColor = when (rgColors.checkedRadioButtonId) {
                R.id.rbRed -> STOCK_RED
                R.id.rbGreen -> STOCK_GREEN
                else -> Color.TRANSPARENT
            }

            val yellowWhite = when (rgYellowWhite.checkedRadioButtonId) {
                R.id.rbYellowUp -> 1
                R.id.rbWhiteUp -> 2
                else -> 0
            }

            val iopv = when (rgIopv.checkedRadioButtonId) {
                R.id.rbPremium -> 1
                R.id.rbDiscount -> 2
                else -> 0
            }

            val marketCount = etMarketCount.text.toString().toIntOrNull() ?: 0

            val action = when (rgAction.checkedRadioButtonId) {
                R.id.rbLongT -> 1
                R.id.rbShortT -> 2
                else -> 0
            }

            val north = when (rgNorth.checkedRadioButtonId) {
                R.id.rbNorthIn -> 1
                R.id.rbNorthOut -> 2
                R.id.rbNorthTurn -> 3
                else -> 0
            }

            val remarkText = etRemarkInput.text.toString().trim()

            val existing = dbHelper.getMemo(selectedDateStr)
            val currentPredict = existing?.predict ?: 0

            if (chosenColor == Color.TRANSPARENT && remarkText.isEmpty() &&
                currentPredict == 0 && yellowWhite == 0 && iopv == 0 &&
                marketCount == 0 && action == 0 && north == 0) {
                dbHelper.deleteMemo(selectedDateStr)
            } else {
                dbHelper.saveMemoFull(
                    selectedDateStr,
                    chosenColor,
                    remarkText,
                    currentPredict,
                    yellowWhite,
                    iopv,
                    marketCount,
                    action,
                    north
                )
            }

            Toast.makeText(this, "✅ 已保存", Toast.LENGTH_SHORT).show()
            playClickSound()
            updateCalendarGrid()
            loadDateData(selectedDateStr)
            dialog.dismiss()
        }

        builder.setNegativeButton("取消") { dialog, _ -> dialog.dismiss() }
        builder.show()
    }
}