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
        background: isDarkMode ? '#0a0a0a' : '#f5f5f5',
        foreground: isDarkMode ? '#e0e0e0' : '#1a1a1a',
        cursor: isDarkMode ? '#e0e0e0' : '#1a1a1a',
        selectionBackground: isDarkMode ? '#333333' : '#cccccc',
      },
      fontFamily: '"JetBrainsMono Nerd Font", "JetBrains Mono", monospace',
      fontSize: 16,
      cols: 80,
      rows: 24,
      cursorBlink: true,
      convertEol: true,
      scrollback: 5000,
    })

    term.open(terminalDiv.current)
    termInstance.current = term

    const handleMessage = (event) => {
      term.write(event.data)
    }
    
    if (wsRef.current) {
      wsRef.current.addEventListener('message', handleMessage)
    }

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
      if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) {
        e.preventDefault()
      }

      if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) return

      let charToSend = null
      if (e.key.length === 1) {
        charToSend = e.key
      } else if (e.key === 'Enter') {
        charToSend = '\r'
      } else if (e.key === 'Backspace') {
        charToSend = '\b'
      }

      if (charToSend) {
        wsRef.current.send(`KEY:${charToSend}`)
      }
    }

    window.addEventListener('keydown', handleKeyDown)

    return () => {
      window.removeEventListener('keydown', handleKeyDown)
      ws.close()
    }
  }, [])

  const handleBootCPU = () => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      wsRef.current.send('KEY: ')
    }
  }

  const toggleTheme = () => {
    setIsDarkMode(!isDarkMode)
  }

  const tests = [
    { id: 'pong', label: 'Pong', desc: 'Real-time ping pong' },
    { id: 'tetris', label: 'Tetris', desc: 'Real time tetris gameplay' },
    { id: 'libc', label: 'Libc Test', desc: 'Standard M-mode system output' },
    {
      id: 'cfi',
      label: 'CFI Security Test',
      desc: 'Hardware-enforced exploit mitigation',
    },
  ]

  const renderActiveModule = () => {
    if (activeTest === 'none') {
      return (
        <div className="pulse-animation empty-state">
          <p className="init-text">&gt; SELECT MODULE TO INITIALIZE</p>
        </div>
      )
    }
    return <UartTerminal wsRef={wsRef} isDarkMode={isDarkMode} />
  }

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
                onChange={toggleTheme} 
                />
              <span className="slider"></span>
              </label>
             </div>
           </div> 
        </header>

        <div className="tests-grid">
          {tests.map((test) => (
            <button
              key={test.id}
              onClick={() => setActiveTest(test.id)}
              className={`test-button ${activeTest === test.id ? 'active' : ''}`}
            >
              <div className="test-header">
                <span className="test-label">{test.label}</span>
              </div>
              <p className="test-desc">{test.desc}</p>
            </button>
          ))}
        </div>

        <main className="viewport-container">
          {renderActiveModule()}
        </main>

        <footer className="dashboard-footer">
          <span>BOARD: TANG PRIMER 20K</span>
        </footer>
      </div>
    </div>
  )
}

export default Dashboard