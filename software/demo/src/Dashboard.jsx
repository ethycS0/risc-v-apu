import React, { useState } from 'react';
import './Dashboard.css';


const Dashboard = () => {
  const [activeTest, setActiveTest] = useState('none');

  const tests = [
    { id: 'pong', label: 'Pong-c', desc: 'Real-time ping pong' },
    { id: 'tetris', label: 'Tetris', desc: 'Real time tetris gameplay' },
    { id: 'libc', label: 'Lib-c Console', desc: 'Standard M-mode system output' },
    { id: 'cfi', label: 'CFI Security Test', desc: 'Hardware-enforced exploit mitigation' },
  ];

  const renderActiveModule = () => {
    switch (activeTest) {
      case 'pong': return <PongModule />;
      case 'tetris': return <TetrisModule />;
      case 'libc': return <div className="module-placeholder">LIBC_TERMINAL_ACTIVE</div>;
      case 'cfi': return <div className="module-placeholder">CFI_ENFORCEMENT_MONITOR</div>;
      default: return (
        <div className="pulse-animation">
          <p className="init-text">&gt; SELECT_MODULE_TO_INITIALIZE</p>
        </div>
      );
    }
  };

  return (
    <div className="dashboard-container">
      <header className="dashboard-header">
        <h1 className="dashboard-title">eSC-V</h1>
        <p className="dashboard-subtitle">RV32I Zicfilp Smcfiss Smpmpind SoC</p>
      </header>
      <div className="tests-grid">
        {tests.map((test) => (
          <button key={test.id} onClick={() => setActiveTest(test.id)} className="test-button">
            <div className="test-header"><span className="test-label">{test.label}</span></div>
            <p className="test-desc">{test.desc}</p>
          </button>
        ))}
      </div>
      <main className="viewport-container">{renderActiveModule()}</main>
      <footer className="dashboard-footer">
        <span>BOARD: TANG PRIMER 20K</span>
      </footer>
    </div>
  );
};

export default Dashboard;