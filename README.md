# Omarchy Weather FX Widget & Service

A retro pixel-game style ambient weather effect system for **Omarchy** (Hyprland + Quickshell).

Renders animated, weather-reactive atmospheric effects **behind open windows and on top of your wallpaper**, with a companion navbar widget featuring live controls and presets.

---

## Features

- **Wallpaper Overlay (`WlrLayer.Bottom`)**:
  - Sits directly between your wallpaper and active windows.
  - Transparent and completely click-through (`mask: Region {}`), with zero mouse interception or window interference.
- **Hardware-Accelerated 60 FPS Performance**:
  - Built with GPU-accelerated batched `ImageParticle` rendering.
  - Zero CPU item-sync jank or micro-stutters.
- **Handcrafted Retro Pixel-Art Weather Systems**:
  - **🌧️ Rain**: Stepped diagonal pixel drops with ground impact puddle splashes.
  - **⚡ Thunderstorm**: Driving wind-blown gale, multi-layer sweeping wind slices, aerosol mist spray, tumbling leaves (`rotationVelocity: 180°/s`), branching pixel lightning bolts, and subtle screen rumble.
  - **❄️ Snow**: Multi-depth drifting snow with sine-wave horizontal wind sways and delicate retro 5×5 star snowflakes.
  - **🌫️ Fog / Mist**: Multi-layer horizontal parallax scrolling cloud banks.
  - **☀️ Sun / Clear**: Warm volumetric pixel god rays with rising golden dust motes.
- **Real-Time Presence & Intensity Sliders**:
  - **Presence (Subtlety ↔ Prominence)**: Dial in how noticeable or anonymous the effect feels. Low presence shrinks particles to fine 1–2px specks and softens contrast into the background.
  - **Intensity (Density)**: Controls the volume of particles on screen.
  - **Visibility (Opacity)**: Modulates maximum alpha transparency.
  - **Animation Speed**: Adjusts falling and drifting velocity.
- **Live Sync & Manual Picker**:
  - Automatically queries local weather via `wttr.in` every 15 minutes.
  - Toggle between live sync and manual overrides anytime.

---

## Directory Structure

```text
Omarchy/Widgets/weather-effects-widget/
├── manifest.json            # Omarchy plugin manifest (service + bar-widget)
├── BarWidget.qml            # Top bar widget with popup panel & live sliders
├── Service.qml              # Background layer-shell surface with particle effects
├── assets/                  # Lossless 8-bit retro pixel-art sprite textures
│   ├── rain_drop.png        # 2px-wide stepped diagonal raindrop (10x10)
│   ├── splash_drop.png      # 2x2 ground splash pixel (4x4)
│   ├── storm_drop.png       # Driving gale streak (12x12)
│   ├── storm_wind.png       # 64px tapered aerodynamic wind streak (64x64)
│   ├── storm_spray.png      # Aerosol wind mist droplet (4x4)
│   ├── storm_debris.png     # Tumbling storm leaf/fleck (4x4)
│   ├── snow_micro.png       # 1x1 micro background flake (2x2)
│   ├── snow_med.png         # 2x2 square snowflake (4x4)
│   ├── snow_star.png        # 5x5 delicate retro cross snowflake (6x6)
│   └── sun_mote.png         # 2x2 rising golden dust mote (4x4)
├── scripts/
│   └── omarchy-weather-fx   # Full-featured helper CLI
├── install.sh               # Quick installer script
└── README.md
```

---

## Installation

Run the installer from this directory:

```bash
./install.sh
```

Or manually link the plugin:

```bash
mkdir -p ~/.config/omarchy/plugins
ln -sf "$(pwd)" ~/.config/omarchy/plugins/jaj.weather-fx
cp scripts/omarchy-weather-fx ~/.local/bin/
chmod +x ~/.local/bin/omarchy-weather-fx
```

### Adding to the Top Bar

Edit `~/.config/omarchy/shell.json` and add `"jaj.weather-fx"` to your desired bar section (e.g. `center`):

```json
{
  "center": [
    "omarchy.weather",
    "jaj.weather-fx",
    "omarchy.clock"
  ]
}
```

Restart the shell to apply:

```bash
omarchy restart shell
```

---

## Usage

### 1. Top Bar Widget
- **Left-Click**: Open the control panel with weather presets and real-time sliders.
- **Right-Click**: Quick-toggle between Live Weather Sync and manual mode.

### 2. CLI Helper (`omarchy-weather-fx`)
```bash
omarchy-weather-fx status               # Show active mode and slider levels
omarchy-weather-fx set rain             # Switch to Rain preset
omarchy-weather-fx set thunderstorm     # Switch to Thunderstorm
omarchy-weather-fx set snow             # Switch to Snow
omarchy-weather-fx set fog              # Switch to Fog/Mist
omarchy-weather-fx set sun              # Switch to Sun/Clear
omarchy-weather-fx set auto             # Sync with real local weather
omarchy-weather-fx toggle               # Quick toggle effects on/off

# Adjusting sliders (accepts 0-100% or 0.0-1.0):
omarchy-weather-fx presence 25          # Set presence/subtlety to 25% (quiet)
omarchy-weather-fx intensity 40         # Set density to 40%
omarchy-weather-fx opacity 25           # Set opacity to 25%
omarchy-weather-fx speed 50             # Set speed to 50%
```

### 3. Keybinding
Add to `~/.config/hypr/bindings.lua`:
```lua
{ "SUPER ALT", "W", "spawn", "omarchy-weather-fx widget" },
```
