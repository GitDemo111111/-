package com.example.mycalendarmemo

import android.content.Context
import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class CalendarAdapter(
    private val context: Context,
    private val dates: List<Date>,
    private val currentMonth: Calendar,
    private val dbHelper: DatabaseHelper,
    private val onPredictChanged: (String, Int) -> Unit,
    private val onDateSelected: (Int) -> Unit
) : BaseAdapter() {

    companion object {
        private val STOCK_RED = Color.parseColor("#E74C3C")
        private val STOCK_GREEN = Color.parseColor("#27AE60")
    }

    private var selectedPosition: Int = -1

    override fun getCount(): Int = dates.size
    override fun getItem(position: Int): Date = dates[position]
    override fun getItemId(position: Int): Long = position.toLong()

    fun setSelectedPosition(position: Int) {
        selectedPosition = position
        notifyDataSetChanged()
    }

    override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
        val view = convertView
            ?: LayoutInflater.from(context).inflate(R.layout.grid_item_day, parent, false)

        val tvDay = view.findViewById<TextView>(R.id.tvDayNumber)
        val viewSelectionBorder = view.findViewById<View>(R.id.viewSelectionBorder)
        val tvPredictMark = view.findViewById<TextView>(R.id.tvPredictMark)

        val date = getItem(position)
        val dateCal = Calendar.getInstance().apply { time = date }

        tvDay.text = dateCal.get(Calendar.DAY_OF_MONTH).toString()

        val dateStr = String.format(
            Locale.getDefault(), "%04d-%02d-%02d",
            dateCal.get(Calendar.YEAR),
            dateCal.get(Calendar.MONTH) + 1,
            dateCal.get(Calendar.DAY_OF_MONTH)
        )

        // 非当前月份灰色
        if (dateCal.get(Calendar.MONTH) == currentMonth.get(Calendar.MONTH)) {
            tvDay.setTextColor(Color.BLACK)
        } else {
            tvDay.setTextColor(Color.LTGRAY)
        }

        // 1. 用户标注的颜色（背景色）
        val memo = dbHelper.getMemo(dateStr)
        if (memo != null && memo.color != Color.TRANSPARENT) {
            view.setBackgroundColor(memo.color)
            if (memo.color == STOCK_RED) {
                tvDay.setTextColor(Color.WHITE)
            } else {
                tvDay.setTextColor(Color.BLACK)
            }
        } else {
            view.setBackgroundColor(Color.TRANSPARENT)
        }

        // 🔥 2. 显示预测 ✓/✗（小尺寸，不遮挡日期）
        if (memo != null && memo.predict != 0) {
            tvPredictMark.visibility = View.VISIBLE
            when (memo.predict) {
                1 -> {
                    tvPredictMark.text = "✓"
                    tvPredictMark.setTextColor(STOCK_GREEN)
                    tvPredictMark.setBackgroundResource(R.drawable.predict_circle_green)
                }
                -1 -> {
                    tvPredictMark.text = "✗"
                    tvPredictMark.setTextColor(STOCK_RED)
                    tvPredictMark.setBackgroundResource(R.drawable.predict_circle_red)
                }
                else -> tvPredictMark.visibility = View.GONE
            }
        } else {
            tvPredictMark.visibility = View.GONE
        }

        // 今天加粗
        val today = Calendar.getInstance()
        val isToday = dateCal.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                dateCal.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
        tvDay.paint.isFakeBoldText = isToday

        // 选中框
        if (selectedPosition == position) {
            viewSelectionBorder.visibility = View.VISIBLE
        } else {
            viewSelectionBorder.visibility = View.GONE
        }

        view.setOnClickListener {
            onDateSelected(position)
        }

        view.setOnLongClickListener {
            togglePredict(dateStr, memo)
            true
        }

        return view
    }

    private fun togglePredict(dateStr: String, currentMemo: Memo?) {
        val currentPredict = currentMemo?.predict ?: 0
        val newPredict = when (currentPredict) {
            0 -> 1
            1 -> -1
            else -> 0
        }

        val existing = dbHelper.getMemo(dateStr)
        if (existing != null) {
            val success = dbHelper.updatePredict(dateStr, newPredict)
            if (success) {
                notifyDataSetChanged()
                onPredictChanged(dateStr, newPredict)
            }
        } else {
            val saved = dbHelper.saveMemoFull(dateStr, Color.TRANSPARENT, "", newPredict)
            if (saved) {
                notifyDataSetChanged()
                onPredictChanged(dateStr, newPredict)
            }
        }
    }
}