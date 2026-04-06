import React from 'react'
import ModuleLayout from '../components/ModuleLayout.jsx'
import UartTerminal from '../components/UartTerminal.jsx'

const CfiPage = () => {
  return (
    <ModuleLayout title="CFI MODULE ACTIVE">
      <UartTerminal moduleId="cfi" />
    </ModuleLayout>
  )
}

export default CfiPage