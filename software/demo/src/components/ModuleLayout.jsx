import React, { useState, useEffect } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import '../Dashboard.css'

const ModuleLayout = ({ children, title }) => {
  const navigate = useNavigate()
  const location = useLocation()

  const [gprData, setGprData] = useState({})
  const [csrData, setCsrData] = useState({})
  const [stackData, setStackData] = useState({})

  useEffect(() => {
    const ws = new WebSocket('ws://localhost:8081')

    ws.addEventListener('message', (event) => {
      try {
        const msg = JSON.parse(event.data)
        if (msg.type === 'telemetry') {
          const parts = msg.data.split(':')
          if (parts.length === 3) {
            const [type, name, val] = parts
            if (type === 'GPR') setGprData((prev) => ({ ...prev, [name]: val }))
            else if (type === 'CSR') setCsrData((prev) => ({ ...prev, [name]: val }))
            else if (type === 'STK') setStackData((prev) => ({ ...prev, [name]: val }))
          }
        }
      } catch (err) {}
    })

    return () => ws.close()
  }, [])

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
            <p className="dashboard-subtitle">{title}</p>
          </div>
          <div className="header-controls">
            <button className="flash-btn">
              FLASH CPU
            </button>
            <button onClick={() => navigate('/')} className="home-btn">
              <span>HOME</span>
            </button>
          </div>
        </header>

        <div className="main-layout">
          <section className="left-section">
            <main className="viewport-container">
              {children}
            </main>
            <div className="cube-grid">
              {modules.map((m) => (
                <button
                  key={m.id}
                  onClick={() => navigate(m.path)}
                  className={`test-cube ${location.pathname === m.path ? 'active' : ''}`}
                >
                  <span className="cube-label">{m.label}</span>
                </button>
              ))}
            </div>
          </section>

          <aside className="right-section">
            <div className="dump-container">
              <h2 className="dump-title">HARDWARE STACK DUMP</h2>
              <div className="dump-grid stack-dump">
                {[...Array(10)].map((_, i) => (
                  <div key={i} className="dump-row">
                    <span className="dump-label">PTR_{i}:</span>
                    <span className="dump-value">{stackData[i.toString()] || '--'}</span>
                  </div>
                ))}
              </div>
            </div>

            <div className="dump-container">
              <h2 className="dump-title">HARDWARE CSR DUMP</h2>
              <div className="dump-grid">
                {['mtvec', 'ssp', 'mseccfg', 'mscratch', 'mcycle', 'pmpcfg0', 'minstret', 'pmpaddr0'].map((reg) => (
                  <div key={reg} className="dump-row">
                    <span className="dump-label">{reg}:</span>
                    <span className="dump-value">{csrData[reg] || '--'}</span>
                  </div>
                ))}
              </div>
            </div>

            <div className="dump-container">
              <h2 className="dump-title">HARDWARE GPR DUMP</h2>
              <div className="dump-grid gpr-dump">
                {['zero', 'a6', 'ra', 'a7', 'sp', 's2', 'gp', 's3', 'tp', 's4', 't0', 's5', 't1', 's6', 't2', 's7', 's0', 's8', 's1', 's9', 'a0', 's10', 'a1', 's11', 'a2', 't3', 'a3', 't4', 'a4', 't5', 'a5', 't6'].map((reg) => (
                  <div key={reg} className="dump-row">
                    <span className="dump-label">{reg}:</span>
                    <span className="dump-value">{gprData[reg] || '--'}</span>
                  </div>
                ))}
              </div>
            </div>
          </aside>
        </div>

        <footer className="dashboard-footer">
          <span>BOARD: TANG PRIMER 20K</span>
        </footer>
      </div>
    </div>
  )
}

export default ModuleLayout