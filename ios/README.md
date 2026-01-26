# Good Espresso - iOS App

A complete iOS application for controlling Decent espresso machines via Bluetooth. Features real-time monitoring, professional brewing profiles (including pulse-brew tea profiles), shot history, and advanced controls.

## Features

- **Bluetooth Control**: Connect and control your Decent DE1/DE1+/DE1PRO machine wirelessly
- **Real-time Monitoring**: Live pressure, flow, and temperature graphs during extraction
- **Professional Profiles**: 11 espresso profiles and 6 tea/herbal profiles
- **Pulse-Brew Tea**: Tea profiles that match Decent's pulsed brewing pattern (fill, steep, pulse cycles)
- **Shot History**: Track, rate, and analyze your brewing history
- **Dark Mode**: Beautiful dark interface optimized for any lighting

## Requirements

- iOS 16.0 or later
- iPhone or iPad with Bluetooth LE support
- Decent espresso machine (DE1, DE1+, or DE1PRO)

## Deployment Instructions

### Option 1: Deploy from Windows using a Cloud Mac Service (Easiest)

Since iOS apps require macOS and Xcode to build, the easiest way to deploy from Windows is using a cloud Mac service:

#### Using MacStadium, MacinCloud, or AWS EC2 Mac

1. **Sign up for a cloud Mac service**:
   - [MacStadium](https://www.macstadium.com/) - Professional Mac hosting
   - [MacinCloud](https://www.macincloud.com/) - Pay-as-you-go Mac access
   - [AWS EC2 Mac](https://aws.amazon.com/ec2/instance-types/mac/) - Amazon cloud Mac

2. **Connect to the cloud Mac via Remote Desktop**

3. **Install Xcode** from the Mac App Store (if not pre-installed)

4. **Transfer the project**:
   ```bash
   # Clone the repository
   git clone <your-repo-url>
   cd deepdoopdop/ios
   ```

5. **Open in Xcode**:
   ```bash
   open GoodEspresso.xcodeproj
   ```

6. **Configure signing**:
   - Open Xcode
   - Select the project in the navigator
   - Go to "Signing & Capabilities"
   - Sign in with your Apple ID
   - Select your development team
   - Let Xcode manage signing automatically

7. **Build and deploy**:
   - Connect your iPhone via USB (or use WiFi deployment)
   - Select your device in Xcode
   - Press Cmd+R or click the Run button

### Option 2: Deploy using GitHub Actions (Automated CI/CD)

Set up automated builds using GitHub Actions with a macOS runner:

1. **Create `.github/workflows/ios-build.yml`**:
   ```yaml
   name: iOS Build

   on:
     push:
       branches: [main]
     pull_request:
       branches: [main]

   jobs:
     build:
       runs-on: macos-14
       steps:
         - uses: actions/checkout@v4

         - name: Select Xcode
           run: sudo xcode-select -s /Applications/Xcode_15.2.app

         - name: Build
           run: |
             cd ios
             xcodebuild -project GoodEspresso.xcodeproj \
               -scheme GoodEspresso \
               -destination 'platform=iOS Simulator,name=iPhone 15' \
               build
   ```

2. **For TestFlight deployment**, add certificates and provisioning profiles as GitHub secrets

### Option 3: Deploy from a Mac (Direct)

If you have access to a Mac:

1. **Install Xcode** from the Mac App Store

2. **Open the project**:
   ```bash
   cd ios
   open GoodEspresso.xcodeproj
   ```

3. **Configure your Apple Developer account**:
   - Xcode > Settings > Accounts
   - Add your Apple ID
   - Download certificates

4. **Select your development team**:
   - Click on the project in the navigator
   - Select the "GoodEspresso" target
   - Go to "Signing & Capabilities"
   - Select your team

5. **Connect your iPhone and run**:
   - Connect iPhone via USB cable
   - Trust the computer on your iPhone if prompted
   - Select your device from the device dropdown
   - Click Run (Cmd+R)

### Option 4: TestFlight Distribution

For distributing to multiple devices or beta testing:

1. **Create an App Store Connect account** at https://appstoreconnect.apple.com

2. **Create a new app**:
   - Bundle ID: `com.goodespresso.app`
   - Name: Good Espresso

3. **Archive and upload**:
   ```bash
   # In Xcode: Product > Archive
   # Then: Distribute App > App Store Connect > Upload
   ```

4. **Add testers** in App Store Connect and send invites

### Option 5: Ad-Hoc Distribution (No Mac Required - Limited)

Using third-party services like [Codemagic](https://codemagic.io/), [Bitrise](https://bitrise.io/), or [Expo EAS](https://expo.dev/eas):

1. Sign up for the service
2. Connect your GitHub repository
3. Configure iOS code signing (requires Apple Developer account)
4. Build and download the IPA file
5. Install via Apple Configurator or TestFlight

## Project Structure

```
ios/
├── GoodEspresso.xcodeproj/     # Xcode project file
├── GoodEspresso/
│   ├── GoodEspressoApp.swift   # App entry point
│   ├── ContentView.swift       # Main tab navigation
│   ├── Info.plist              # App configuration
│   ├── Assets.xcassets/        # App icons and colors
│   ├── Models/
│   │   ├── Models.swift        # Data models (Recipe, ShotRecord, etc.)
│   │   └── MachineStore.swift  # Observable state store
│   ├── Views/
│   │   ├── HomeView.swift      # Dashboard
│   │   ├── ConnectionView.swift # Bluetooth connection
│   │   ├── ProfilesView.swift  # Profile browser
│   │   ├── ProfileDetailView.swift # Profile details
│   │   ├── ControlView.swift   # Machine controls
│   │   ├── HistoryView.swift   # Shot history
│   │   ├── SettingsView.swift  # App settings
│   │   ├── ShotChartView.swift # Extraction charts
│   │   └── LegalView.swift     # Legal disclaimers
│   ├── Services/
│   │   └── BluetoothService.swift # CoreBluetooth implementation
│   └── Data/
│       └── ProfilesData.swift  # Pre-built profiles
└── README.md                   # This file
```

## Included Profiles

### Espresso Profiles (11)
- E61 Classic
- E61 High Temperature
- Lever Machine - Blooming
- Turbo Shot
- Advanced Pressure Profile
- Ristretto
- Slayer Style
- Allonge
- Dark Roast - Low Temperature
- Light Roast - Extended
- Flow Profile - Adaptive

### Tea Profiles (6) - Pulse Brewing
All tea profiles use Decent-style pulse brewing:
1. Initial basket fill
2. Pressure ramp to open valve
3. Repeated steep/pulse cycles
4. Final drain

- Green Tea - Pulse Brew (78°C)
- Black Tea - Pulse Brew (90°C)
- White Tea - Pulse Brew (73°C)
- Oolong Tea - Pulse Brew (85°C)
- Pu-erh Tea - Pulse Brew (95°C)
- Herbal Tisane - Pulse Brew (95°C)

## Legal Disclaimers

**IMPORTANT**: Good Espresso is NOT affiliated with, endorsed by, or officially connected to Decent Espresso. This is an independent, open-source project.

- Use at your own risk
- The developers are not liable for any damages or injuries
- Espresso machines operate at high temperatures and pressures
- Always follow manufacturer safety guidelines
- This app does not replace the official Decent Espresso app

See the full legal disclaimers in the app's Legal section.

## Privacy

- No data is collected or transmitted
- All brewing data is stored locally on your device
- Bluetooth communication is direct to your machine only

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - See LICENSE file for details.

## Acknowledgments

- Decent Espresso for creating amazing espresso machines
- The Decent espresso community for protocol documentation
- All contributors to this project
