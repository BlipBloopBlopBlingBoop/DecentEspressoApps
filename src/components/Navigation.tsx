import { NavLink } from 'react-router-dom'
import {
  Wifi,
  Home,
  Sliders,
  BookOpen,
  History,
  BarChart3,
  Settings,
} from 'lucide-react'
import { useConnectionStore } from '../stores/connectionStore'

export default function Navigation() {
  const isConnected = useConnectionStore((state) => state.connected)

  const navItems = [
    { to: '/connect', icon: Wifi, label: 'Connect', alwaysShow: true },
    { to: '/home', icon: Home, label: 'Home' },
    { to: '/control', icon: Sliders, label: 'Control' },
    { to: '/recipes', icon: BookOpen, label: 'Recipes' },
    { to: '/history', icon: History, label: 'History' },
    { to: '/analytics', icon: BarChart3, label: 'Analytics' },
    { to: '/settings', icon: Settings, label: 'Settings' },
  ]

  return (
    <nav
      className="bg-gray-900 border-t border-gray-800"
      role="navigation"
      aria-label="Main navigation"
    >
      <div className="flex justify-around" role="menubar">
        {navItems.map(({ to, icon: Icon, label, alwaysShow }) => {
          // Show connect always, others only when connected
          if (!alwaysShow && !isConnected && to !== '/connect') {
            return (
              <div
                key={to}
                className="flex-1 flex flex-col items-center py-2 opacity-30 cursor-not-allowed"
                role="menuitem"
                aria-disabled="true"
                aria-label={`${label} (disabled, connect to machine first)`}
              >
                <Icon className="w-5 h-5" aria-hidden="true" />
                <span className="text-xs mt-1">{label}</span>
              </div>
            )
          }

          return (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                `flex-1 flex flex-col items-center py-2 transition-colors ${
                  isActive
                    ? 'text-decent-blue'
                    : 'text-gray-400 hover:text-gray-200'
                }`
              }
              role="menuitem"
              aria-label={label}
            >
              {({ isActive }) => (
                <>
                  <Icon className="w-5 h-5" aria-hidden="true" />
                  <span className="text-xs mt-1" aria-current={isActive ? 'page' : undefined}>
                    {label}
                  </span>
                </>
              )}
            </NavLink>
          )
        })}
      </div>
    </nav>
  )
}
