import React, { useState, useEffect, useRef } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import '../Dashboard.css'

const ModuleLayout = ({ children, title }) => {
  const navigate = useNavigate()
  const location = useLocation()
  const wsRef = useRef(null)

  const [gprData, setGprData] = useState({})
  const [csrData, setCsrData] = useState({})
  const [stackData, setStackData] = useState({})

  
  const [cfiEnabled, setCfiEnabled] = useState(false)
  
  const [isFlashing, setIsFlashing] = useState(false)

  useEffect(() => {
    const ws = new WebSocket('ws://localhost:8081')
    wsRef.current = ws

    ws.addEventListener('message', (event) => {
      try {
        const msg = JSON.parse(event.data)
        if (msg.type === 'telemetry') {
          const parts = msg.data.split(':')
          if (parts.length === 3) {
            const [type, name, val] = parts
            if (type === 'GPR') setGprData((prev) => ({ ...prev, [name]: val }))
            else if (type === 'CSR')
              setCsrData((prev) => ({ ...prev, [name]: val }))
            else if (type === 'STK')
              setStackData((prev) => ({ ...prev, [name]: val }))
          }
        }
      } catch (err) {}
    })

    return () => ws.close()
  }, [])

  // Clear terminal when switching modes
  useEffect(() => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify({ type: 'game', data: '\x1b[2J\x1b[H' }))
    }
  }, [location.pathname])

  // exploit command handler
  const handleExploit = (cmd) => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      const payload = JSON.stringify({
        type: 'command',
        data: cmd,
      })
      wsRef.current.send(payload)
      console.log('Sent exploit command:', cmd)
    }
  }

  // Corrected Delay
  const handleFlash = () => {
    if (isFlashing) return

    setIsFlashing(true)

    // 1. Clear terminal immediately
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify({ type: 'game', data: '\x1b[2J\x1b[H' }))
    }

    // 2. Send command to hardware INSTANTLY
    const commandMap = {
      '/pong': 'upload_pong',
      '/tetris': 'upload_tetris',
      '/cfi': cfiEnabled ? 'upload_safe' : 'upload_unsafe',
    }

    const targetCommand = commandMap[location.pathname] || 'upload_tetris'

    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      const payload = JSON.stringify({
        type: 'command',
        data: targetCommand,
      })

      wsRef.current.send(payload)
      console.log('Sent command to backend immediately:', targetCommand)
    } else {
      console.error('WebSocket is not connected.')
    }

    // 3. Keep UI flashing state for 6s
    setTimeout(() => {
      setIsFlashing(false)
    }, 6000)
  }

  const modules = [
    { id: 'pong', label: 'PONG', path: '/pong' },
    { id: 'tetris', label: 'TETRIS', path: '/tetris' },
    { id: 'cfi', label: 'CFI', path: '/cfi' },
  ]

  const viewportSizes = {
    '/pong': { width: '1000px', height: '580px' },
    '/tetris': { width: '400px', height: '450px' },
    '/cfi': { width: '600px', height: '580px' },
  }

  const currentSize = viewportSizes[location.pathname] || {
    width: '345px',
    height: '380px',
  }

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
            {location.pathname === '/cfi' && (
              <>
                <button
                  className="exploit-btn"
                  onClick={() => handleExploit('exploit_jop')}
                >
                  JOP
                </button>
                <button
                  className="exploit-btn"
                  onClick={() => handleExploit('exploit_rop')}
                >
                  ROP
                </button>
                <div className="cfi-toggle-container">
                  <span className="toggle-label">Enable CFI Security</span>
                  <label className="switch">
                    <input
                      type="checkbox"
                      checked={cfiEnabled}
                      onChange={() => setCfiEnabled(!cfiEnabled)}
                    />
                    <span
                      className={`slider ${cfiEnabled ? 'on' : 'off'}`}
                    ></span>
                  </label>
                </div>
              </>
            )}
            <button 
              className={`flash-btn ${isFlashing ? 'flashing' : ''}`} 
              onClick={handleFlash}
            >
              {isFlashing ? '' : 'FLASH CPU'}
            </button>
            <button onClick={() => navigate('/')} className="home-btn">
              <span>HOME</span>
            </button>
          </div>
        </header>

        <div className="main-layout">
          <section className="left-section">
            <main className="screen-container">
              <div
                className="viewport-container"
                style={{
                  width: currentSize.width,
                  height: currentSize.height,
                  transition: 'width 0.3s ease, height 0.3s ease',
                }}
                onScroll={(e) => {
                  e.target.scrollLeft = 0
                  e.target.scrollTop = 0
                }}
              >
                {children}
              </div>
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
                {[...Array(24)].map((_, i) => (
                  <div key={i} className="dump-row">
                    <span className="dump-label">PTR_{i}:</span>
                    <span className="dump-value">
                      {stackData[i.toString()] || '--'}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            <div className="dump-container">
              <h2 className="dump-title">HARDWARE CSR DUMP</h2>
              <div className="dump-grid">
                {[
                  'mtvec',
                  'ssp',
                  'mseccfg',
                  'mscratch',
                  'mcycle',
                  'pmpcfg0',
                  'minstret',
                  'pmpaddr0',
                ].map((reg) => (
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
                {[
                  'zero',
                  'a6',
                  'ra',
                  'a7',
                  'sp',
                  's2',
                  'gp',
                  's3',
                  'tp',
                  's4',
                  't0',
                  's5',
                  't1',
                  's6',
                  't2',
                  's7',
                  's0',
                  's8',
                  's1',
                  's9',
                  'a0',
                  's10',
                  'a1',
                  's11',
                  'a2',
                  't3',
                  'a3',
                  't4',
                  'a4',
                  't5',
                  'a5',
                  't6',
                ].map((reg) => (
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