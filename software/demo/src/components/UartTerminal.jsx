import React, { useEffect, useRef } from 'react'
import { Terminal } from 'xterm'
import 'xterm/css/xterm.css'

const UartTerminal = ({ moduleId }) => {
  const terminalDiv = useRef(null)
  const termInstance = useRef(null)

  useEffect(() => {
    const term = new Terminal({
      theme: {
        background: '#0a0a0a',
        foreground: '#e0e0e0',
        cursor: '#e0e0e0',
        selectionBackground: 'rgba(128, 128, 128, 0.3)',
      },
      fontFamily: '"JetBrainsMono Nerd Font", monospace',
      fontSize: 14,
      cols: 120,
      rows: 30,
      cursorBlink: true,
      convertEol: true,
    })

    term.open(terminalDiv.current)
    termInstance.current = term
    term.focus()

    const ws = new WebSocket('ws://localhost:8081')

    ws.addEventListener('open', () => {
      ws.send(`MOD:${moduleId}`)
    })

    const handleMessage = (event) => {
      try {
        const msg = JSON.parse(event.data)
        if (msg.type === 'game') {
          term.write(msg.data)
        }
      } catch (err) {}
    }

    ws.addEventListener('message', handleMessage)

    const inputListener = term.onData((data) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(`KEY:${data}`)
      }
    })

    return () => {
      ws.close()
      inputListener.dispose()
      term.dispose()
    }
  }, [moduleId])

  return (
    <div className="terminal-wrapper">
      <div ref={terminalDiv} className="terminal-container" />
    </div>
  )
}

export default UartTerminal