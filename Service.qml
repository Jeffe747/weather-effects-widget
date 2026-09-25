import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Particles

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string settingsFile: home + "/.local/state/omarchy/settings/weather-fx.json"

  // mode can be: "auto", "rain", "thunderstorm", "snow", "fog", "sun", "off"
  property string mode: "auto"
  property string lastManualMode: "rain"
  property string autoCondition: "off"
  property string conditionDescription: ""

  // Slider settings (calm, subtle defaults)
  property real presence: 0.35
  property real intensity: 0.30
  property real effectOpacity: 0.28
  property real speed: 0.50

  readonly property string effectiveEffect: mode === "auto" ? autoCondition : mode
  readonly property bool isRunning: effectiveEffect !== "off" && effectiveEffect !== ""

  function setMode(newMode) {
    newMode = String(newMode || "").trim().toLowerCase()
    if (!newMode) return
    if (newMode === "toggle-live" || newMode === "toggle_live") {
      toggleLive()
      return
    }
    if (newMode !== "auto" && newMode !== "off") {
      lastManualMode = newMode
    }
    mode = newMode
    saveState()
    if (mode === "auto") {
      fetchWeather()
    }
  }

  function setPresence(val) {
    var n = Number(val)
    if (!isNaN(n)) {
      presence = Math.max(0.05, Math.min(1.0, n))
      saveState()
    }
  }

  function setIntensity(val) {
    var n = Number(val)
    if (!isNaN(n)) {
      intensity = Math.max(0.05, Math.min(1.0, n))
      saveState()
    }
  }

  function setOpacity(val) {
    var n = Number(val)
    if (!isNaN(n)) {
      effectOpacity = Math.max(0.05, Math.min(0.80, n))
      saveState()
    }
  }

  function setSpeed(val) {
    var n = Number(val)
    if (!isNaN(n)) {
      speed = Math.max(0.20, Math.min(1.20, n))
      saveState()
    }
  }

  function toggleLive() {
    if (mode === "auto") {
      setMode(lastManualMode || "rain")
    } else {
      setMode("auto")
    }
  }

  function toggle() {
    if (isRunning) {
      setMode("off")
    } else {
      setMode(mode === "off" ? (lastManualMode || "auto") : "auto")
    }
  }

  function fetchWeather() {
    if (!weatherProc.running) {
      weatherProc.running = true
    }
  }

  function statusString() {
    if (mode === "auto") {
      var desc = conditionDescription ? " (" + conditionDescription + " -> " + autoCondition + ")" : " (" + autoCondition + ")"
      return "auto" + desc
    }
    return mode
  }

  function saveState() {
    var state = {
      "mode": mode,
      "lastManualMode": lastManualMode,
      "effective": effectiveEffect,
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

  function loadSettings(raw) {
    try {
      var data = JSON.parse(raw || "{}")
      if (data && typeof data === "object") {
        if (data.mode !== undefined) mode = String(data.mode)
        if (data.lastManualMode !== undefined) lastManualMode = String(data.lastManualMode)
        if (data.autoCondition !== undefined) autoCondition = String(data.autoCondition)
        if (data.conditionDescription !== undefined) conditionDescription = String(data.conditionDescription)
        if (data.presence !== undefined && !isNaN(Number(data.presence))) presence = Number(data.presence)
        if (data.intensity !== undefined && !isNaN(Number(data.intensity))) intensity = Number(data.intensity)
        if (data.opacity !== undefined && !isNaN(Number(data.opacity))) effectOpacity = Number(data.opacity)
        if (data.speed !== undefined && !isNaN(Number(data.speed))) speed = Number(data.speed)
      }
    } catch (e) {}
  }

  Process { id: saveProc }

  // Watch for external changes from BarWidget or CLI
  property FileView settingsWatcher: FileView {
    path: root.settingsFile
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("{}")
  }

  // Weather query process
  Process {
    id: weatherProc
    command: ["curl", "-fsS", "--max-time", "5", "https://wttr.in/?format=j1"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var res = JSON.parse(text || "{}")
          if (res && res.current_condition && res.current_condition.length > 0) {
            var curr = res.current_condition[0]
            var code = parseInt(curr.weatherCode, 10)
            var desc = (curr.weatherDesc && curr.weatherDesc[0] && curr.weatherDesc[0].value) ? curr.weatherDesc[0].value.trim() : ""
            root.conditionDescription = desc

            // Map wttr.in WMO weatherCode to distinct effects:
            if ([200, 386, 389, 392, 395].indexOf(code) !== -1) {
              root.autoCondition = "thunderstorm"
            } else if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359].indexOf(code) !== -1) {
              root.autoCondition = "rain"
            } else if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].indexOf(code) !== -1) {
              root.autoCondition = "snow"
            } else if ([143, 248, 260].indexOf(code) !== -1) {
              root.autoCondition = "fog"
            } else if ([113, 116].indexOf(code) !== -1) {
              root.autoCondition = "sun"
            } else {
              root.autoCondition = "off"
            }
            root.saveState()
          }
        } catch (e) {}
      }
    }
  }

  // Periodic weather update every 15 minutes in auto mode
  Timer {
    interval: 900000
    running: root.mode === "auto"
    repeat: true
    onTriggered: root.fetchWeather()
  }

  Component.onCompleted: {
    if (root.mode === "auto") root.fetchWeather()
  }

  // Dynamic storm squall gust surge (pulses wind intensity and angle)
  property real stormGust: 1.0
  SequentialAnimation {
    running: root.isRunning && root.effectiveEffect === "thunderstorm"
    loops: Animation.Infinite
    PauseAnimation { duration: 4000 }
    NumberAnimation { target: root; property: "stormGust"; to: 1.50; duration: 1500; easing.type: Easing.InOutQuad }
    PauseAnimation { duration: 1800 }
    NumberAnimation { target: root; property: "stormGust"; to: 0.95; duration: 2200; easing.type: Easing.InOutQuad }
    PauseAnimation { duration: 2000 }
  }

  // Render on each screen
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: weatherPanel
      required property var modelData
      screen: modelData

      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      visible: root.isRunning

      // Layer.Bottom puts this behind all windows and on top of the wallpaper!
      WlrLayershell.namespace: "omarchy-weather-fx"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      // Empty mask makes the surface completely click-through
      mask: Region {}

      // Tactical screen-rumble offset during thunder
      property real rumbleX: 0
      property real rumbleY: 0

      Item {
        id: sceneContainer
        width: modelData.width
        height: modelData.height
        x: weatherPanel.rumbleX
        y: weatherPanel.rumbleY

        ParticleSystem {
          id: weatherSys
          running: weatherPanel.visible
        }

        // =============================================================
        // 1. RAIN: Staircase Pixel Drops + Bottom Ground Splashes
        // =============================================================
        Emitter {
          system: weatherSys
          group: "rainDrop"
          enabled: root.effectiveEffect === "rain"
          width: modelData.width
          height: 1
          x: 0
          y: -30
          size: Math.max(3, Math.round(10 * root.presence))
          emitRate: Math.max(8, Math.round(55 * root.intensity * 2.2))
          lifeSpan: Math.max(800, Math.round(2200 / Math.max(0.3, root.speed)))
          velocity: PointDirection {
            y: Math.round(650 * root.speed * 1.4)
            yVariation: Math.round(50 * root.speed)
            x: Math.round(-85 * root.speed)
            xVariation: 15
          }
        }

        ImageParticle {
          system: weatherSys
          groups: ["rainDrop"]
          source: Qt.resolvedUrl("assets/rain_drop.png")
          alpha: Math.max(0.04, Math.min(0.95, root.effectOpacity * (0.35 + 0.65 * root.presence) * 1.1))
          entryEffect: ImageParticle.None
        }

        // Rain Ground Impact Splashes (pop up along bottom edge!)
        Emitter {
          system: weatherSys
          group: "rainSplash"
          enabled: root.effectiveEffect === "rain"
          width: modelData.width
          height: 4
          x: 0
          y: modelData.height - 4
          size: Math.max(2, Math.round(4 * root.presence))
          emitRate: Math.max(4, Math.round(35 * root.intensity * 2.0))
          lifeSpan: 280
          velocity: PointDirection {
            y: -95
            yVariation: 40
            x: -25
            xVariation: 50
          }
          acceleration: PointDirection { y: 380 } // Gravity pulls splash back down
        }

        ImageParticle {
          system: weatherSys
          groups: ["rainSplash"]
          source: Qt.resolvedUrl("assets/splash_drop.png")
          alpha: Math.max(0.04, Math.min(0.90, root.effectOpacity * (0.35 + 0.65 * root.presence) * 1.3))
          entryEffect: ImageParticle.None
        }

        // =============================================================
        // 2. THUNDERSTORM: Driving Gale + Sweeping Wind Slices + Spray + Debris + Lightning
        // =============================================================
        Emitter {
          system: weatherSys
          group: "stormDrop"
          enabled: root.effectiveEffect === "thunderstorm"
          width: modelData.width + 300
          height: 1
          x: -50
          y: -40
          size: Math.max(4, Math.round(12 * root.presence))
          emitRate: Math.max(12, Math.round(100 * root.intensity * 2.5))
          lifeSpan: Math.max(600, Math.round(1700 / Math.max(0.3, root.speed)))
          velocity: PointDirection {
            y: Math.round(920 * root.speed * 1.5)
            yVariation: Math.round(70 * root.speed)
            x: Math.round(-320 * root.speed * root.stormGust) // Wind drives rain slant
            xVariation: 40
          }
        }

        ImageParticle {
          system: weatherSys
          groups: ["stormDrop"]
          source: Qt.resolvedUrl("assets/storm_drop.png")
          alpha: Math.max(0.05, Math.min(0.95, root.effectOpacity * (0.35 + 0.65 * root.presence) * 1.3))
          entryEffect: ImageParticle.None
        }

        // Layer A: Sweeping Gale Streaks (spans sky & right quadrant, long travel, smooth fade)
        Emitter {
          system: weatherSys
          group: "stormWind"
          enabled: root.effectiveEffect === "thunderstorm"
          width: modelData.width + 300
          height: modelData.height * 0.75
          x: -50
          y: -80
          size: Math.max(20, Math.round(52 * root.presence))
          emitRate: Math.max(4, Math.round(14 * root.intensity * root.stormGust))
          lifeSpan: Math.max(1400, Math.round(3000 / Math.max(0.3, root.speed)))
          velocity: PointDirection {
            x: Math.round(-850 * root.speed * root.stormGust)
            xVariation: Math.round(140 * root.speed)
            y: Math.round(380 * root.speed)
            yVariation: Math.round(60 * root.speed)
          }
        }

        ImageParticle {
          system: weatherSys
          groups: ["stormWind"]
          source: Qt.resolvedUrl("assets/storm_wind.png")
          alpha: Math.max(0.04, Math.min(0.50, root.effectOpacity * (0.30 + 0.70 * root.presence) * 0.85))
          entryEffect: ImageParticle.Fade
        }

        // Layer B: Aerosol Wind Spray (fine mist whipped across the screen in gusts)
        Emitter {
          system: weatherSys
          group: "stormSpray"
          enabled: root.effectiveEffect === "thunderstorm"
          width: modelData.width + 200
          height: modelData.height * 0.7
          x: 0
          y: -60
          size: Math.max(2, Math.round(3 * root.presence))
          emitRate: Math.max(8, Math.round(32 * root.intensity * root.stormGust))
          lifeSpan: Math.max(1200, Math.round(2400 / Math.max(0.3, root.speed)))
          velocity: PointDirection {
            x: Math.round(-720 * root.speed * root.stormGust)
            xVariation: Math.round(180 * root.speed)
            y: Math.round(440 * root.speed)
            yVariation: Math.round(90 * root.speed)
          }
        }

        ImageParticle {
          system: weatherSys
          groups: ["stormSpray"]
          source: Qt.resolvedUrl("assets/storm_spray.png")
          alpha: Math.max(0.03, Math.min(0.55, root.effectOpacity * (0.25 + 0.75 * root.presence) * 0.95))
          entryEffect: ImageParticle.Fade
        }

        // Layer C: Tumbling Storm Debris & Leaves (fluttering in gale turbulence)
        Emitter {
          system: weatherSys
          group: "stormDebris"
          enabled: root.effectiveEffect === "thunderstorm"
          width: modelData.width + 300
          height: modelData.height * 0.6
          x: 0
          y: -40
          size: Math.max(3, Math.round(5 * root.presence))
          emitRate: Math.max(1, Math.round(5 * root.intensity * root.stormGust))
          lifeSpan: Math.max(1800, Math.round(3800 / Math.max(0.3, root.speed)))
          velocity: PointDirection {
            x: Math.round(-620 * root.speed * root.stormGust)
            xVariation: Math.round(160 * root.speed)
            y: Math.round(340 * root.speed)
            yVariation: Math.round(80 * root.speed)
          }
        }

        Wander {
          system: weatherSys
          groups: ["stormDebris"]
          enabled: root.effectiveEffect === "thunderstorm"
          xVariance: 35
          yVariance: 30
          pace: 160 // violent wind flutter
        }

        ImageParticle {
          system: weatherSys
          groups: ["stormDebris"]
          source: Qt.resolvedUrl("assets/storm_debris.png")
          alpha: Math.max(0.06, Math.min(0.85, root.effectOpacity * (0.35 + 0.65 * root.presence) * 1.4))
          entryEffect: ImageParticle.Fade
          rotationVelocity: 180
          rotationVelocityVariation: 120
        }

        // Branching Jagged Pixel Lightning Bolt (Canvas)
        Canvas {
          id: lightningCanvas
          width: modelData.width
          height: modelData.height
          visible: root.effectiveEffect === "thunderstorm"
          opacity: 0

          property var mainSegments: []
          property var branchSegments1: []
          property var branchSegments2: []

          function strike() {
            var main = []
            var b1 = []
            var b2 = []
            var startX = width * (0.25 + Math.random() * 0.5)
            var curX = startX
            var curY = 0
            main.push({ x: curX, y: curY })

            var b1Start = Math.floor(height * 0.3)
            var b2Start = Math.floor(height * 0.55)
            var b1Forked = false
            var b2Forked = false

            while (curY < height) {
              curY += 26 + Math.floor(Math.random() * 34)
              curX += (Math.random() - 0.5) * 64
              // Snap to 4px grid for crisp retro pixel aesthetic!
              curX = Math.round(curX / 4) * 4
              curY = Math.round(curY / 4) * 4
              main.push({ x: Math.max(10, Math.min(width - 10, curX)), y: Math.min(height, curY) })

              // Fork branch 1
              if (!b1Forked && curY >= b1Start) {
                b1Forked = true
                var bx = curX, by = curY
                b1.push({ x: bx, y: by })
                for (var j = 0; j < 4; j++) {
                  bx += (Math.random() > 0.5 ? 28 : -28)
                  by += 20 + Math.floor(Math.random() * 24)
                  b1.push({ x: Math.round(bx / 4) * 4, y: Math.round(by / 4) * 4 })
                }
              }

              // Fork branch 2
              if (!b2Forked && curY >= b2Start) {
                b2Forked = true
                var bx2 = curX, by2 = curY
                b2.push({ x: bx2, y: by2 })
                for (var k = 0; k < 3; k++) {
                  bx2 += (Math.random() > 0.5 ? -32 : 32)
                  by2 += 22 + Math.floor(Math.random() * 20)
                  b2.push({ x: Math.round(bx2 / 4) * 4, y: Math.round(by2 / 4) * 4 })
                }
              }
            }
            mainSegments = main
            branchSegments1 = b1
            branchSegments2 = b2
            requestPaint()
            lightningAnim.restart()
          }

          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (!mainSegments || mainSegments.length < 2) return

            ctx.imageSmoothingEnabled = false

            // Draw branches first
            function drawBranch(branch, w, col) {
              if (!branch || branch.length < 2) return
              ctx.lineWidth = w
              ctx.strokeStyle = col
              ctx.beginPath()
              ctx.moveTo(branch[0].x, branch[0].y)
              for (var b = 1; b < branch.length; b++) ctx.lineTo(branch[b].x, branch[b].y)
              ctx.stroke()
            }

            drawBranch(branchSegments1, 2, "#90e4ff")
            drawBranch(branchSegments2, 2, "#90e4ff")

            // Main bolt: White core + cyan outline
            ctx.lineWidth = 5
            ctx.strokeStyle = "#80e0ff"
            ctx.beginPath()
            ctx.moveTo(mainSegments[0].x, mainSegments[0].y)
            for (var i = 1; i < mainSegments.length; i++) ctx.lineTo(mainSegments[i].x, mainSegments[i].y)
            ctx.stroke()

            ctx.lineWidth = 3
            ctx.strokeStyle = "#ffffff"
            ctx.stroke()
          }
        }

        // Sky flash during storm
        Rectangle {
          id: lightningBgFlash
          width: modelData.width
          height: modelData.height
          color: "#ffffff"
          opacity: 0
          visible: root.effectiveEffect === "thunderstorm"
        }

        // Thunderstorm lightning strike + tactile camera rumble
        SequentialAnimation {
          id: lightningAnim

          // Frame 1: Flash & rumble start
          ParallelAnimation {
            NumberAnimation { target: lightningCanvas; property: "opacity"; to: Math.min(1.0, 0.4 + 0.6 * root.presence); duration: 40 }
            NumberAnimation { target: lightningBgFlash; property: "opacity"; to: Math.min(0.18, root.effectOpacity * root.presence * 0.5); duration: 40 }
            ScriptAction { script: { weatherPanel.rumbleX = 3 * root.presence; weatherPanel.rumbleY = -2 * root.presence } }
          }
          // Frame 2: Dim & rumble jitter
          ParallelAnimation {
            NumberAnimation { target: lightningCanvas; property: "opacity"; to: 0.15 * root.presence; duration: 35 }
            NumberAnimation { target: lightningBgFlash; property: "opacity"; to: 0.02 * root.presence; duration: 35 }
            ScriptAction { script: { weatherPanel.rumbleX = -3 * root.presence; weatherPanel.rumbleY = 2 * root.presence } }
          }
          // Frame 3: Secondary pulse & settle
          ParallelAnimation {
            NumberAnimation { target: lightningCanvas; property: "opacity"; to: 0.90 * Math.min(1.0, 0.4 + 0.6 * root.presence); duration: 50 }
            NumberAnimation { target: lightningBgFlash; property: "opacity"; to: Math.min(0.12, root.effectOpacity * root.presence * 0.35); duration: 50 }
            ScriptAction { script: { weatherPanel.rumbleX = 1 * root.presence; weatherPanel.rumbleY = -1 * root.presence } }
          }
          // Frame 4: Fade to calm
          ParallelAnimation {
            NumberAnimation { target: lightningCanvas; property: "opacity"; to: 0; duration: 160 }
            NumberAnimation { target: lightningBgFlash; property: "opacity"; to: 0; duration: 200 }
            ScriptAction { script: { weatherPanel.rumbleX = 0; weatherPanel.rumbleY = 0 } }
          }
        }

        Timer {
          id: lightningStrikeTimer
          interval: 12000 + Math.random() * 16000
          running: weatherPanel.visible && root.effectiveEffect === "thunderstorm"
          repeat: true
          onTriggered: {
            lightningStrikeTimer.interval = 10000 + Math.random() * 20000
            lightningCanvas.strike()
          }
        }

        // =============================================================
        // 3. SNOW: Sine-Wave Meandering Flakes + Multi-Depth Stars & Pixels
        // =============================================================
        Wander {
          system: weatherSys
          groups: ["snowMicro", "snowMedium", "snowStar"]
          enabled: root.effectiveEffect === "snow"
          xVariance: 45
          yVariance: 10
          pace: 110 // Gentle horizontal sway!
        }

        // Layer A: Micro background flakes (1x1 pixel dots)
        Emitter {
          system: weatherSys
          group: "snowMicro"
          enabled: root.effectiveEffect === "snow"
          width: modelData.width
          height: 1
          x: 0
          y: -20
          size: Math.max(1, Math.round(2 * root.presence))
          emitRate: Math.max(6, Math.round(25 * root.intensity * 2.2))
          lifeSpan: Math.max(2500, Math.round(7500 / Math.max(0.3, root.speed)))
          velocity: PointDirection {
            y: Math.round(65 * root.speed)
            yVariation: 15
            x: Math.round(-12 * root.speed)
            xVariation: 20
          }
        }

        ImageParticle {
          system: weatherSys
          groups: ["snowMicro"]
          source: Qt.resolvedUrl("assets/snow_micro.png")
          alpha: Math.max(0.04, Math.min(0.70, root.effectOpacity * (0.30 + 0.70 * root.presence) * 1.3))
          entryEffect: ImageParticle.None
        }

        // Layer B: Medium flakes (2x2 sharp square flakes)
        Emitter {
          system: weatherSys
          group: "snowMedium"
          enabled: root.effectiveEffect === "snow"
          width: modelData.width
          height: 1
          x: 0
          y: -20
          size: Math.max(2, Math.round(4 * root.presence))
          emitRate: Math.max(4, Math.round(18 * root.intensity * 2.0))
          lifeSpan: Math.max(2000, Math.round(6000 / Math.max(0.3, root.speed)))
          velocity: PointDirection {
            y: Math.round(95 * root.speed)
            yVariation: 20
            x: Math.round(-16 * root.speed)
            xVariation: 25
          }
        }

        ImageParticle {
          system: weatherSys
          groups: ["snowMedium"]
          source: Qt.resolvedUrl("assets/snow_med.png")
          alpha: Math.max(0.05, Math.min(0.85, root.effectOpacity * (0.30 + 0.70 * root.presence) * 1.5))
          entryEffect: ImageParticle.None
        }

        // Layer C: Retro 8-bit star snowflakes (delicate 5x5 cross)
        Emitter {
          system: weatherSys
          group: "snowStar"
          enabled: root.effectiveEffect === "snow"
          width: modelData.width
          height: 1
          x: 0
          y: -20
          size: Math.max(3, Math.round(6 * root.presence))
          emitRate: Math.max(2, Math.round(8 * root.intensity * 1.8))
          lifeSpan: Math.max(1800, Math.round(5500 / Math.max(0.3, root.speed)))
          velocity: PointDirection {
            y: Math.round(120 * root.speed)
            yVariation: 25
            x: Math.round(-20 * root.speed)
            xVariation: 30
          }
        }

        ImageParticle {
          system: weatherSys
          groups: ["snowStar"]
          source: Qt.resolvedUrl("assets/snow_star.png")
          alpha: Math.max(0.06, Math.min(0.90, root.effectOpacity * (0.30 + 0.70 * root.presence) * 1.7))
          entryEffect: ImageParticle.None
        }

        // =============================================================
        // 4. FOG / MIST: Parallax Scrolling Pixel Cloud Banks (Zero falling particles!)
        // =============================================================
        Item {
          id: parallaxFogContainer
          width: modelData.width
          height: modelData.height
          visible: root.effectiveEffect === "fog"
          opacity: Math.max(0.03, Math.min(0.85, root.effectOpacity * (0.25 + 0.75 * root.presence) * 1.4))

          // Low Ground Fog Layer (hugging bottom of screen, scrolling left)
          Item {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 120
            clip: true

            Row {
              id: lowFogRow
              property real offset: 0
              x: -offset
              height: parent.height

              NumberAnimation on offset {
                from: 0; to: 960
                duration: Math.max(12000, Math.round(32000 / Math.max(0.3, root.speed)))
                loops: Animation.Infinite
                running: weatherPanel.visible && root.effectiveEffect === "fog"
              }

              Repeater {
                model: 4
                Item {
                  width: 960; height: 120

                  // Chunky stepped 16-bit cloud bank silhouette
                  Rectangle { x: 40; y: 20; width: 280; height: 24; color: "#9bb8cc"; antialiasing: false; opacity: 0.18 }
                  Rectangle { x: 20; y: 44; width: 340; height: 36; color: "#9bb8cc"; antialiasing: false; opacity: 0.24 }
                  Rectangle { x: 400; y: 15; width: 440; height: 32; color: "#9bb8cc"; antialiasing: false; opacity: 0.20 }
                  Rectangle { x: 360; y: 47; width: 520; height: 40; color: "#9bb8cc"; antialiasing: false; opacity: 0.28 }
                  // Solid bottom base
                  Rectangle { x: 0; y: 80; width: 960; height: 40; color: "#9bb8cc"; antialiasing: false; opacity: 0.35 }
                }
              }
            }
          }

          // Mid-Altitude Haze Layer (drifting in opposite direction, rightward)
          Item {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 90
            clip: true

            Row {
              id: midFogRow
              property real offset: 0
              x: offset - 960
              height: parent.height

              NumberAnimation on offset {
                from: 0; to: 960
                duration: Math.max(16000, Math.round(44000 / Math.max(0.3, root.speed)))
                loops: Animation.Infinite
                running: weatherPanel.visible && root.effectiveEffect === "fog"
              }

              Repeater {
                model: 4
                Item {
                  width: 960; height: 90
                  Rectangle { x: 80; y: 10; width: 380; height: 20; color: "#b8d0e0"; antialiasing: false; opacity: 0.14 }
                  Rectangle { x: 40; y: 30; width: 460; height: 28; color: "#b8d0e0"; antialiasing: false; opacity: 0.18 }
                  Rectangle { x: 550; y: 18; width: 320; height: 24; color: "#b8d0e0"; antialiasing: false; opacity: 0.15 }
                  Rectangle { x: 500; y: 42; width: 400; height: 30; color: "#b8d0e0"; antialiasing: false; opacity: 0.20 }
                }
              }
            }
          }
        }

        // =============================================================
        // 5. SUN / CLEAR: Warm Volumetric Pixel God Rays + Rising Golden Dust Motes
        // =============================================================
        Item {
          id: sunRaysContainer
          width: modelData.width
          height: modelData.height
          visible: root.effectiveEffect === "sun"
          opacity: Math.max(0.03, Math.min(0.85, root.effectOpacity * (0.25 + 0.75 * root.presence) * 1.5))

          // Diagonal Pixel God Rays from top-left corner
          Canvas {
            id: raysCanvas
            width: modelData.width
            height: modelData.height
            property real pulse: 0.85

            SequentialAnimation on pulse {
              loops: Animation.Infinite
              running: weatherPanel.visible && root.effectiveEffect === "sun"
              NumberAnimation { to: 1.15; duration: 4000; easing.type: Easing.InOutSine }
              NumberAnimation { to: 0.85; duration: 4000; easing.type: Easing.InOutSine }
            }

            onPulseChanged: requestPaint()

            onPaint: {
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              ctx.imageSmoothingEnabled = false

              // Draw stepped diagonal sunbeams
              var beams = [
                { startX: -80, widthTop: 90, endX: width * 0.45, widthBottom: 220, alpha: 0.14 },
                { startX: 60, widthTop: 120, endX: width * 0.70, widthBottom: 260, alpha: 0.18 },
                { startX: 240, widthTop: 80, endX: width * 0.95, widthBottom: 200, alpha: 0.12 }
              ]

              for (var b = 0; b < beams.length; b++) {
                var bm = beams[b]
                ctx.fillStyle = "rgba(255, 246, 210, " + (bm.alpha * pulse).toFixed(3) + ")"
                ctx.beginPath()
                ctx.moveTo(bm.startX, 0)
                ctx.lineTo(bm.startX + bm.widthTop, 0)
                ctx.lineTo(bm.endX + bm.widthBottom, height)
                ctx.lineTo(bm.endX, height)
                ctx.closePath()
                ctx.fill()
              }
            }
          }

          // Rising Golden Dust Motes (float UPWARDS through the beams!)
          Emitter {
            system: weatherSys
            group: "sunMote"
            enabled: root.effectiveEffect === "sun"
            width: modelData.width
            height: 10
            x: 0
            y: modelData.height - 10
            size: Math.max(2, Math.round(4 * root.presence))
            emitRate: Math.max(4, Math.round(18 * root.intensity * 2.0))
            lifeSpan: Math.max(3000, Math.round(9000 / Math.max(0.3, root.speed)))
            velocity: PointDirection {
              y: Math.round(-45 * root.speed) // Floating UPWARDS!
              yVariation: 15
              x: Math.round(18 * root.speed)
              xVariation: 20
            }
          }

          ImageParticle {
            system: weatherSys
            groups: ["sunMote"]
            source: Qt.resolvedUrl("assets/sun_mote.png")
            alpha: Math.max(0.06, Math.min(0.95, root.effectOpacity * (0.35 + 0.65 * root.presence) * 1.8))
            entryEffect: ImageParticle.None
          }
        }

      }
    }
  }

  // Shell IPC Interface
  IpcHandler {
    target: "weather_fx"

    function setMode(m: string): void {
      root.setMode(m)
    }

    function setPresence(val: real): void {
      root.setPresence(val)
    }

    function setIntensity(val: real): void {
      root.setIntensity(val)
    }

    function setOpacity(val: real): void {
      root.setOpacity(val)
    }

    function setSpeed(val: real): void {
      root.setSpeed(val)
    }

    function toggleLive(): void {
      root.toggleLive()
    }

    function toggle(): void {
      root.toggle()
    }

    function refresh(): void {
      root.fetchWeather()
    }

    function getMode(): string {
      return root.mode
    }

    function getPresence(): real {
      return root.presence
    }

    function getEffective(): string {
      return root.effectiveEffect
    }

    function getStatus(): string {
      return root.statusString()
    }
  }
}
