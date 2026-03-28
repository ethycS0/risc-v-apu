import React, { useState, useEffect, useRef } from 'react'
import { Terminal } from 'xterm'
import 'xterm/css/xterm.css'
import './Dashboard.css'

const UartTerminal = ({ wsRef }) => {
  const terminalDiv = useRef(null)
  const termInstance = useRef(null)

  useEffect(() => {
    const term = new Terminal({
      theme: {
        background: '#0a0a0a',
        foreground: '#4ade80',
        cursor: '#4ade80',
      },
      fontFamily: 'monospace',
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
  }, [wsRef])

  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'center',
        backgroundColor: '#0a0a0a',
        padding: '1rem',
        borderRadius: '8px',
      }}
    >
      <div
        ref={terminalDiv}
        style={{ width: 'max-content', height: 'max-content' }}
      />
    </div>
  )
}

const Dashboard = () => {
  const [activeTest, setActiveTest] = useState('none')
  const wsRef = useRef(null) 

  useEffect(() => {
    const ws = new WebSocket('ws://localhost:8081')
    wsRef.current = ws

    const handleKeyDown = (e) => {
      if (
        ['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(
          e.code,
        )
      ) {
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
        <div
          className="pulse-animation"
          style={{ padding: '4rem', textAlign: 'center', color: '#666' }}
        >
          <p className="init-text font-mono">
            &gt; SELECT_MODULE_TO_INITIALIZE
          </p>
        </div>
      )
    }
    return <UartTerminal wsRef={wsRef} />
  }

  return (
    <div className="dashboard-container">
      <header
        className="dashboard-header"
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <div>
          <h1 className="dashboard-title">eSC-V</h1>
          <p className="dashboard-subtitle">M-mode CFI-Hardened RV32I SoC</p>
        </div>

        <button
          onClick={handleBootCPU}
          style={{
            backgroundColor: '#ef4444',
            color: 'white',
            padding: '10px 20px',
            borderRadius: '4px',
            fontWeight: 'bold',
            cursor: 'pointer',
            border: 'none',
          }}
        >
          ⚡ INITIALIZE CPU
        </button>
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

      <main className="viewport-container" style={{ marginTop: '2rem' }}>
        {renderActiveModule()}
      </main>

      <footer
        className="dashboard-footer"
        style={{ marginTop: '2rem', color: '#666', fontSize: '0.8rem' }}
      >
        <span>BOARD: TANG PRIMER 20K | STATUS: BRIDGE CONNECTED</span>
      </footer>
    </div>
  )
}

export default Dashboard
