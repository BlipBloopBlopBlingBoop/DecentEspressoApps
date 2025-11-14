import { Outlet } from 'react-router-dom'
import Navigation from './Navigation'
import StatusBar from './StatusBar'

export default function Layout() {
  return (
    <div className="flex flex-col h-screen bg-decent-dark">
      <StatusBar />
      <main
        id="main-content"
        className="flex-1 overflow-y-auto"
        role="main"
        aria-label="Main content"
        tabIndex={-1}
      >
        <Outlet />
      </main>
      <Navigation />
    </div>
  )
}
