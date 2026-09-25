import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "jaj.weather-fx"
  ipcTarget: "jaj.weather-fx.widget"

  readonly property string settingsFile: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather-fx.json"

  property string mode: "auto"
  property string lastManualMode: "rain"
  property string effective: "off"
  property string autoCondition: "off"
  property string conditionDescription: ""
  property real presence: 0.35
  property real intensity: 0.30
  property real effectOpacity: 0.28
  property real speed: 0.50

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function weatherIcon() {
    var eff = mode === "auto" ? autoCondition : mode
    if (mode === "auto") {
      if (eff === "rain") return ""
      if (eff === "thunderstorm") return ""
      if (eff === "snow") return ""
      if (eff === "fog") return ""
      if (eff === "sun") return ""
      return "󰖐"
    }
    if (eff === "rain") return ""
    if (eff === "thunderstorm") return ""
    if (eff === "snow") return ""
    if (eff === "fog") return ""
    if (eff === "sun") return ""
    return "󰖪"
  }

  function statusSubtitle() {
    if (mode === "auto") {
      var d = conditionDescription ? conditionDescription : "Auto-detecting"
      return "Live: " + d + " (" + (autoCondition === "off" ? "dry" : autoCondition) + ")"
    }
    if (mode === "off") return "Disabled"
    return "Manual: " + mode
  }

  function setMode(newMode) {
    if (newMode !== "auto" && newMode !== "off") {
      lastManualMode = newMode
    }
    mode = newMode
    saveSettings()
    Quickshell.execDetached(["omarchy-shell", "-q", "weather_fx", "setMode", newMode])
  }

  function setPresence(val) {
    presence = Math.max(0.05, Math.min(1.0, val))
    saveSettings()
    Quickshell.execDetached(["omarchy-shell", "-q", "weather_fx", "setPresence", String(presence)])
  }

  function setIntensity(val) {
    intensity = Math.max(0.05, Math.min(1.0, val))
    saveSettings()
    Quickshell.execDetached(["omarchy-shell", "-q", "weather_fx", "setIntensity", String(intensity)])
  }

  function setOpacity(val) {
    effectOpacity = Math.max(0.05, Math.min(0.80, val))
    saveSettings()
    Quickshell.execDetached(["omarchy-shell", "-q", "weather_fx", "setOpacity", String(effectOpacity)])
  }

  function setSpeed(val) {
    speed = Math.max(0.20, Math.min(1.20, val))
    saveSettings()
    Quickshell.execDetached(["omarchy-shell", "-q", "weather_fx", "setSpeed", String(speed)])
  }

  function loadSettings(raw) {
    try {
      var data = JSON.parse(raw || "{}")
      if (data && typeof data === "object") {
        if (data.mode !== undefined) mode = String(data.mode)
        if (data.lastManualMode !== undefined) lastManualMode = String(data.lastManualMode)
        if (data.effective !== undefined) effective = String(data.effective)
        if (data.autoCondition !== undefined) autoCondition = String(data.autoCondition)
        if (data.conditionDescription !== undefined) conditionDescription = String(data.conditionDescription)
        if (data.presence !== undefined && !isNaN(Number(data.presence))) presence = Number(data.presence)
        if (data.intensity !== undefined && !isNaN(Number(data.intensity))) intensity = Number(data.intensity)
        if (data.opacity !== undefined && !isNaN(Number(data.opacity))) effectOpacity = Number(data.opacity)
        if (data.speed !== undefined && !isNaN(Number(data.speed))) speed = Number(data.speed)
      }
    } catch (e) {}
  }

  function saveSettings() {
    var state = {
      "mode": mode,
      "lastManualMode": lastManualMode,
      "effective": mode === "auto" ? autoCondition : mode,
      "autoCondition": autoCondition,
      "conditionDescription": conditionDescription,
      "presence": presence,
      "intensity": intensity,
      "opacity": effectOpacity,
      "speed": speed
    }
    saveProc.command = ["bash", "-c", "mkdir -p \"$(dirname \"" + settingsFile + "\")\" && cat > \"" + settingsFile + "\" << 'EOF'\n" + JSON.stringify(state, null, 2) + "\nEOF\n"]
    saveProc.running = true
  }

  Process { id: saveProc }

  property FileView fileView: FileView {
    path: root.settingsFile
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("{}")
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.weatherIcon()
    tooltipText: "Weather Effect: " + root.mode + " (" + Math.round(root.intensity * 100) + "%)"
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.setMode(root.mode === "auto" ? (root.lastManualMode || "rain") : "auto")
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // Header: icon + title + status subtitle
        Row {
          spacing: Style.space(12)
          width: parent.width

          Text {
            text: root.weatherIcon()
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.display
            color: root.bar ? root.bar.foreground : Color.foreground
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Weather Effect"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: root.statusSubtitle()
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.pixelSize: Style.font.caption
            }
          }
        }

        PanelSeparator { width: parent.width }

        // Presets
        PanelSectionHeader { text: "PRESET EFFECT" }

        Grid {
          columns: 3
          spacing: Style.space(6)
          width: parent.width

          Button {
            width: (parent.width - Style.space(12)) / 3
            iconText: "󰖐"
            text: "Auto"
            selected: root.mode === "auto"
            onClicked: root.setMode("auto")
          }

          Button {
            width: (parent.width - Style.space(12)) / 3
            iconText: ""
            text: "Rain"
            selected: root.mode === "rain"
            onClicked: root.setMode("rain")
          }

          Button {
            width: (parent.width - Style.space(12)) / 3
            iconText: ""
            text: "Storm"
            selected: root.mode === "thunderstorm"
            onClicked: root.setMode("thunderstorm")
          }

          Button {
            width: (parent.width - Style.space(12)) / 3
            iconText: ""
            text: "Snow"
            selected: root.mode === "snow"
            onClicked: root.setMode("snow")
          }

          Button {
            width: (parent.width - Style.space(12)) / 3
            iconText: ""
            text: "Fog"
            selected: root.mode === "fog"
            onClicked: root.setMode("fog")
          }

          Button {
            width: (parent.width - Style.space(12)) / 3
            iconText: ""
            text: "Sun"
            selected: root.mode === "sun"
            onClicked: root.setMode("sun")
          }
        }

        Button {
          width: parent.width
          iconText: "󰖪"
          text: "Off (Disable Effects)"
          selected: root.mode === "off"
          onClicked: root.setMode("off")
        }

        PanelSeparator { width: parent.width }

        // Sliders
        PanelSectionHeader { text: "PRESENCE, INTENSITY & SPEED" }

        // Slider 1: Presence (Subtle ↔ Prominent)
        Column {
          width: parent.width
          spacing: Style.space(4)

          Item {
            width: parent.width
            height: presenceLabel.implicitHeight

            Text {
              id: presenceLabel
              anchors.left: parent.left
              text: "Presence (Subtlety)"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.pixelSize: Style.font.body
            }

            Text {
              anchors.right: parent.right
              text: Math.round((presenceSlider.dragging ? presenceSlider.liveValue : root.presence) * 100) + "%"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.pixelSize: Style.font.body
            }
          }

          PanelSlider {
            id: presenceSlider
            bar: root.bar
            width: parent.width
            minimum: 0.05
            maximum: 1.0
            step: 0.05
            value: root.presence
            onMoved: function(v) { root.setPresence(v) }
            onReleased: function(v) { root.setPresence(v) }
          }
        }

        // Slider 2: Intensity / Density
        Column {
          width: parent.width
          spacing: Style.space(4)

          Item {
            width: parent.width
            height: intensityLabel.implicitHeight

            Text {
              id: intensityLabel
              anchors.left: parent.left
              text: "Intensity (Density)"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.pixelSize: Style.font.body
            }

            Text {
              anchors.right: parent.right
              text: Math.round((intensitySlider.dragging ? intensitySlider.liveValue : root.intensity) * 100) + "%"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.pixelSize: Style.font.body
            }
          }

          PanelSlider {
            id: intensitySlider
            bar: root.bar
            width: parent.width
            minimum: 0.05
            maximum: 1.0
            step: 0.05
            value: root.intensity
            onMoved: function(v) { root.setIntensity(v) }
            onReleased: function(v) { root.setIntensity(v) }
          }
        }

        // Slider 2: Opacity
        Column {
          width: parent.width
          spacing: Style.space(4)

          Item {
            width: parent.width
            height: opacityLabel.implicitHeight

            Text {
              id: opacityLabel
              anchors.left: parent.left
              text: "Visibility / Opacity"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.pixelSize: Style.font.body
            }

            Text {
              anchors.right: parent.right
              text: Math.round((opacitySlider.dragging ? opacitySlider.liveValue : root.effectOpacity) * 100) + "%"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.pixelSize: Style.font.body
            }
          }

          PanelSlider {
            id: opacitySlider
            bar: root.bar
            width: parent.width
            minimum: 0.05
            maximum: 0.80
            step: 0.05
            value: root.effectOpacity
            onMoved: function(v) { root.setOpacity(v) }
            onReleased: function(v) { root.setOpacity(v) }
          }
        }

        // Slider 3: Speed
        Column {
          width: parent.width
          spacing: Style.space(4)

          Item {
            width: parent.width
            height: speedLabel.implicitHeight

            Text {
              id: speedLabel
              anchors.left: parent.left
              text: "Animation Speed"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.pixelSize: Style.font.body
            }

            Text {
              anchors.right: parent.right
              text: Math.round((speedSlider.dragging ? speedSlider.liveValue : root.speed) * 100) + "%"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.pixelSize: Style.font.body
            }
          }

          PanelSlider {
            id: speedSlider
            bar: root.bar
            width: parent.width
            minimum: 0.20
            maximum: 1.20
            step: 0.05
            value: root.speed
            onMoved: function(v) { root.setSpeed(v) }
            onReleased: function(v) { root.setSpeed(v) }
          }
        }
      }
    }
  }
}
