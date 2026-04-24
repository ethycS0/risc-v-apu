import React from 'react'
import { useNavigate } from 'react-router-dom'
import TraceBackground from './TraceBackground'
import './Dashboard.css'

const Dashboard = () => {
  const navigate = useNavigate()

  const modules = [
    {
      id: 'pong',
      label: 'PONG',
      path: '/pong',
      art: (
        <div className="art-container pong-art">
          <div className="pong-line"></div>
          <div className="pong-paddle left"></div>
          <div className="pong-ball"></div>
          <div className="pong-paddle right"></div>
        </div>
      ),
    },
    {
      id: 'tetris',
      label: 'TETRIS',
      path: '/tetris',
      art: (
        <div className="art-container tetris-art">
          <div className="t-block empty"></div>
          <div className="t-block filled"></div>
          <div className="t-block empty"></div>
          <div className="t-block filled"></div>
          <div className="t-block filled"></div>
          <div className="t-block filled"></div>
        </div>
      ),
    },
    {
      id: 'cfi',
      label: 'CFI',
      path: '/cfi',
      art: (
        <div className="art-container cfi-art">
          <span className="cfi-line valid">SHADOW_RA == 0x10A4</span>
          <span className="cfi-line invalid">
            STACK_RA == <span className="strike">0xDEAD</span>
          </span>
          <span className="cfi-line blink">[ HARDWARE TRAP ]</span>
        </div>
      ),
    },
  ]

  return (
    <div className="dashboard-root dark">
      <TraceBackground />
      <div className="grid-background" />
      <div className="dashboard-container">
        <header className="dashboard-header">
          <div className="header-left">
            <h1 className="dashboard-title">eSC-V</h1>
            <p className="dashboard-subtitle">M-mode CFI-Hardened RISC-V SoC</p>
          </div>
          <div className="header-controls">
            <button
              onClick={() => navigate('/docs')}
              className="home-btn"
              style={{
                background: 'rgba(255, 255, 255, 0.05)',
                border: '1px solid rgba(255, 255, 255, 0.2)',
              }}
            >
              <span>DOCS</span>
            </button>
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
                <div className="cube-art-wrapper">{m.art}</div>
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