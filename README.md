# Decent Espresso Control

> **⚠️ IMPORTANT DISCLAIMER:** This is an **unofficial**, **educational** project created for demonstration and learning purposes only. This application is **NOT affiliated with, endorsed by, or sponsored by Decent Espresso Ltd.** Use entirely at your own risk. See [Legal Disclaimer](#legal-disclaimer) below.

A fully-functional mobile web application for controlling Decent espresso machines via Bluetooth. This app provides comprehensive control over all machine functions, real-time data visualization, recipe management, shot history tracking, and advanced analytics.

## ⚠️ Known Issues & Limitations

### Browser Compatibility
**Web Bluetooth API has LIMITED support across browsers:**

✅ **Supported:**
- Chrome/Chromium 56+ on **Windows, Linux, macOS**
- Chrome on **Android**
- Edge 79+ on **Windows, Linux, macOS**

❌ **NOT Supported:**
- **Safari (all platforms)** - Safari does not implement Web Bluetooth API
- **iOS browsers (all)** - iOS does not allow Web Bluetooth, even in Chrome
- **Firefox** - No Web Bluetooth support
- **Mac Chrome** - May have limited/unreliable Bluetooth support depending on macOS version

**If you're on iOS or Safari:** You must use the official Decent Espresso app or switch to Android/Windows.

### Tea Brewing Profiles
Tea profiles may have **duration limitations** imposed by machine firmware:
- ⚠️ Tea profiles might run for **30 seconds maximum** regardless of configured duration
- This appears to be a firmware limitation for flow-only (pressure=0) profiles
- **Workaround**: Use manual mode or investigate firmware tea-specific modes
- Currently investigating the protocol for extended tea brewing cycles

### Real-Time Joystick Control
The joystick control interface for real-time pressure/flow adjustment:
- ⚠️ **May not function** without specific firmware support
- Uses Memory-Mapped Register (MMR) protocol which may not be enabled on all firmware versions
- If the joystick doesn't affect brewing, this is likely a firmware limitation
- Designed for compatible firmware versions that support live parameter updates

### Profile Transfer
- Profile encoding follows the official Decent protocol specification
- Enhanced debug logging has been added to diagnose transfer issues
- Check browser console for detailed frame encoding information

## 🚀 Quick Deploy

**Deploy your app in 2 minutes (FREE!):**

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/BlipBloopBlopBlingBoop/deepdoopdop)
[![Deploy to Netlify](https://www.netlify.com/img/deploy/button.svg)](https://app.netlify.com/start/deploy?repository=https://github.com/BlipBloopBlopBlingBoop/deepdoopdop)

**📖 Need help?** See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed deployment instructions.

---

## Features

### 🔌 Bluetooth Connectivity
- Web Bluetooth API integration for wireless connection
- Setup wizard with step-by-step instructions
- Comprehensive troubleshooting guide
- Connection status monitoring

### ☕ Machine Control
- Start/stop espresso extraction
- Steam mode control
- Flush and hot water dispensing
- Real-time temperature adjustment
- Sleep mode management

### 📊 Real-time Monitoring
- Live temperature, pressure, and flow readings
- Weight tracking during extraction
- Visual status indicators
- Machine state monitoring

### 📈 Data Visualization
- Real-time extraction plotting with Chart.js
- Multi-axis charts showing pressure, flow, temperature, and weight
- Historical shot analysis
- Interactive graphs with detailed tooltips

### 📖 Recipe Management
- Create and save custom shot profiles
- Profile step editor with granular control
- Favorite recipes
- Recipe usage tracking
- Search and filter recipes

### 📜 Shot History
- Complete shot database with IndexedDB
- Detailed shot metrics (duration, yield, ratio)
- Interactive 5-star rating system for shots
- Editable notes and tasting metadata
- Search and filter by rating, profile, or notes
- Shot detail view with extraction charts
- Automatic database persistence

### 💾 Data Management
- Export all data to JSON
- Import data from backups
- Local storage using IndexedDB
- Database statistics

### 📱 Mobile-First Design
- Responsive UI optimized for mobile devices
- Touch-friendly controls (minimum 44px tap targets)
- PWA-ready architecture
- Dark mode interface

### 🎭 Demo Mode
- Full simulation for testing without hardware
- Realistic espresso extraction with pressure profiling
- Temperature variations during brewing
- Steam mode operation
- Shot recording with realistic data points
- Perfect for learning and experimentation

## Technology Stack

- **Framework**: React 18 with TypeScript
- **Build Tool**: Vite
- **Styling**: Tailwind CSS
- **State Management**: Zustand
- **Charts**: Chart.js with react-chartjs-2
- **Database**: IndexedDB via idb
- **Routing**: React Router v6
- **Icons**: Lucide React

## Getting Started

### Prerequisites

- Node.js 18+ and npm
- A modern browser with Web Bluetooth API support:
  - Chrome/Edge (recommended)
  - Opera
  - On iOS: Bluefy browser app
- Decent espresso machine with Bluetooth enabled

### Installation

1. Install dependencies:
```bash
npm install
```

2. Start the development server:
```bash
npm run dev
```

3. Open your browser to `http://localhost:3000`

### Building for Production

```bash
npm run build
```

The built files will be in the `dist/` directory.

### Development

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm run lint` - Run ESLint
- `npm run type-check` - Check TypeScript types

## Browser Compatibility

### Web Bluetooth API Support

The app requires Web Bluetooth API support:
- ✅ Chrome 56+ (Desktop & Android)
- ✅ Edge 79+
- ✅ Opera 43+
- ⚠️ Safari - Not supported (use Bluefy on iOS)
- ❌ Firefox - Not supported

Check compatibility: https://caniuse.com/web-bluetooth

### Recommended Browsers

- **Desktop**: Chrome or Edge (latest version)
- **Android**: Chrome (latest version)
- **iOS**: Bluefy browser (Web Bluetooth support)

## Usage Guide

### Connecting to Your Machine

1. Power on your Decent espresso machine
2. Open the app and navigate to the Connect page
3. Click "Connect via Bluetooth"
4. Select your machine from the list (name starts with "DE1")
5. Wait for connection to establish

### Troubleshooting Connection Issues

If you can't connect:
- Ensure machine is fully powered on (not in sleep mode)
- Move closer to the machine (within 10 meters)
- Close any other apps connected to the machine
- Restart Bluetooth on your device
- Try a different browser
- Clear browser cache

### Using the Control Interface

1. **Dashboard**: View real-time machine status and metrics
2. **Control**: Start espresso, steam, flush, or adjust temperature
3. **Recipes**: Create, manage, and select shot profiles
4. **History**: Review past shots with detailed graphs and notes
5. **Settings**: Configure machine settings and manage data

### Creating a Recipe

1. Navigate to Recipes page
2. Click the "+" button
3. Enter recipe name and description
4. The app will create a default 3-step profile
5. (Future enhancement: Edit individual steps)

### Recording Shots

Shots are automatically recorded when you start an espresso extraction:
1. Select a recipe (or use Manual mode)
2. Go to Control page
3. Click "Start Espresso"
4. The shot will be recorded with real-time data
5. Find it in History after extraction completes

### Exporting/Importing Data

**Export**:
1. Go to Settings
2. Click "Export All Data"
3. Save the JSON file to your device

**Import**:
1. Go to Settings
2. Click "Import Data"
3. Select a previously exported JSON file

## Architecture

### Directory Structure

```
src/
├── components/       # Reusable UI components
│   ├── Layout.tsx
│   ├── Navigation.tsx
│   ├── StatusBar.tsx
│   └── ShotChart.tsx
├── pages/           # Page components
│   ├── ConnectionPage.tsx
│   ├── DashboardPage.tsx
│   ├── ControlPage.tsx
│   ├── RecipesPage.tsx
│   ├── HistoryPage.tsx
│   └── SettingsPage.tsx
├── services/        # Business logic services
│   ├── bluetoothService.ts
│   └── databaseService.ts
├── stores/          # Zustand state stores
│   ├── connectionStore.ts
│   ├── machineStore.ts
│   ├── recipeStore.ts
│   └── shotStore.ts
├── types/           # TypeScript type definitions
│   └── decent.ts
├── utils/           # Utility functions
│   └── formatters.ts
├── App.tsx         # Main app component
├── main.tsx        # Entry point
└── index.css       # Global styles
```

### State Management

The app uses Zustand for state management with four main stores:

- **connectionStore**: Bluetooth connection status
- **machineStore**: Machine state and settings
- **recipeStore**: Recipe management
- **shotStore**: Shot history and active recording

### Data Persistence

- IndexedDB for local storage (via idb library)
- Three object stores: recipes, shots, settings
- Automatic data synchronization

## Known Limitations

### Bluetooth Communication

- The current implementation uses placeholder Bluetooth UUIDs
- Actual Decent machine protocol implementation required
- Data parsing needs to match Decent's binary format

### Missing Features

- Profile step editor UI (currently uses default profile)
- Advanced shot profiling with pressure/flow ramping
- Real machine protocol integration
- Firmware updates via app
- Multiple machine support

## Future Enhancements

- [ ] Advanced profile editor with visual flow designer
- [ ] Cloud sync for recipes and data
- [ ] Social features (share recipes)
- [ ] Statistics and analytics dashboard
- [ ] Machine maintenance reminders
- [ ] Automatic shot photography
- [ ] Coffee bean inventory tracking
- [ ] Brew timer with notifications
- [ ] Multiple language support

## Contributing

This is an open-source educational project. Contributions are welcome for learning purposes!

## ⚠️ Legal Disclaimer

### Educational & Demonstration Purpose Only

This application is provided strictly for **educational and demonstration purposes**. It is a proof-of-concept project showcasing Web Bluetooth API integration and should **NOT** be considered production-ready software.

### Use at Your Own Risk

This software is provided **"AS IS"** without warranty of any kind, express or implied. By using this application, you acknowledge that:

- ✋ You use this software entirely at your own risk
- ⚠️ The developers assume **NO LIABILITY** for any damages, injuries, or losses
- 🔧 You are responsible for the safe operation of your espresso machine
- 📜 **NO WARRANTIES** are provided regarding functionality, safety, or reliability

### Intellectual Property Rights

**Decent Espresso®** and all related trademarks, logos, and intellectual property belong to **Decent Espresso Ltd.**

This project is an independent, unofficial implementation and is:
- ❌ **NOT affiliated with Decent Espresso Ltd.**
- ❌ **NOT endorsed by Decent Espresso Ltd.**
- ❌ **NOT sponsored by Decent Espresso Ltd.**

All original design, engineering, and proprietary elements of Decent Espresso machines remain the exclusive property of Decent Espresso Ltd. and its rightful owners.

### Safety Warning

**⚠️ CRITICAL:** Espresso machines operate at **high temperatures** (up to 165°C/330°F) and **high pressures** (up to 12 bar/174 psi).

Improper use can result in:
- 🔥 **Burns** from hot water, steam, or machine surfaces
- ⚡ **Equipment damage** or malfunction
- 💧 **Water damage** to surrounding areas
- ⚡ **Electrical hazards** if machine is improperly maintained

**Always:**
- Follow manufacturer safety guidelines
- Never leave your machine unattended during operation
- Keep children and pets away from operating machines
- Ensure proper ventilation and stable placement
- Regularly maintain and descale your machine

### No Official Support

This is a community/hobbyist project. The original equipment manufacturers and their official support channels are **NOT responsible** for issues arising from the use of this software.

### Privacy & Data

- All data is stored **locally** in your browser using IndexedDB
- **No data** is transmitted to external servers
- The developers make **no guarantees** about data persistence, privacy, or security
- You are responsible for backing up your own data

### Liability Waiver

By using this software, you agree to **release, indemnify, and hold harmless** the developers, contributors, and any affiliated parties from any and all liability, claims, damages, or expenses arising from your use of this application.

### Entertainment Value

This project is created for fun, learning, and experimentation with modern web technologies. It is **NOT** intended for:
- ❌ Commercial use
- ❌ Replacement for official manufacturer software
- ❌ Critical or production applications

## License

MIT License - See LICENSE file for details. Note that this license applies to the code only and does not grant any rights to Decent Espresso trademarks or intellectual property.

## Support

For issues and questions:
- Check the troubleshooting guide in the app
- Review the Web Bluetooth API documentation
- Consult Decent Espresso community forums

## Acknowledgments

- **Decent Espresso Ltd.** - For creating incredible espresso machines that inspire innovation
- **Web Bluetooth API Community** - For documentation, examples, and support
- **Open Source Contributors** - For the amazing libraries that make this project possible
- **Espresso Enthusiasts** - For testing, feedback, and inspiration

---

## 📄 Version Information

**Current Version:** v2.0.0 (November 2025)

### Changelog

#### v2.0.0 (November 2025) - Production Release
- ✅ **FIXED:** Critical Bluetooth profile transfer protocol bugs
- ✅ **FIXED:** Correct binary encoding for profile header, frames, and tail
- ✅ **FIXED:** Temperature encoding (1 byte × 2, not 2 bytes × 256)
- ✅ **FIXED:** Added missing tail frame to prevent machine crashes
- ✅ **FIXED:** F8_1_7 duration encoding implementation
- ✅ Automatic shot recording on machine state change
- ✅ Comprehensive accessibility features (ARIA labels, screen readers)
- ✅ Removed 3rd party reference files
- ✅ Production-ready deployment

#### v1.0.0 (January 2025) - Initial Release
- ✅ Core Bluetooth connectivity with Decent machines
- ✅ Real-time data visualization with dual Y-axis charts
- ✅ Shot history with rating and notes functionality
- ✅ Advanced analytics dashboard
- ✅ Demo mode for testing without hardware
- ✅ Recipe management system
- ✅ Comprehensive legal disclaimer
- ✅ Auto-selecting temperature parsing
- ✅ Database persistence for all shots
- ✅ Import/export functionality

---

**Made with ☕ by the community • For educational purposes only • No warranty provided**

© 2025 • This is an unofficial educational project • Decent Espresso® is a trademark of Decent Espresso Ltd.

*Version 2.0.0 • Last Updated: November 2025*
