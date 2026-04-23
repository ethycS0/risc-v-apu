import React from 'react'
import ModuleLayout from '../components/ModuleLayout.jsx'
import UartTerminal from '../components/UartTerminal.jsx'

const PongPage = () => {
  return (
    <ModuleLayout title="PONG">
      <UartTerminal moduleId="pong" />
    </ModuleLayout>
  )
}

export default PongPage
