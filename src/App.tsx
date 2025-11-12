import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useEffect } from 'react'
import { useConnectionStore } from './stores/connectionStore'
import { useShotStore } from './stores/shotStore'
import { databaseService } from './services/databaseService'
import Layout from './components/Layout'
import ConnectionPage from './pages/ConnectionPage'
import HomePage from './pages/HomePage'
import DashboardPage from './pages/DashboardPage'
import ControlPage from './pages/ControlPage'
import RecipesPage from './pages/RecipesPage'
import HistoryPage from './pages/HistoryPage'
import SettingsPage from './pages/SettingsPage'
import AnalyticsPage from './pages/AnalyticsPage'

function App() {
  const isConnected = useConnectionStore((state) => state.connected)

  // Initialize database and load all data on app start
  useEffect(() => {
    const initializeApp = async () => {
      try {
        console.log('[App] Initializing database...')
        await databaseService.init()

        // Load all shots from database
        const shots = await databaseService.getAllShots()
        console.log(`[App] Loaded ${shots.length} shots from database`)
        useShotStore.getState().loadShots(shots)
      } catch (error) {
        console.error('[App] Failed to initialize database:', error)
      }
    }

    initializeApp()
  }, [])

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={
            isConnected ? <Navigate to="/home" replace /> : <Navigate to="/connect" replace />
          } />
          <Route path="connect" element={<ConnectionPage />} />
          <Route path="home" element={<HomePage />} />
          <Route path="dashboard" element={<DashboardPage />} />
          <Route path="control" element={<ControlPage />} />
          <Route path="recipes" element={<RecipesPage />} />
          <Route path="history" element={<HistoryPage />} />
          <Route path="analytics" element={<AnalyticsPage />} />
          <Route path="settings" element={<SettingsPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}

export default App
