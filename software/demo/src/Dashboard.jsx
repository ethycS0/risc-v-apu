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
      fontSize: 14,
      cols: 70,
      rows: 25,
      cursorBlink: true,
      convertEol: true,
    })

    term.open(terminalDiv.current)
    termInstance.current = term

    // Auto-focus the terminal so you can immediately press Space to boot
    term.focus()

    const handleMessage = (event) => {
      term.write(event.data)
    }
    if (wsRef.current) wsRef.current.addEventListener('message', handleMessage)

    const inputListener = term.onData((data) => {
      if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
        wsRef.current.send(`KEY:${data}`)
      }
    })

    return () => {
      if (wsRef.current)
        wsRef.current.removeEventListener('message', handleMessage)
      inputListener.dispose()
      term.dispose()
    }
  }, [])

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

  useEffect(() => {
    const ws = new WebSocket('ws://localhost:8081')
    wsRef.current = ws

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
            <table className="status-table">
              <thead>
                <tr>
                  <th>1</th>
                  <th>2</th>
                  <th>3</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td></td>
                  <td></td>
                  <td></td>
                </tr>
                <tr>
                  <td></td>
                  <td></td>
                  <td></td>
                </tr>
                <tr>
                  <td></td>
                  <td></td>
                  <td></td>
                </tr>
              </tbody>
            </table>
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
