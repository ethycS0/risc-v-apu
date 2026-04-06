import React from 'react'
import ModuleLayout from '../components/ModuleLayout.jsx'
import UartTerminal from '../components/UartTerminal.jsx'

const TetrisPage = () => (
  <ModuleLayout title="TETRIS MODULE ACTIVE" terminalClass="narrow">
    <UartTerminal moduleId="tetris" cols={60} rows={35} />
  </ModuleLayout>
) 


export default TetrisPage