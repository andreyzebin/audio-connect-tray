# audio-connect-tray

## Development
### Run from source
```bash
./gradlew test
./gradlew app:run --args='list bluetooth'

INFO  org.example.App                     - Device 4B:E4:89:A0:16:EE 4B-E4-89-A0-16-EE
INFO  org.example.App                     - Device 48:06:CB:B4:BB:93 9018 BT5.2 AUDIO
INFO  org.example.App                     - Device 44:5C:E9:AD:54:4D [TV] Samsung Q80 Series (65)
INFO  org.example.App                     - Device DD:70:1D:7F:5D:B2 Logi POP Mouse
INFO  org.example.App                     - Device 68:6C:E6:56:9D:F1 Xbox Wireless Controller
INFO  org.example.App                     - Device 00:02:5B:00:FF:00 9018 BT5.2 AUDIO


./gradlew app:run --args='use audio 00:02:5B:00:FF:00'
./gradlew app:run --args='audio on'
./gradlew app:run --args='audio off'

```

## Use
Requirements
- Operating system: Linux or macOs

### Install 
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/andreyzebin/audio-connect-tray/refs/heads/main/install.sh)"
```

### Manage Home Audio
```bash
tray audio on  # connect home audio
```
```bash
tray audio off # disconnect home audio
```