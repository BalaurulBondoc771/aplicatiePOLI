# Blackout Link

**Blackout Link** is an offline emergency communication app built with Flutter and Android native BLE technology.  
It allows nearby devices to communicate without internet, mobile networks, or external infrastructure.

The app is designed for critical situations such as blackouts, natural disasters, war aftermath, hiking accidents, rural isolation, and any environment where normal communication fails.

## Core Features

- Offline messaging using Bluetooth Low Energy
- SOS alerts with location
- Quick status broadcasts:
  - I AM SAFE
  - NEED HELP
  - ON MY WAY
  - LOW BATTERY
- Offline map support with POIs
- Battery-saving modes for extended emergency runtime
- Local message and SOS history
- Background discoverability
- Device-to-device communication without internet

## Why Blackout Link?

When power, internet, and mobile networks fail, people still need a way to communicate.

Blackout Link helps users:
- contact nearby people
- request help
- confirm safety
- find important locations on offline maps
- preserve battery during emergencies

## Use Cases

- City-wide blackout
- Earthquakes and floods
- War or post-disaster areas
- Hiking / mountain rescue scenarios
- Remote areas with no signal
- Emergency team coordination

## Technology Stack

### Flutter / Dart
Used for:
- user interface
- app routes
- controllers and state management
- communication with native Android

### Android / Kotlin
Used for:
- Bluetooth Low Energy communication
- background services
- Room database
- location services
- permissions
- battery and power profiles

### Local Storage
- Room database for messages, peers, conversations, SOS history

### Offline Maps
- MBTiles map package
- Offline POIs
- Current / last-known location display

## Main Screens

### Dashboard
Displays system status, Bluetooth state, battery level, permissions, active peers, mesh range, and quick status actions.

### Chat
Allows users to discover nearby peers and exchange offline messages.

### SOS
Sends emergency alerts with location to nearby devices.

### Offline Map
Displays offline maps and important POIs such as hospitals, shelters, safe zones, and useful emergency locations.

### Power
Provides battery-saving options such as:
- Battery Saver
- Low Power Bluetooth
- Grayscale UI
- Critical Tasks Only

### Settings
Allows configuration of:
- display name
- quick status preset
- background discoverability
- emergency behavior profiles
- grayscale UI

## Native Communication

Flutter communicates with Android through:

### MethodChannels
- `blackout_link/chat`
- `blackout_link/mesh`
- `blackout_link/sos`
- `blackout_link/location`
- `blackout_link/permissions`
- `blackout_link/power`
- `blackout_link/system`

### EventChannels
- `blackout_link/chat/incoming`
- `blackout_link/chat/connection`
- `blackout_link/mesh/peers`
- `blackout_link/sos/state`
- `blackout_link/location/updates`
- `blackout_link/power/state`
- `blackout_link/system/status`

## BLE Communication

Blackout Link uses Bluetooth Low Energy for offline discovery and communication.

- Service UUID: `0000aa01-0000-1000-8000-00805f9b34fb`
- Message Characteristic UUID: `0000aa02-0000-1000-8000-00805f9b34fb`
- Devices advertise a custom marker: `BLC1`
- Only devices running Blackout Link are accepted as valid peers

## Emergency Philosophy

Blackout Link is built around one simple idea:

> We don’t build apps for when everything works.  
> We build them for when everything fails.

## Project Status

The app includes:
- BLE peer discovery
- offline messaging
- SOS alerts
- local persistence
- offline map support
- power-saving modes
- background communication support

Future improvements may include:
- multi-hop mesh routing
- stronger delivery acknowledgements
- larger message chunking
- extended POI datasets
- organization-level deployment tools

**Blackout Link — when communication matters most.**

