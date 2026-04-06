import React from 'react'
import ModuleLayout from '../components/ModuleLayout.jsx'
import UartTerminal from '../components/UartTerminal.jsx'

const TetrisPage = () => {
  return (
    <ModuleLayout title="TETRIS MODULE ACTIVE">
      <UartTerminal moduleId="tetris" />
    </ModuleLayout>
  )
}

export default TetrisPage