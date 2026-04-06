import React from 'react'
import { useNavigate } from 'react-router-dom'
import './Dashboard.css'

const Dashboard = () => {
  const navigate = useNavigate()

  const modules = [
    { id: 'pong', label: 'PONG', path: '/pong' },
    { id: 'tetris', label: 'TETRIS', path: '/tetris' },
    { id: 'cfi', label: 'CFI', path: '/cfi' },
  ]

  return (
    <div className="dashboard-root dark">
      <div className="grid-background" />
      <div className="dashboard-container">
        <header className="dashboard-header">
          <div className="header-left">
            <h1 className="dashboard-title">eSC-V</h1>
            <p className="dashboard-subtitle">M-mode CFI-Hardened RV32I SoC</p>
          </div>
        </header>

        <div className="main-layout center-layout">
          <div className="cube-grid home-grid">
            {modules.map((m) => (
              <button
                key={m.id}
                onClick={() => navigate(m.path)}
                className="test-cube home-cube"
              >
                <span className="cube-label">{m.label}</span>
              </button>
            ))}
          </div>
        </div>

        <footer className="dashboard-footer">
          <span>BOARD: TANG PRIMER 20K</span>
        </footer>
      </div>
    </div>
  )
}

export default Dashboard