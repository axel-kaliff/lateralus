import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Singleton pomodoro engine. Declared as a `service` kind so the shell loads
// exactly one of these per session: a bar surface exists per monitor, so an
// engine living in the bar widget would run one timer per screen and fire a
// completion notification from each. Every bar widget is a thin view over
// this object.
//
// The running phase is stored as a wall-clock deadline rather than a
// decremented counter, so a suspended laptop, a slow tick, or a shell restart
// all resolve to the same remaining time.
Item {
  id: root

  // Injected by the shell's service loader.
  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  // Durations, pushed in from the bar widget's shell.json entry so they stay
  // configurable with `omarchy bar set` without this service needing its own
  // config file.
  property int workMinutes: 25
  property int breakMinutes: 5
  property int longBreakMinutes: 15
  property int cyclesPerLong: 4

  // Phase-end chimes, as absolute paths so any file works, not just the two
  // sound themes that happen to be installed. Set either to "" to mute it.
  // Distinct sounds on purpose: the ear should tell focus-over from
  // break-over without looking at the bar.
  readonly property string defaultFocusEndSound: "/usr/share/sounds/freedesktop/stereo/service-login.oga"
  readonly property string defaultBreakEndSound: "/usr/share/sounds/gnome/default/alerts/string.ogg"
  property string focusEndSound: defaultFocusEndSound
  property string breakEndSound: defaultBreakEndSound

  readonly property var config: ({
    workMinutes: root.workMinutes,
    breakMinutes: root.breakMinutes,
    longBreakMinutes: root.longBreakMinutes
  })

  property string phase: "idle"
  property bool running: false
  property double endsAt: 0     // epoch ms; authoritative while running
  property double pausedMs: 0   // remaining while paused or ready
  property double totalMs: 0
  property int completedInCycle: 0
  property bool loaded: false

  property double nowMs: Date.now()

  readonly property bool idle: phase === "idle"
  readonly property double remainingMs: running ? Math.max(0, endsAt - nowMs) : pausedMs
  readonly property string displayTime: Model.formatClock(remainingMs)
  readonly property string glyph: Model.phaseGlyph(phase)
  readonly property string label: Model.phaseLabel(phase)
  readonly property bool onBreak: Model.isBreak(phase)
  readonly property string dots: Model.cycleDots(completedInCycle, cyclesPerLong)
  readonly property real progress: totalMs > 0
    ? Math.max(0, Math.min(1, 1 - remainingMs / totalMs))
    : 0

  readonly property string notifyBin: (omarchyPath !== "" ? omarchyPath + "/bin/" : "") + "omarchy-notification-send"

  // ------------------------------------------------------------- transport

  function beginPhase(next, autoStart) {
    nowMs = Date.now()
    phase = next
    totalMs = Model.minutesFor(next, config) * 60000
    pausedMs = totalMs
    endsAt = autoStart ? nowMs + totalMs : 0
    running = autoStart
    scheduleSave()
  }

  function start() {
    if (idle) beginPhase("focus", true)
    else resume()
  }

  function pause() {
    if (!running) return
    nowMs = Date.now()
    pausedMs = Math.max(0, endsAt - nowMs)
    endsAt = 0
    running = false
    scheduleSave()
  }

  function resume() {
    if (running || idle || pausedMs <= 0) return
    nowMs = Date.now()
    endsAt = nowMs + pausedMs
    running = true
    scheduleSave()
  }

  function toggle() {
    if (running) pause()
    else start()
  }

  function reset() {
    phase = "idle"
    running = false
    endsAt = 0
    pausedMs = 0
    totalMs = 0
    completedInCycle = 0
    scheduleSave()
  }

  function skip() {
    if (!idle) advance(false)
  }

  // Roll the finished phase into the next one. Breaks start on their own so a
  // finished focus rolls straight into rest; focus always waits for a
  // deliberate start, so walking away never silently burns a session.
  function advance(notify) {
    var finished = phase
    if (finished === "focus") completedInCycle = Math.min(cyclesPerLong, completedInCycle + 1)
    else if (finished === "longBreak") completedInCycle = 0

    var next = Model.nextPhase(finished, completedInCycle, cyclesPerLong)
    beginPhase(next, Model.isBreak(next))
    if (notify) announce(finished, next)
  }

  function announce(finished, next) {
    Quickshell.execDetached([notifyBin, "-g", Model.phaseGlyph(next),
                             "Pomodoro", Model.announcement(finished, next, config)])
    chime(finished === "focus" ? focusEndSound : breakEndSound)
  }

  // Fire-and-forget: a missing player or a path that no longer exists costs a
  // silent phase change, never a stuck timer. Only reached from announce(), so
  // a manual skip and a session restored after the shell was down stay quiet.
  function chime(soundPath) {
    if (soundPath !== "") Quickshell.execDetached(["pw-play", soundPath])
  }

  // --------------------------------------------------------------- ticking

  // Only runs while a phase is live, so an idle bar costs nothing. Completion
  // is decided against the wall clock, not against a tick count.
  Timer {
    interval: 1000
    repeat: true
    running: root.running
    onTriggered: {
      root.nowMs = Date.now()
      if (root.endsAt > 0 && root.nowMs >= root.endsAt) root.advance(true)
    }
  }

  // ----------------------------------------------------------- persistence

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy"
  readonly property string statePath: stateDir + "/pomodoro.json"

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.hydrate(text())
    onLoadFailed: root.hydrate("")
  }

  Timer {
    id: saveTimer
    interval: 250
    repeat: false
    onTriggered: root.flush()
  }

  function scheduleSave() {
    if (loaded) saveTimer.restart()
  }

  function flush() {
    stateFile.setText(JSON.stringify({
      version: 1,
      phase: root.phase,
      running: root.running,
      endsAt: root.endsAt,
      pausedMs: root.pausedMs,
      totalMs: root.totalMs,
      completedInCycle: root.completedInCycle
    }) + "\n")
  }

  function hydrate(raw) {
    if (loaded) return
    var data = {}
    try { data = JSON.parse(raw || "{}") } catch (error) { data = {} }

    completedInCycle = Model.clampInt(data.completedInCycle, 0, 0, cyclesPerLong)
    nowMs = Date.now()
    loaded = true

    var savedPhase = Model.validPhase(data.phase)
    if (savedPhase === "idle") return

    phase = savedPhase
    totalMs = Math.max(0, Number(data.totalMs) || 0)
    var savedEndsAt = Number(data.endsAt) || 0

    if (data.running === true && savedEndsAt > nowMs) {
      endsAt = savedEndsAt
      pausedMs = 0
      running = true
      return
    }

    if (data.running === true) {
      // The phase elapsed while the shell was down. Settle on what should
      // come next, silently — a notification for something that finished an
      // hour ago is noise, not information.
      running = false
      endsAt = 0
      advance(false)
      return
    }

    pausedMs = Math.max(0, Number(data.pausedMs) || 0)
    endsAt = 0
    running = false
  }

  Process {
    id: ensureStateDir
    command: ["mkdir", "-p", root.stateDir]
  }

  Component.onCompleted: {
    ensureStateDir.running = true
    Qt.callLater(function () { stateFile.reload() })
  }

  // --------------------------------------------------------------- IPC

  // Lets Hyprland keybindings drive the timer without opening the panel:
  //   omarchy-shell pomodoro toggle
  IpcHandler {
    target: "pomodoro"

    function toggle(): string { root.toggle(); return "ok" }
    function start(): string { root.start(); return "ok" }
    function pause(): string { root.pause(); return "ok" }
    function skip(): string { root.skip(); return "ok" }
    function reset(): string { root.reset(); return "ok" }
    function status(): string {
      return JSON.stringify({
        phase: root.phase,
        label: root.label,
        running: root.running,
        remaining: root.displayTime,
        remainingMs: Math.round(root.remainingMs),
        completedInCycle: root.completedInCycle,
        cyclesPerLong: root.cyclesPerLong,
        workMinutes: root.workMinutes,
        breakMinutes: root.breakMinutes,
        longBreakMinutes: root.longBreakMinutes
      })
    }
  }
}
