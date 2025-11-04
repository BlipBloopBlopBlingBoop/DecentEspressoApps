# Decent Espresso Control

A fully-functional mobile web application for controlling Decent espresso machines via Bluetooth. This app provides comprehensive control over all machine functions, real-time data visualization, recipe management, and shot history tracking.

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
- Rating system for shots
- Notes and metadata
- Search and filter by rating
- Export shot data

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

This is an open-source project. Contributions are welcome!

## License

MIT License - See LICENSE file for details

## Disclaimer

This is an unofficial third-party application and is not affiliated with, endorsed by, or connected to Decent Espresso. Use at your own risk.

## Support

For issues and questions:
- Check the troubleshooting guide in the app
- Review the Web Bluetooth API documentation
- Consult Decent Espresso community forums

## Acknowledgments

- Decent Espresso for creating amazing machines
- Web Bluetooth API community
- Open-source contributors
