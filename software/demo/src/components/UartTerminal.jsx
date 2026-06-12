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
        selectionBackground: 'rgba(256, 256, 256, 0.3)',
      },
      fontFamily: '"JetBrainsMono Nerd Font", monospace',
      fontSize: 14,
      cols: 180,
      rows: 50,
      cursorBlink: true,
      convertEol: true,
    })

    const ws = new WebSocket('ws://localhost:8081')
    const handleClearTerminal = () => {
      term.reset()
    }
    window.addEventListener('clear-terminal', handleClearTerminal)

    term.attachCustomKeyEventHandler((e) => {
      if (e.code === 'Space') {
        if (e.type === 'keydown') {
          e.preventDefault()
          if (ws.readyState === WebSocket.OPEN) {
            ws.send('KEY: ')
          }
        }
        return false // Prevents xterm from capturing it and jumping
      }
      if (e.code.startsWith('Arrow')) {
        if (e.type === 'keydown') {
          e.preventDefault()
        }
        return true
      }
      return true
    })

    term.open(terminalDiv.current)
    termInstance.current = term
    term.focus()

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
      window.removeEventListener('clear-terminal', handleClearTerminal)
    }
  }, [moduleId])

  return (
    <div className="terminal-wrapper">
      <div ref={terminalDiv} className="terminal-container" />
    </div>
  )
}

export default UartTerminal
