import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useConnectionStore } from './stores/connectionStore'
import Layout from './components/Layout'
import ConnectionPage from './pages/ConnectionPage'
import DashboardPage from './pages/DashboardPage'
import ControlPage from './pages/ControlPage'
import RecipesPage from './pages/RecipesPage'
import HistoryPage from './pages/HistoryPage'
import SettingsPage from './pages/SettingsPage'

function App() {
  const isConnected = useConnectionStore((state) => state.connected)

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={
            isConnected ? <Navigate to="/dashboard" replace /> : <Navigate to="/connect" replace />
          } />
          <Route path="connect" element={<ConnectionPage />} />
          <Route path="dashboard" element={<DashboardPage />} />
          <Route path="control" element={<ControlPage />} />
          <Route path="recipes" element={<RecipesPage />} />
          <Route path="history" element={<HistoryPage />} />
          <Route path="settings" element={<SettingsPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}

export default App
