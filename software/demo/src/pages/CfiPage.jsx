import React from 'react'
import ModuleLayout from '../components/ModuleLayout.jsx'
import UartTerminal from '../components/UartTerminal.jsx'

const CfiPage = () => (
  <ModuleLayout title="CFI MODULE ACTIVE" terminalClass="standard">
    <UartTerminal moduleId="cfi" cols={120} rows={30} />
  </ModuleLayout>
)

export default CfiPage