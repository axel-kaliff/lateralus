# Pomodoro (`pneuma.pomodoro`)

A focus timer in the Omarchy bar. Idle is a lone hourglass; a running phase
puts a live `mm:ss` countdown on the bar, tinted with the theme's active color
during focus and swapped for a coffee glyph during breaks. Clicking opens a
panel with the phase, cycle progress, a big countdown, and transport controls.

## Architecture

The timer lives in `Service.qml`, declared as a `service` kind so the shell
loads exactly one per session. That matters on a multi-monitor setup: a bar
surface exists per monitor, so an engine living in the bar widget would run one
timer per screen and fire a completion notification from each. `BarWidget.qml`
is a stateless view over the service.

A running phase is stored as a wall-clock deadline (`endsAt`), never as a
decremented counter, so suspend/resume, a slow tick, and a shell restart all
resolve to the same remaining time. State persists to
`~/.local/state/omarchy/pomodoro.json`.

## Interactions

| Where | Action | Effect |
| --- | --- | --- |
| Bar pill | Left click | Open/close the panel |
| Bar pill | Middle click | Start / pause |
| Bar pill | Right click | Skip to the next phase |
| Panel | `Space` | Start / pause |
| Panel | `R` | Reset to idle |
| Panel | `S` | Skip phase |
| Panel | `Esc` | Close |

Breaks start on their own when a focus phase ends; focus always waits for a
deliberate start, so walking away never silently burns a session.

## Settings

Inline on the bar layout entry in `~/.config/omarchy/shell.json`. Numbers need
`--json` or they land as strings:

```sh
omarchy bar set pneuma.pomodoro workMinutes 50 --json
```

| Key | Default | Meaning |
| --- | --- | --- |
| `workMinutes` | `25` | Focus phase length |
| `breakMinutes` | `5` | Short break length |
| `longBreakMinutes` | `15` | Long break length |
| `cyclesPerLong` | `4` | Focus phases before a long break |
| `focusEndSound` | `service-login.oga` | Chime when a focus phase ends |
| `breakEndSound` | `string.ogg` | Chime when a break ends |

The two chimes are deliberately different, so the ear tells focus-over from
break-over without looking at the bar. Both take an absolute path to any file
`pw-play` can read, and `""` mutes one:

```sh
omarchy bar set pneuma.pomodoro focusEndSound /usr/share/sounds/freedesktop/stereo/complete.oga
omarchy bar set pneuma.pomodoro breakEndSound ""
```

Chimes follow the notification: they fire on a phase running out, not on a
manual skip, and not when a session that elapsed while the shell was down is
settled at startup.

## From scripts and keybindings

```sh
omarchy-shell pomodoro toggle | start | pause | skip | reset | status
omarchy-shell pneuma.pomodoro toggle          # the panel
```

`status` returns JSON. Note that the panel IPC routes to one monitor's bar
instance only — clicking the pill is per-monitor, as with the first-party
widgets.

## Dependencies

The phase-change notification calls `omarchy-notification-send`, and the chimes
call `pw-play`. Both are fire-and-forget: if either is missing the phase still
changes and the bar still updates.

Omarchy 4.0.0.alpha shipped a notification service that could not load on
Qt 6.10 (`var transient`, a reserved word), which left the desktop with no
notification daemon at all. Pneuma patches that in the image build
(`build/38-omarchy-qml-patches.sh`) and the fix is upstream in the pneuma-el10
omedora fork.
