import { Routes, Route } from 'react-router-dom'
import Dashboard from './Dashboard.jsx'
import PongPage from './pages/PongPage.jsx'
import TetrisPage from './pages/TetrisPage.jsx'
import CfiPage from './pages/CfiPage.jsx'
import DocsPage from './pages/DocsPage.jsx'

function App() {
  return (
    <Routes>
      <Route path="/" element={<Dashboard />} />
      <Route path="/pong" element={<PongPage />} />
      <Route path="/tetris" element={<TetrisPage />} />
      <Route path="/cfi" element={<CfiPage />} />
      <Route path="/docs" element={<DocsPage />} />
    </Routes>
  )
}

export default App