# Decent Espresso Control v2.0.0 - Web-Based Machine Control

**A fully-featured PWA for controlling your Decent espresso machine via Web Bluetooth**

## What is it?

An unofficial, open-source web application that brings comprehensive Decent machine control to your browser. Built with modern web technologies (React, TypeScript, Web Bluetooth API), this app provides real-time monitoring, profile management, shot history tracking, and advanced analytics - all without installing anything.

## Key Features

### Core Functionality
- **Full Machine Control** - Start/stop espresso, steam, flush, and hot water modes
- **Real-Time Monitoring** - Live pressure, flow, temperature, and weight tracking at 100+ Hz
- **Profile Management** - Create, edit, and upload custom shot profiles
- **Shot History** - Complete extraction database with ratings, notes, and detailed charts
- **Tea Brewing Support** - Dedicated profiles for tea basket accessory
- **Automatic Recording** - Shots automatically save when started on machine
- **Demo Mode** - Full simulation for learning without hardware

### Technical Highlights
- **Zero Installation** - Works directly in Chrome/Edge browser
- **Offline-Capable PWA** - Full functionality without internet
- **Comprehensive Accessibility** - WCAG 2.1 AA compliant with screen reader support
- **Local Data Storage** - All data stays on your device (IndexedDB)
- **Export/Import** - Full data backup and restore capabilities

### Pre-Built Profiles
- Classic espresso styles (Turbo, Ristretto, Lungo, Americano)
- Advanced techniques (Blooming, Pressure Profiling, Adaptive)
- Milk drinks (Cappuccino, Latte, Flat White, Cortado)
- Tea brewing (Green, Black, White, Oolong)

## Browser Compatibility

✅ **Supported:**
- Chrome/Edge 56+ on Windows, Linux, macOS
- Chrome on Android

❌ **Not Supported:**
- Safari (all platforms) - No Web Bluetooth API
- iOS browsers (all) - iOS restrictions prevent Web Bluetooth
- Firefox - No Web Bluetooth support

## Quick Start

**Try it now:** [Insert your deployed URL here]

Or deploy your own instance in 2 minutes:
- [![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/BlipBloopBlopBlingBoop/deepdoopdop)
- [![Deploy to Netlify](https://www.netlify.com/img/deploy/button.svg)](https://app.netlify.com/start/deploy?repository=https://github.com/BlipBloopBlopBlingBoop/deepdoopdop)

## Important Disclaimers

⚠️ **This is an UNOFFICIAL educational project**
- NOT affiliated with, endorsed by, or sponsored by Decent Espresso Ltd.
- Decent Espresso® is a trademark of Decent Espresso Ltd.
- Use entirely at your own risk
- No warranty provided - educational/demonstration purposes only

⚠️ **Known Limitations**
- Tea profiles may have 30-second firmware duration limits
- Real-time joystick control requires specific firmware support
- Enhanced debug logging available for troubleshooting

## For Developers

- **Tech Stack**: React 18, TypeScript, Vite, Zustand, Chart.js, Plotly.js
- **Protocol**: Full implementation of Decent Bluetooth protocol
- **Contributions**: Open to community improvements and bug reports
- **Documentation**: Comprehensive protocol docs and integration guides included

## Credits

Built with ❤️ by the Decent community for educational purposes. Special thanks to:
- Decent Espresso Ltd. for creating incredible machines
- The open-source community for modern web technologies
- Early testers who provided invaluable feedback

---

**Repository:** https://github.com/BlipBloopBlopBlingBoop/deepdoopdop

**Version:** 2.0.0
**Release Date:** November 2025
**License:** Educational/Open Source

Happy brewing! ☕
