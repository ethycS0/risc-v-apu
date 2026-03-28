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
      if (wsRef.current) wsRef.current.removeEventListener('message', handleMessage)
      inputListener.dispose() 
      term.dispose()
    }
  }, [wsRef, isDarkMode])

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

    const handleKeyDown = (e) => {
      if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) e.preventDefault()
      if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) return

      let charToSend = null
      if (e.key.length === 1) charToSend = e.key
      else if (e.key === 'Enter') charToSend = '\r'
      else if (e.key === 'Backspace') charToSend = '\b'

      if (charToSend) wsRef.current.send(`KEY:${charToSend}`)
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => {
      window.removeEventListener('keydown', handleKeyDown)
      ws.close()
    }
  }, [])

  const handleBootCPU = () => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) wsRef.current.send('KEY: ')
  }

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
                <input type="checkbox" checked={!isDarkMode} onChange={() => setIsDarkMode(!isDarkMode)} />
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
        </div>

        <footer className="dashboard-footer">
          <span>BOARD: TANG PRIMER 20K</span>
        </footer>
      </div>
    </div>
  )
}

export default Dashboard