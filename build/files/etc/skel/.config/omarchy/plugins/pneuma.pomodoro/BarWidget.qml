import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The bar pill and its transport popup. Deliberately stateless: every value
// painted here is read off the `pneuma.pomodoro` service singleton, so both
// monitors' bars show one shared countdown instead of racing timers.
BarWidget {
  id: root
  moduleName: "pneuma.pomodoro"

  // serviceFor() is a function call, not a property, so a binding on it would
  // never re-evaluate once the shell finishes constructing the service.
  // Resolve it once and retry until it exists.
  property var pomo: null

  // Keyed on identity rather than "have we resolved yet": a plugin code reload
  // builds a fresh service, and a widget that kept the old handle would push
  // its settings into a dead object and read a frozen countdown.
  function resolveService() {
    var found = bar && bar.shell && typeof bar.shell.serviceFor === "function"
      ? bar.shell.serviceFor(root.moduleName)
      : null
    if (!found || found === pomo) return
    pomo = found
    pushSettings()
  }

  // Durations live on this widget's shell.json entry so `omarchy bar set`
  // configures them; the service is what actually consumes them.
  function pushSettings() {
    if (!pomo) return
    pomo.workMinutes = Model.clampInt(setting("workMinutes", 25), 25, 1, 180)
    pomo.breakMinutes = Model.clampInt(setting("breakMinutes", 5), 5, 1, 180)
    pomo.longBreakMinutes = Model.clampInt(setting("longBreakMinutes", 15), 15, 1, 180)
    pomo.cyclesPerLong = Model.clampInt(setting("cyclesPerLong", 4), 4, 1, 12)
    pomo.focusEndSound = String(setting("focusEndSound", pomo.defaultFocusEndSound))
    pomo.breakEndSound = String(setting("breakEndSound", pomo.defaultBreakEndSound))
  }

  onBarChanged: resolveService()
  onSettingsChanged: pushSettings()
  Component.onCompleted: resolveService()

  Timer {
    interval: 400
    repeat: true
    running: root.pomo === null
    onTriggered: root.resolveService()
  }

  readonly property bool live: pomo ? !pomo.idle : false
  readonly property bool ticking: pomo ? pomo.running : false
  readonly property bool onBreak: pomo ? pomo.onBreak : false
  readonly property string timeText: pomo ? pomo.displayTime : "00:00"
  readonly property string glyph: pomo ? pomo.glyph : Model.GLYPH_TIMER
  readonly property string phaseText: pomo ? pomo.label : "READY"

  // Idle is a lone glyph; a live phase puts the countdown on the bar, which is
  // the entire point of the widget. A vertical bar has no room for mm:ss, so
  // it keeps the glyph and leaves the time to the tooltip.
  readonly property string pillText: live && !vertical ? glyph + "  " + timeText : glyph

  readonly property string tooltip: live
    ? phaseText + " · " + timeText + (ticking ? "" : " · paused")
    : "Pomodoro — click to start"

  // ---- popup lifecycle. open/close/opened is the shape the bar's popout
  //      coordinator and `omarchy-shell shell toggle` both route through.
  property bool popupOpen: false
  readonly property bool opened: popupOpen
  readonly property bool popoutSwitchClosing: panel.popoutSwitchClosing

  function open() { popupOpen = true }
  function close() { popupOpen = false }
  function togglePanel() { popupOpen = !popupOpen }
  function closeForPopoutSwitch() { panel.closeForPopoutSwitch() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.pillText
    tooltipText: root.tooltip
    // Focus takes the bar's active color so a running session is obvious at a
    // glance; a break stays in the normal foreground and is told apart by its
    // coffee glyph. Paused dims, whatever the phase.
    active: root.live && !root.onBreak
    dimmed: root.live && !root.ticking

    onPressed: function (b) {
      if (!root.pomo) return
      if (b === Qt.RightButton) root.pomo.skip()
      else if (b === Qt.MiddleButton) root.pomo.toggle()
      else root.togglePanel()
    }
  }

  // Mirrors the first-party widgets: lets a keybinding open the panel with
  // `omarchy-shell pneuma.pomodoro toggle`. A bar surface exists per monitor,
  // but an IPC target only ever routes to one of them, which is what we want
  // for a popup.
  IpcHandler {
    target: "pneuma.pomodoro"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.popupOpen
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(250))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    onOpenChanged: if (!open) root.popupOpen = false

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onActivateRequested: if (root.pomo) root.pomo.toggle()
      onCloseRequested: root.close()
      onTabRequested: function (direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
          root.bar.switchPanelFrom(root, direction)
      }
      onTextKey: function (text) {
        if (!root.pomo) return
        var key = text.toLowerCase()
        if (key === "r") root.pomo.reset()
        else if (key === "s") root.pomo.skip()
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // Phase on the left, cycle progress on the right.
        Item {
          width: parent.width
          implicitHeight: phaseLabel.implicitHeight

          Text {
            id: phaseLabel
            anchors.left: parent.left
            text: root.phaseText
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1.6
            font.bold: true
            renderType: Text.NativeRendering
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: phaseLabel.verticalCenter
            text: root.pomo ? root.pomo.dots : ""
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            renderType: Text.NativeRendering
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.timeText
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.displayLarge * 1.5)
          renderType: Text.NativeRendering
        }

        // Progress runs left to right as the phase burns down.
        Rectangle {
          width: parent.width
          height: Style.space(4)
          radius: height / 2
          color: Style.normalFill

          Rectangle {
            width: parent.width * (root.pomo ? root.pomo.progress : 0)
            height: parent.height
            radius: parent.radius
            color: root.onBreak ? Color.popups.text : Color.accent

            Behavior on width {
              NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
            }
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(10)

          Button {
            iconText: root.ticking ? Model.GLYPH_PAUSE : Model.GLYPH_PLAY
            tooltipText: root.ticking ? "Pause" : "Start"
            foreground: Color.popups.text
            accent: Color.accent
            fontFamily: Style.font.family
            onClicked: if (root.pomo) root.pomo.toggle()
          }

          Button {
            iconText: Model.GLYPH_RESET
            tooltipText: "Reset"
            foreground: Color.popups.text
            accent: Color.accent
            fontFamily: Style.font.family
            onClicked: if (root.pomo) root.pomo.reset()
          }

          Button {
            iconText: Model.GLYPH_SKIP
            tooltipText: "Skip phase"
            foreground: Color.popups.text
            accent: Color.accent
            fontFamily: Style.font.family
            onClicked: if (root.pomo) root.pomo.skip()
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: (root.ticking ? "Space pause" : "Space start") + " · R reset · S skip"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          renderType: Text.NativeRendering
        }
      }
    }
  }
}
