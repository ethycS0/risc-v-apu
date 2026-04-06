import React, { useState, useEffect, useRef } from 'react'
import { Terminal } from 'xterm'
import 'xterm/css/xterm.css'
import './Dashboard.css'

const UartTerminal = ({ wsRef, isDarkMode }) => {
  const terminalDiv = useRef(null)
  const termInstance = useRef(null)

  useEffect(() => {
    const term = new Terminal({
      theme: {
        background: 'transparent',
        foreground: isDarkMode ? '#e0e0e0' : '#1a1a1a',
        cursor: isDarkMode ? '#e0e0e0' : '#1a1a1a',
        selectionBackground: 'rgba(128, 128, 128, 0.3)',
      },
      fontFamily: '"JetBrainsMono Nerd Font", monospace',
      fontSize: 12,
      cols: 180,
      rows: 25,
      cursorBlink: true,
      convertEol: true,
    })

    term.open(terminalDiv.current)
    termInstance.current = term
    term.focus()

    const handleMessage = (event) => {
      try {
        const msg = JSON.parse(event.data)
        // Only write to the terminal if it's normal game output
        if (msg.type === 'game') {
          term.write(msg.data)
        }
      } catch (err) {
        console.error('Failed to parse WebSocket message:', err)
      }
    }

    if (wsRef.current) wsRef.current.addEventListener('message', handleMessage)

    const inputListener = term.onData((data) => {
      if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
        wsRef.current.send(`KEY:${data}`)
      }
    })

    return () => {
      if (wsRef.current) {
        wsRef.current.removeEventListener('message', handleMessage)
      }
      inputListener.dispose()
      term.dispose()
    }
  }, []) // Empty dependency array ensures this only runs once on mount

  useEffect(() => {
    if (termInstance.current) {
      termInstance.current.options.theme = {
        background: 'transparent',
        foreground: isDarkMode ? '#e0e0e0' : '#1a1a1a',
        cursor: isDarkMode ? '#e0e0e0' : '#1a1a1a',
        selectionBackground: 'rgba(128, 128, 128, 0.3)',
      }
    }
  }, [isDarkMode])

  return (
    <div className="terminal-wrapper">
      <div ref={terminalDiv} className="terminal-container" />
    </div>
  )
}

const Dashboard = () => {
  const [activeTest, setActiveTest] = useState('none')
  const [isDarkMode, setIsDarkMode] = useState(true)
  const wsRef = useRef(null)

  // State objects to hold our telemetry data
  const [gprData, setGprData] = useState({})
  const [csrData, setCsrData] = useState({})
  const [stackData, setStackData] = useState({})

  useEffect(() => {
    const ws = new WebSocket('ws://localhost:8081')
    wsRef.current = ws

    // Listener for hardware telemetry
    ws.addEventListener('message', (event) => {
      try {
        const msg = JSON.parse(event.data)

        if (msg.type === 'telemetry') {
          // Parse format: "GPR:ra:0x0000014A"
          const parts = msg.data.split(':')
          if (parts.length === 3) {
            const [type, name, val] = parts

            // Dynamically update the specific register in React state
            if (type === 'GPR') {
              setGprData((prev) => ({ ...prev, [name]: val }))
            } else if (type === 'CSR') {
              setCsrData((prev) => ({ ...prev, [name]: val }))
            } else if (type === 'STK') {
              setStackData((prev) => ({ ...prev, [name]: val }))
            }
          }
        }
      } catch (err) {
        // Ignore JSON parse errors silently to not spam the console
      }
    })

    return () => {
      ws.close()
    }
  }, [])

  const tests = [
    { id: 'pong', label: 'PONG' },
    { id: 'tetris', label: 'TETRIS' },
    { id: 'libc', label: 'LIBC' },
    { id: 'cfi', label: 'CFI' },
  ]

  return (
    <div className={`dashboard-root ${isDarkMode ? 'dark' : 'light'}`}>
      <div className="grid-background" />
      <div className="dashboard-container">
        <header className="dashboard-header">
          <div className="header-left">
            <h1 className="dashboard-title">eSC-V</h1>
            <p className="dashboard-subtitle">M-mode CFI-Hardened RV32I SoC</p>
          </div>
          <div className="header-controls">
            <div className="theme-switch-wrapper">
              <label className="theme-switch">
                <input
                  type="checkbox"
                  checked={!isDarkMode}
                  onChange={() => setIsDarkMode(!isDarkMode)}
                />
                <span className="slider"></span>
              </label>
            </div>
          </div>
        </header>

        <div className="main-layout">
          <section className="left-section">
            <main className="viewport-container">
              {activeTest === 'none' ? (
                <div className="pulse-animation empty-state">
                  <p className="init-text">&gt; SELECT MODULE</p>
                </div>
              ) : (
                <UartTerminal wsRef={wsRef} isDarkMode={isDarkMode} />
              )}
            </main>
            <div className="cube-grid">
              {tests.map((test) => (
                <button
                  key={test.id}
                  onClick={() => setActiveTest(test.id)}
                  className={`test-cube ${activeTest === test.id ? 'active' : ''}`}
                >
                  <span className="cube-label">{test.label}</span>
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
                    {/* Maps to STK:0, STK:1, etc. Fallback to '--' */}
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
                    {/* Pull from CSR state */}
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
                    {/* Pull from GPR state */}
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

export default Dashboard
