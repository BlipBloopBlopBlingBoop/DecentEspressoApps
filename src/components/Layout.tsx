import { Outlet } from 'react-router-dom'
import Navigation from './Navigation'
import StatusBar from './StatusBar'

export default function Layout() {
  return (
    <div className="flex flex-col h-screen bg-decent-dark">
      <StatusBar />
      <main className="flex-1 overflow-y-auto">
        <Outlet />
      </main>
      <Navigation />
    </div>
  )
}
