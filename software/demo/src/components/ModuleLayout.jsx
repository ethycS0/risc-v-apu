import React, { useState, useEffect, useRef } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import TraceBackground from '../TraceBackground'
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
      wsRef.current.send(
        JSON.stringify({ type: 'game', data: '\x1b[0m\x1b[2J\x1b[H' }),
      )
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

    window.dispatchEvent(new Event('clear-terminal'))

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

    setTimeout(() => {
      setIsFlashing(false)
      window.dispatchEvent(new Event('clear-terminal'))
    }, 6000)
  }

  const modules = [
    { id: 'pong', label: 'PONG', path: '/pong' },
    { id: 'tetris', label: 'TETRIS', path: '/tetris' },
    { id: 'cfi', label: 'CFI', path: '/cfi' },
  ]

  const viewportSizes = {
    '/pong': { width: '1000px', height: '620px' },
    '/tetris': { width: '400px', height: '470px' },
    '/cfi': { width: '600px', height: '580px' },
  }

  const currentSize = viewportSizes[location.pathname] || {
    width: '345px',
    height: '380px',
  }

  return (
    <div className="dashboard-root dark">
      <TraceBackground />
      <div className="grid-background" />
      <div className="dashboard-container">
        <header className="dashboard-header">
          <div className="header-left">
            <h1 className="dashboard-title">{title}</h1>
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
          <aside className="right-section gdb-terminal">
            <div className="gdb-split-layout">
              {/* LEFT PANE: STACK */}
              <div className="gdb-left-pane">
                <div className="gdb-section stack-section">
                  <div className="gdb-header">
                    <span className="gdb-line">────────[</span>
                    <span className="gdb-title"> STACK </span>
                    <span className="gdb-line">]────────</span>
                  </div>
                  <div className="gdb-stack-container">
                    {Array.from({ length: 36 }, (_, i) => i - 7).map(
                      (offset) => {
                        const sign = offset < 0 ? '-' : '+'
                        const absVal = Math.abs(offset)
                          .toString()
                          .padStart(2, '0')
                        const ptrStr = `0xSP${sign}${absVal}`
                        const dataKey = offset.toString()

                        return (
                          <div key={dataKey} className="gdb-row stack-row">
                            <span
                              className="gdb-stack-ptr"
                              style={{
                                color: offset === 0 ? '#00ff00' : '#ffd700',
                              }}
                            >
                              {ptrStr}
                            </span>
                            <span className="gdb-stack-arrow">→</span>
                            <span className="gdb-value stack-value">
                              {stackData[dataKey] || '0x00000000'}
                            </span>
                          </div>
                        )
                      },
                    )}
                  </div>
                </div>
              </div>

              {/* RIGHT PANE: REGISTERS & CSRs */}
              <div className="gdb-right-pane">
                <div className="gdb-section">
                  <div className="gdb-header">
                    <span className="gdb-line">────────────────────[</span>
                    <span className="gdb-title"> REGISTERS </span>
                    <span className="gdb-line">]────────────────────</span>
                  </div>
                  <div className="gdb-grid gpr-grid">
                    {[
                      'zero',
                      'ra',
                      'sp',
                      'gp',
                      'tp',
                      't0',
                      't1',
                      't2',
                      's0',
                      's1',
                      'a0',
                      'a1',
                      'a2',
                      'a3',
                      'a4',
                      'a5',
                      'a6',
                      'a7',
                      's2',
                      's3',
                      's4',
                      's5',
                      's6',
                      's7',
                      's8',
                      's9',
                      's10',
                      's11',
                      't3',
                      't4',
                      't5',
                      't6',
                    ].map((reg) => (
                      <div key={reg} className="gdb-row">
                        <span className="gdb-reg-name">
                          {reg.padEnd(4, ' ')}
                        </span>
                        <span className="gdb-value">
                          {gprData[reg] || '0x00000000'}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="gdb-section">
                  <div className="gdb-header">
                    <span className="gdb-line">──────────────────────[</span>
                    <span className="gdb-title"> CSRs </span>
                    <span className="gdb-line">]──────────────────────</span>
                  </div>
                  <div className="gdb-grid csr-grid">
                    {[
                      'mtvec',
                      'mscratch',
                      'mcycle',
                      'minstret',
                      'ssp',
                      'mseccfg',
                      'pmpcfg0',
                      'pmpaddr0',
                    ].map((reg) => (
                      <div key={reg} className="gdb-row">
                        <span className="gdb-reg-name csr-name">
                          {reg.padEnd(8, ' ')}
                        </span>
                        <span className="gdb-value">
                          {csrData[reg] || '0x00000000'}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
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
