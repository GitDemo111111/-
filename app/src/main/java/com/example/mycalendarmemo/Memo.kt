package com.example.mycalendarmemo

data class Memo(
    val date: String,
    val color: Int,
    val remark: String,
    val predict: Int = 0,
    val yellowWhite: Int = 0,
    val iopv: Int = 0,
    val marketCount: Int = 0,
    val action: Int = 0,
    val north: Int = 0
)