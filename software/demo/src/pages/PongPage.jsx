import React from 'react'
import ModuleLayout from '../components/ModuleLayout.jsx'
import UartTerminal from '../components/UartTerminal.jsx'

const PongPage = () => (
  <ModuleLayout title="PONG MODULE ACTIVE" terminalClass="wide">
    <UartTerminal moduleId="pong" cols={100} rows={30} />
  </ModuleLayout>
)

export default PongPage