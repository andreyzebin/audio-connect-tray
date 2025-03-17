# audio-connect-tray

## Development
### Run from source
```bash
./gradlew test
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