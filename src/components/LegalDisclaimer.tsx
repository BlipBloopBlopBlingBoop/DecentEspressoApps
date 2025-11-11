import { useState } from 'react'
import { AlertTriangle, Check } from 'lucide-react'

interface LegalDisclaimerProps {
  onAccept: () => void
}

export default function LegalDisclaimer({ onAccept }: LegalDisclaimerProps) {
  const [hasScrolled, setHasScrolled] = useState(false)
  const [hasAgreed, setHasAgreed] = useState(false)

  const handleScroll = (e: React.UIEvent<HTMLDivElement>) => {
    const element = e.currentTarget
    const isNearBottom =
      element.scrollHeight - element.scrollTop - element.clientHeight < 50
    if (isNearBottom) {
      setHasScrolled(true)
    }
  }

  const handleAccept = () => {
    if (hasAgreed) {
      localStorage.setItem('legal-disclaimer-accepted', 'true')
      onAccept()
    }
  }

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div className="bg-gray-900 border border-gray-700 rounded-2xl max-w-2xl w-full max-h-[90vh] flex flex-col shadow-2xl">
        {/* Header */}
        <div className="p-6 border-b border-gray-700">
          <div className="flex items-center gap-3 mb-2">
            <div className="bg-yellow-500/20 p-2 rounded-lg">
              <AlertTriangle className="w-6 h-6 text-yellow-500" />
            </div>
            <h2 className="text-2xl font-bold text-white">Legal Disclaimer & Terms</h2>
          </div>
          <p className="text-sm text-gray-400">
            Please read carefully before using this application
          </p>
        </div>

        {/* Content */}
        <div
          className="flex-1 overflow-y-auto p-6 space-y-4 text-gray-300"
          onScroll={handleScroll}
        >
          <section>
            <h3 className="text-lg font-semibold text-white mb-2">
              🎓 Educational & Demonstration Purpose Only
            </h3>
            <p className="text-sm leading-relaxed">
              This application is provided strictly for <strong>educational and demonstration purposes</strong>.
              It is a proof-of-concept project showcasing Web Bluetooth API integration and should
              not be considered production-ready software.
            </p>
          </section>

          <section>
            <h3 className="text-lg font-semibold text-white mb-2">
              ⚠️ Use at Your Own Risk
            </h3>
            <p className="text-sm leading-relaxed">
              This software is provided "AS IS" without warranty of any kind, express or implied.
              By using this application, you acknowledge that:
            </p>
            <ul className="list-disc list-inside space-y-1 text-sm mt-2 ml-2">
              <li>You use this software entirely at your own risk</li>
              <li>The developers assume no liability for any damages, injuries, or losses</li>
              <li>You are responsible for the safe operation of your espresso machine</li>
              <li>No warranties are provided regarding functionality, safety, or reliability</li>
            </ul>
          </section>

          <section>
            <h3 className="text-lg font-semibold text-white mb-2">
              ©️ Intellectual Property Rights
            </h3>
            <p className="text-sm leading-relaxed">
              Decent Espresso® and all related trademarks, logos, and intellectual property
              belong to Decent Espresso Ltd. This project is an independent, unofficial
              implementation and is <strong>not affiliated with, endorsed by, or sponsored by Decent Espresso Ltd.</strong>
            </p>
            <p className="text-sm leading-relaxed mt-2">
              All original design, engineering, and proprietary elements of Decent Espresso
              machines remain the exclusive property of Decent Espresso Ltd. and its rightful owners.
            </p>
          </section>

          <section>
            <h3 className="text-lg font-semibold text-white mb-2">
              🔧 No Official Support
            </h3>
            <p className="text-sm leading-relaxed">
              This is a community/hobbyist project. The original equipment manufacturers
              and their official support channels are not responsible for issues arising
              from the use of this software.
            </p>
          </section>

          <section>
            <h3 className="text-lg font-semibold text-white mb-2">
              ⚡ Safety Warning
            </h3>
            <p className="text-sm leading-relaxed">
              Espresso machines operate at high temperatures and pressures. Improper use
              can result in:
            </p>
            <ul className="list-disc list-inside space-y-1 text-sm mt-2 ml-2">
              <li>Burns from hot water, steam, or machine surfaces</li>
              <li>Equipment damage or malfunction</li>
              <li>Water damage to surrounding areas</li>
              <li>Electrical hazards if machine is improperly maintained</li>
            </ul>
            <p className="text-sm leading-relaxed mt-2 font-semibold text-yellow-400">
              Always follow the manufacturer's safety guidelines and never leave your machine
              unattended during operation.
            </p>
          </section>

          <section>
            <h3 className="text-lg font-semibold text-white mb-2">
              🔐 Privacy & Data
            </h3>
            <p className="text-sm leading-relaxed">
              All data is stored locally in your browser using IndexedDB. No data is
              transmitted to external servers. However, the developers make no guarantees
              about data persistence, privacy, or security.
            </p>
          </section>

          <section>
            <h3 className="text-lg font-semibold text-white mb-2">
              📜 License & Liability Waiver
            </h3>
            <p className="text-sm leading-relaxed">
              By using this software, you agree to release, indemnify, and hold harmless
              the developers, contributors, and any affiliated parties from any and all
              liability, claims, damages, or expenses arising from your use of this application.
            </p>
          </section>

          <section>
            <h3 className="text-lg font-semibold text-white mb-2">
              🎭 Entertainment Value
            </h3>
            <p className="text-sm leading-relaxed">
              This project is created for fun, learning, and experimentation with modern
              web technologies. It is not intended for commercial use or as a replacement
              for official manufacturer software.
            </p>
          </section>

          <div className="pt-4 border-t border-gray-700">
            <p className="text-xs text-gray-500 italic">
              Last Updated: January 2025 • This disclaimer may be updated without notice
            </p>
          </div>
        </div>

        {/* Footer */}
        <div className="p-6 border-t border-gray-700 space-y-4">
          <label className="flex items-start gap-3 cursor-pointer group">
            <input
              type="checkbox"
              checked={hasAgreed}
              onChange={(e) => setHasAgreed(e.target.checked)}
              className="mt-1 w-5 h-5 rounded border-gray-600 bg-gray-800 text-decent-blue focus:ring-2 focus:ring-decent-blue focus:ring-offset-0"
              disabled={!hasScrolled}
            />
            <span className={`text-sm ${hasScrolled ? 'text-white' : 'text-gray-500'}`}>
              I have read and understood the disclaimer. I agree to use this software at my own
              risk and acknowledge that the developers assume no liability for any damages or
              issues that may arise.
            </span>
          </label>

          {!hasScrolled && (
            <p className="text-xs text-yellow-500 flex items-center gap-2">
              <AlertTriangle className="w-4 h-4" />
              Please scroll to the bottom to continue
            </p>
          )}

          <button
            onClick={handleAccept}
            disabled={!hasAgreed}
            className={`w-full py-4 rounded-xl font-semibold text-lg transition-all flex items-center justify-center gap-2 ${
              hasAgreed
                ? 'bg-decent-blue hover:bg-blue-700 text-white shadow-lg hover:shadow-xl'
                : 'bg-gray-800 text-gray-600 cursor-not-allowed'
            }`}
          >
            <Check className="w-5 h-5" />
            Accept & Continue
          </button>

          <p className="text-xs text-center text-gray-500">
            By clicking "Accept & Continue", you acknowledge that you have read and agree to the terms above
          </p>
        </div>
      </div>
    </div>
  )
}
