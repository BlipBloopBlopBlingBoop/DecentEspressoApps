import { Coffee, Github, Heart } from 'lucide-react'

export default function Footer() {
  return (
    <footer className="bg-gray-900/50 backdrop-blur-sm border-t border-gray-800 py-6 px-4">
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 text-sm">
          {/* About */}
          <div>
            <h3 className="text-white font-semibold mb-2 flex items-center gap-2">
              <Coffee className="w-4 h-4" />
              Decent Control
            </h3>
            <p className="text-gray-400 text-xs leading-relaxed">
              An unofficial, educational web-based control interface for Decent Espresso machines.
              Built with React, TypeScript, and Web Bluetooth API.
            </p>
          </div>

          {/* Disclaimer */}
          <div>
            <h3 className="text-white font-semibold mb-2">Disclaimer</h3>
            <p className="text-gray-400 text-xs leading-relaxed">
              This project is <strong>not affiliated with Decent Espresso Ltd.</strong>
              All trademarks and intellectual property rights belong to their respective owners.
              Use at your own risk.
            </p>
          </div>

          {/* Credits */}
          <div>
            <h3 className="text-white font-semibold mb-2">Credits</h3>
            <ul className="text-gray-400 text-xs space-y-1">
              <li className="flex items-center gap-1">
                <Heart className="w-3 h-3 text-red-500" />
                Created for educational purposes
              </li>
              <li>Web Bluetooth API by W3C</li>
              <li>Decent Espresso® is a trademark of Decent Espresso Ltd.</li>
              <li className="flex items-center gap-1">
                <Github className="w-3 h-3" />
                Open source community
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-6 pt-6 border-t border-gray-800 text-center">
          <p className="text-gray-500 text-xs">
            v1.0.0 • January 2025 • For demo and educational purposes only • No warranty provided
          </p>
          <p className="text-gray-600 text-xs mt-2">
            Made with <Heart className="w-3 h-3 inline text-red-500" /> by the community
          </p>
        </div>
      </div>
    </footer>
  )
}
