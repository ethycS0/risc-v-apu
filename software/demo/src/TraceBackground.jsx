import React, { useRef, useEffect } from 'react'

const TraceBackground = () => {
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

    const handleMouseMove = (e) => {
      mouse.current.x = e.clientX
      mouse.current.y = e.clientY
    }
    window.addEventListener('mousemove', handleMouseMove)

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
        ctx.strokeStyle = `rgba(255, 255, 255, ${this.life * 0.3})`
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

      traces = traces.filter((t) => t.life > 0)
      traces.forEach((t) => t.draw())

      animationFrameId = requestAnimationFrame(render)
    }

    render()
    return () => {
      window.removeEventListener('resize', resize)
      window.removeEventListener('mousemove', handleMouseMove)
      cancelAnimationFrame(animationFrameId)
    }
  }, [])

  return <canvas ref={canvasRef} className="trace-canvas" />
}

export default TraceBackground
