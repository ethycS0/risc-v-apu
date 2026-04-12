import React, { useRef, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import './Dashboard.css'

const Dashboard = () => {
  const navigate = useNavigate()
  const canvasRef = useRef(null)
  const mouse = useRef({ x: 0, y: 0 })

  useEffect(() => {
    const canvas = canvasRef.current
    const ctx = canvas.getContext('2d')
    let animationFrameId
    let traces = []

    const resize = () => {
      canvas.width = window.innerWidth
      canvas.height = window.innerHeight
    }

    window.addEventListener('resize', resize)
    resize()

    class Trace {
      constructor(x, y, isManual = false) {
        this.x = x || Math.random() * canvas.width
        this.y = y || Math.random() * canvas.height
        this.path = [{ x: this.x, y: this.y }]
        this.length = Math.floor(Math.random() * 8) + 4
        this.life = 1.0
        this.speed = isManual ? 0.01 : 0.005
        this.dir = Math.random() > 0.5 ? 'h' : 'v'
        this.buildPath()
      }

      buildPath() {
        let curX = this.x
        let curY = this.y
        for (let i = 0; i < this.length; i++) {
          const segment = Math.random() * 120 + 40
          if (this.dir === 'h') {
            curX += Math.random() > 0.5 ? segment : -segment
            this.dir = 'v'
          } else {
            curY += Math.random() > 0.5 ? segment : -segment
            this.dir = 'h'
          }
          this.path.push({ x: curX, y: curY })
        }
      }

      draw() {
        ctx.beginPath()
        ctx.strokeStyle = `rgba(255, 255, 255, ${this.life * 0.15})`
        ctx.lineWidth = 1.5
        ctx.moveTo(this.path[0].x, this.path[0].y)
        for (let i = 1; i < this.path.length; i++) {
          ctx.lineTo(this.path[i].x, this.path[i].y)
        }
        ctx.stroke()

        const head = this.path[0]
        ctx.fillStyle = `rgba(255, 255, 255, ${this.life * 0.6})`
        ctx.beginPath()
        ctx.arc(head.x, head.y, 1.5, 0, Math.PI * 2)
        ctx.fill()

        this.life -= this.speed
      }
    }

    const render = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height)
      
      if (Math.random() > 0.92) {
        traces.push(new Trace())
      }

      if (Math.random() > 0.98) {
        traces.push(new Trace(mouse.current.x, mouse.current.y, true))
      }

      traces = traces.filter(t => t.life > 0)
      traces.forEach(t => t.draw())

      animationFrameId = requestAnimationFrame(render)
    }

    render()
    return () => {
      window.removeEventListener('resize', resize)
      cancelAnimationFrame(animationFrameId)
    }
  }, [])

  const handleMouseMove = (e) => {
    mouse.current.x = e.clientX
    mouse.current.y = e.clientY
  }

  const modules = [
    { id: 'pong', label: 'PONG', path: '/pong' },
    { id: 'tetris', label: 'TETRIS', path: '/tetris' },
    { id: 'cfi', label: 'CFI', path: '/cfi' },
  ]

  return (
    <div onMouseMove={handleMouseMove} className="dashboard-root dark">
      <canvas ref={canvasRef} className="trace-canvas" />
      <div className="grid-background" />
      <div className="dashboard-container">
        <header className="dashboard-header">
          <div className="header-left">
            <h1 className="dashboard-title">eSC-V</h1>
            <p className="dashboard-subtitle">M-mode CFI-Hardened RV32I SoC</p>
          </div>
        </header>

        <div className="main-layout center-layout">
          <div className="cube-grid home-grid">
            {modules.map((m) => (
              <button
                key={m.id}
                onClick={() => navigate(m.path)}
                className="test-cube home-cube"
              >
                <span className="cube-label">{m.label}</span>
              </button>
            ))}
          </div>
        </div>

        <footer className="dashboard-footer">
          <span>BOARD: TANG PRIMER 20K</span>

        </footer>
      </div>
    </div>
  )
}

export default Dashboard