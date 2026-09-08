.pragma library

// Pure helpers for the pomodoro widget. No QML types and no state, so the
// phase machine and the formatting can be reasoned about (and tested) on
// their own.

var IDLE = "idle"
var FOCUS = "focus"
var SHORT_BREAK = "shortBreak"
var LONG_BREAK = "longBreak"

var GLYPH_TIMER = "󰔟"
var GLYPH_COFFEE = "󰅶"
var GLYPH_PLAY = "󰐊"
var GLYPH_PAUSE = "󰏤"
var GLYPH_RESET = "󰑐"
var GLYPH_SKIP = "󰒭"

function clampInt(value, fallback, min, max) {
    var parsed = parseInt(value, 10)
    if (!isFinite(parsed)) return fallback
    return Math.min(max, Math.max(min, parsed))
}

function isBreak(phase) {
    return phase === SHORT_BREAK || phase === LONG_BREAK
}

function validPhase(phase) {
    var value = String(phase || IDLE)
    if (value === FOCUS || value === SHORT_BREAK || value === LONG_BREAK) return value
    return IDLE
}

// mm:ss, rounded up so a fresh 25-minute phase reads 25:00 rather than
// 24:59, and the last live second reads 00:01 rather than 00:00.
function formatClock(ms) {
    var total = Math.ceil(Math.max(0, ms) / 1000)
    var minutes = Math.floor(total / 60)
    var seconds = total % 60
    return (minutes < 10 ? "0" : "") + minutes + ":" + (seconds < 10 ? "0" : "") + seconds
}

function phaseLabel(phase) {
    if (phase === FOCUS) return "FOCUS"
    if (phase === SHORT_BREAK) return "SHORT BREAK"
    if (phase === LONG_BREAK) return "LONG BREAK"
    return "READY"
}

function phaseGlyph(phase) {
    return isBreak(phase) ? GLYPH_COFFEE : GLYPH_TIMER
}

function minutesFor(phase, config) {
    if (phase === SHORT_BREAK) return config.breakMinutes
    if (phase === LONG_BREAK) return config.longBreakMinutes
    return config.workMinutes
}

// What follows `phase` once it finishes. `completedInCycle` is the count
// *after* the finished focus has been added, so a full cycle earns the long
// break rather than the one after it.
function nextPhase(phase, completedInCycle, cyclesPerLong) {
    if (phase !== FOCUS) return FOCUS
    return completedInCycle >= cyclesPerLong ? LONG_BREAK : SHORT_BREAK
}

// "● ● ○ ○" — one filled dot per focus session banked in this cycle.
function cycleDots(completedInCycle, cyclesPerLong) {
    var dots = []
    for (var i = 0; i < cyclesPerLong; i++) dots.push(i < completedInCycle ? "●" : "○")
    return dots.join(" ")
}

// Body copy for the phase-change notification.
function announcement(finished, next, config) {
    if (isBreak(next)) {
        var label = next === LONG_BREAK ? "long break" : "break"
        return "Focus done — " + minutesFor(next, config) + " minute " + label + " started"
    }
    if (finished === LONG_BREAK) return "Long break over — ready when you are"
    return "Break over — ready to focus"
}
