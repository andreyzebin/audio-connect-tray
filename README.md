# audio-connect-tray

List bluetooth devices and choose audio for a quick toggle.

## Development
### Run from source
```bash
./gradlew test
./gradlew app:run --args='--version'
./gradlew app:run --args='audio off'
```

## Use
Requirements
- Operating system: Linux or macOs

### Install 
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/andreyzebin/audio-connect-tray/refs/heads/main/install.sh)"
```

### Toggle Audio Connection

List radio available devices.
```bash
tray list bluetooth # list available bluetooth devices
```
List of devices returned. Find your home audio.
```
INFO  org.example.App                     - Device 4B:E4:89:A0:16:EE 4B-E4-89-A0-16-EE
INFO  org.example.App                     - Device 48:06:CB:B4:BB:93 9018 BT5.2 AUDIO
INFO  org.example.App                     - Device 44:5C:E9:AD:54:4D [TV] Samsung Q80 Series (65)
INFO  org.example.App                     - Device DD:70:1D:7F:5D:B2 Logi POP Mouse
INFO  org.example.App                     - Device 68:6C:E6:56:9D:F1 Xbox Wireless Controller
INFO  org.example.App                     - Device 00:02:5B:00:FF:00 9018 BT5.2 AUDIO
```
Set and toggle connection.
```bash
tray use audio 00:02:5B:00:FF:00  # specify one as a home audio
tray audio on                     # connect home audio
tray audio off                    # disconnect home audio
```

Bluetoothctl cheatsheet
```
sudo bluetoothctl
[bluetooth]# list
[bluetooth]# select <MAC-address>
[bluetooth]# power on
[bluetooth]# scan on
[bluetooth]# scan off
[bluetooth]# devices
```
Also: https://walkonthebyteside.com/blog/2023-02-15-bluetooth-monitoring-command-linux/
