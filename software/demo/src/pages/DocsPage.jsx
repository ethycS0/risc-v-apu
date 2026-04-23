import React, { useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import TraceBackground from '../TraceBackground'
import pipelineImg from '../assets/pipeline.png'
import '../Dashboard.css'

const DocsPage = () => {
  const navigate = useNavigate()
  const scrollContainerRef = useRef(null)


  useEffect(() => {
    const sections = document.querySelectorAll('.docs-section-anchor');
    const navLinks = document.querySelectorAll('.docs-nav li');

    const observerOptions = {
      root: null,
      rootMargin: '-10% 0px -80% 0px',
      threshold: 0
    };

    const observerCallback = (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          const id = entry.target.getAttribute('id');
          navLinks.forEach((link) => {
            link.classList.remove('active');
            if (link.getAttribute('data-target') === id) {
              link.classList.add('active');
            }
          });
        }
      });
    };

    const observer = new IntersectionObserver(observerCallback, observerOptions);
    sections.forEach((section) => observer.observe(section));

    return () => observer.disconnect();
  }, []);

  /**
   * Smooth Scroll Navigation
   * Targets elements precisely with offset for the sticky header.
   */
  const scrollToSection = (id) => {
    const element = document.getElementById(id);
    if (element) {
      const headerOffset = 130;
      const elementPosition = element.getBoundingClientRect().top;
      const offsetPosition = elementPosition + window.pageYOffset - headerOffset;

      window.scrollTo({
        top: offsetPosition,
        behavior: 'smooth'
      });
    }
  };

  return (
    <div className="dashboard-root dark docs-page">
      <TraceBackground />
      <div className="grid-background" />
      
      <div className="dashboard-container">
        <header className="dashboard-header docs-header-sticky">
          <div className="header-left">
            <h1 className="dashboard-title" onClick={() => navigate('/')} style={{ cursor: 'pointer' }}>eSC-V</h1>
            <p className="dashboard-subtitle">M-MODE BARE-METAL RISC-V HARDWARE SECURITY // SYSTEM DOCUMENTATION</p>
          </div>
          <div className="header-controls">
             <button onClick={() => navigate('/')} className="home-btn"><span>EXIT_TO_SYSTEM</span></button>
          </div>
        </header>

        <div className="docs-main-wrapper">
          <aside className="docs-sidebar-sticky">
            <nav className="docs-nav">
              <div className="nav-group">
                <span className="nav-label">01 OVERVIEW</span>
                <ul>
                  <li data-target="abstract" onClick={() => scrollToSection('abstract')}>Introduction</li>
                </ul>
              </div>
              <br />
              <div className="nav-group">
                <span className="nav-label">02 DESIGN</span>
                <ul>
                  <li data-target="pipeline" onClick={() => scrollToSection('pipeline')}>Hardware Architecture</li>
                  {/* NEW NAV LINK FOR STATS */}
                  <li data-target="synthesis-stats" onClick={() => scrollToSection('synthesis-stats')}>Synthesis Statistics</li>
                  <li data-target="security-lab" onClick={() => scrollToSection('security-lab')}>Security Mechanisms</li>
                </ul>
              </div>
              <br />
              <div className="nav-group">
                <span className="nav-label">03 TOOLS</span>
                <ul>
                  <li data-target="fpga" onClick={() => scrollToSection('fpga')}>FPGA & Toolchain</li>
                  <li data-target="verification" onClick={() => scrollToSection('verification')}>RISCOF Verification</li>
                  <li data-target="structure" onClick={() => scrollToSection('structure')}>Project Structure</li>
                </ul>
              </div>
              <br />
              <div className="nav-group">
                <span className="nav-label">04 CONTRIBUTE</span>
                <ul>
                  <li data-target="build" onClick={() => scrollToSection('build')}>Repository</li>
                </ul>
              </div>
            </nav>
          </aside>

          <main className="docs-scroll-content" ref={scrollContainerRef}>
            
            <section id="abstract" className="docs-section-anchor">
              <div className="docs-glass-card">
                <h2 className="docs-primary-h">Introduction</h2>
                <p className="docs-para">
                    eSC-V is a 5-stage pipelined RV32I Zicsr Zicfilp Smcfiss Smpmpind RISC-V SoC implemented entirely in VHDL. It is designed to provide hardware-enforced Control-Flow Integrity (CFI) for bare-metal, M-mode microcontrollers. To protect against Return-Oriented Programming (ROP) and Jump-Oriented Programming (JOP) , the core integrates the Zicfilp extension for forward-edge protection and the draft Smcfiss and Smpmpind extensions to enforce a hardware shadow stack.
                    <br /><br />
                    The SoC has a dual-port unified memory controller that synthesizes to BRAM, a UART for communication, and has been verified against Sail and Spike formal models using the RISC-V Compatibility Framework (RISCOF).
                    <br /><br />
                   The complete tooling is open source, and the FPGA used is the Tang Primer 20K, running at 60 MHz with an open-source (reverse-engineered) bitstream. Nix is used to keep the development environment consistent and to manage the custom GCC toolchain required for compiling the CFI extensions.
                </p>
              </div>
            </section>

            <br />

            <section id="pipeline" className="docs-section-anchor">
              <div className="docs-glass-card">
                <h2 className="docs-primary-h">Hardware Architecture</h2>
                <p className="docs-para">
                  The microarchitecture follows the standard <strong>IF-ID-EX-MEM-WB</strong> organization. 
                  CFI primitives are modularly separated across these stages to ensure peak throughput 
                  while maintaining cycle-accurate security validation of control transfers.
                </p>
                
                <div className="docs-image-container">
                    <img src={pipelineImg} alt="eSC-V Pipeline" className="docs-pipeline-img" />
                    <p className="image-caption">Fig 1. Baseline 5-stage RV32I pipeline organization used in eSC-V.</p>
                </div>

                <div className="docs-feature-grid">
                  <div className="feature-item">
                    <h4>Fetch (IF)</h4>
                    <p>Detects Zicfilp violations and redirects PC immediately to <code>mtvec</code>.</p>
                  </div>
                  <div className="feature-item">
                    <h4>Decode (ID)</h4>
                    <p>Reconstructs 20-bit labels and generates dedicated control signals for shadow stack ops.</p>
                  </div>
                  <div className="feature-item">
                    <h4>Execute (EX)</h4>
                    <p>Implements label hardware comparators and manages Landing-Pad-Enabled tracking.</p>
                  </div>
                  <div className="feature-item">
                    <h4>Memory (MEM)</h4>
                    <p>Enforces shadow stack integrity via PMP-like access rules.</p>
                  </div>
                </div>
              </div>
            </section>

            <br />

            {/* NEW STATS SECTION ADDED HERE */}
            <section id="synthesis-stats" className="docs-section-anchor">
              <div className="docs-glass-card">
                <h2 className="docs-primary-h">Synthesis Statistics</h2>
                <p className="docs-para">
                  Comparative analysis between the baseline RV32I core and the CFI-hardened eSC-V implementation. 
                  The metrics highlight the minimal hardware overhead required for robust control-flow security.
                </p>
                <div className="stats-table-wrapper">
                  <table className="docs-stats-table">
                    <thead>
                      <tr>
                        <th>Parameter</th>
                        <th>Baseline</th>
                        <th>CFI-Enabled</th>
                        <th>Growth/Penalty</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <td>LUTs Utilization</td>
                        <td>7,527 cells</td>
                        <td>8,066 cells</td>
                        <td className="stat-penalty">+6.68% Area</td>
                      </tr>
                      <tr>
                        <td>Max Frequency</td>
                        <td>58 MHz</td>
                        <td>54 MHz</td>
                        <td className="stat-penalty">-6.89% Speed</td>
                      </tr>
                      <tr>
                        <td>Binary Size</td>
                        <td>19,072 Bytes</td>
                        <td>22,853 Bytes</td>
                        <td className="stat-penalty">+19.82% Size</td>
                      </tr>
                      <tr>
                        <td>Total Registers</td>
                        <td>2,461 cells</td>
                        <td>2,469 cells</td>
                        <td className="stat-penalty">+0.33% Registers</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <div className="docs-info-box" style={{ marginTop: '2rem' }}>
                  <span className="box-label">PERFORMANCE INSIGHT</span>
                  <p className="docs-para" style={{ marginBottom: 0, fontSize: '0.95rem' }}>
                    The hardware shadow stack and landing pad enforcement logic only consume a marginal 6.68% additional 
                    FPGA area. The frequency impact is kept under 7%, ensuring real-time performance is preserved.
                  </p>
                </div>
              </div>
            </section>

            <br />

            <section id="security-lab" className="docs-section-anchor">
              <div className="docs-glass-card">
                <h2 className="docs-primary-h">Security Mechanisms</h2>
                <p className="docs-para">
                  Control Flow Hijacking attacks redirect the processor's execution to malicious paths. 
                  eSC-V provides dedicated hardware-level defenses against both Forward-Edge and Backward-Edge redirection.
                </p>

                <h3 className="docs-h3">Forward-Edge Protection (Zicfilp)</h3>
                <p className="docs-para">
                  Forward-edge attacks, such as Jump-Oriented Programming (JOP), target indirect branches 
                  like function pointers. Attackers corrupt these pointers to force a jump to a malicious "gadget."
                  <br /><br />
                  <strong>Defense:</strong> The Zicfilp extension enforces Landing Pads. Any indirect 
                  jump must land on a valid <code>lpad</code> instruction with a matching label.
                </p>

                <br /><br />

                <h3 className="docs-h3">Backward-Edge Protection (Smcfiss)</h3>
                <p className="docs-para">
                  Backward-edge attacks, primarily Return-Oriented Programming (ROP), exploit stack 
                  vulnerabilities to overwrite the return address.
                  <br /><br />
                  <strong>Defense:</strong> The Smcfiss extension implements a Hardware Shadow Stack. 
                  Return addresses are stored in a protected region and verified during returns 
                  via <code>sspush</code> and <code>sspopchk</code>.
                </p>

                <div className="docs-animation-container rop-container">
                  <div className="animation-header">
                    <span className="live-tag">LIVE SIMULATION</span>
                    <span>ATTACK VECTOR: STACK OVERFLOW ROP</span>
                  </div>
                  <iframe 
                    src="/rop-animation.html" 
                    title="ROP Animation"
                    className="docs-iframe rop-frame"
                    style={{ width: '90%', height: '300px', border: 'none', display: 'block' }}
                  />
                </div>

                <div className="docs-warning-box">
                  <span className="warning-tag">IMMUTABILITY RULE</span>
                  Shadow stack memory is protected from regular store instructions. 
                  Only dedicated hardware instructions may modify this region.
                </div>
              </div>
            </section>

            <br />

            <section id="fpga" className="docs-section-anchor">
              <div className="docs-glass-card">
                <h2 className="docs-primary-h">FPGA Deployment & Toolchain</h2>
                <p className="docs-para">
                  We have used the <strong>Nix</strong> package manager to deploy the following 
                  software tools and ensure a reproducible environment.
                </p>
                <div className="docs-info-box">
                  <span className="box-label">SOFTWARE TOOLS</span>
                  <ul>
                    <li><strong>Yosys:</strong> RTL synthesis</li>
                    <li><strong>Nextpnr:</strong> Place & Route</li>
                    <li><strong>Project Apicula:</strong> Bitstream generation</li>
                    <li><strong>RISCOF:</strong> ISA compliance verification</li>
                    <li><strong>Spike/Sail:</strong> Golden reference model</li>
                  </ul>
                </div>
                <br />
                <div className="docs-info-box">
                  <span className="box-label">HARDWARE SPECIFICATIONS</span>
                  <ul>
                    <li><strong>FPGA Board:</strong> Sipeed Tang Primer 20K</li>
                    <li><strong>FPGA Model:</strong> Gowin GW2A-LV18PG256C8/I7</li>
                    <li><strong>Operating Frequency:</strong> 60 MHz Stable</li>
                    <li><strong>Logic Resources:</strong> ~20k LUTs & 15k Flip-Flops</li>
                  </ul>
                </div>
              </div>
            </section>

            <br />

            <section id="verification" className="docs-section-anchor">
              <div className="docs-glass-card">
                <h2 className="docs-primary-h">RISCOF Verification</h2>
                <p className="docs-para">
                  ISA compliance is validated using the RISC-V Compatibility Framework. 
                  Behavior is compared against <strong>Spike</strong> or <strong>Sail</strong> golden 
                  models to ensure architectural consistency during security traps.
                </p>
              </div>
            </section>

            <br />

            <section id="structure" className="docs-section-anchor">
              <div className="docs-glass-card">
                <h2 className="docs-primary-h">Project Structure</h2>
                <div className="docs-tree">
                  <pre>
                    {`eSC-V/
├── constraints/           # FPGA constraint files
│   └── fpga.cst
├── docs/                  # Documentation and diagrams
│   ├── dev_docs/
│   ├── pipeline.png
│   └── specifications/
├── software/              # Software and firmware
│   ├── apps
│   ├── common
│   ├── drivers
│   ├── Makefile
│   └── tests
├── src/                   # VHDL module implementations
│   ├── core.vhd
│   ├── soc.vhd
│   ├── IF_stage/
│   ├── ID_stage/
│   ├── EX_stage/
│   └── ...
├── tb/                    # Testbench files
│   ├── tb_soc.vhd
│   └── tb_soc_riscof.vhd
├── verification/          # Verification frameworks
│   └── riscof/
├── Makefile               # Build and simulation commands
├── flake.nix              # Nix development environment
└── README.md              # Project documentation`}
                  </pre>
                </div>
              </div>
            </section>

            <br />

            <section id="build" className="docs-section-anchor">
              <div className="docs-glass-card">
                <div className="docs-info-box" style={{ margin: 0 }}>
                    <span className="box-label">Repository</span>
                    <p className="docs-para" style={{ marginBottom: 0 }}>
                      Access the full VHDL source code, documentation, and software tests here: <br />
                      <a 
                        href="https://github.com/ethycS0/eSC-V" 
                        target="_blank" 
                        rel="noopener noreferrer" 
                        style={{ color: '#00f0ff', textDecoration: 'underline', fontWeight: 800 }}
                      >
                        github.com/ethycS0/eSC-V
                      </a>
                    </p>
                  </div>
              </div>
            </section>
            <br /><br />
          </main>
        </div>
      </div>
    </div>
  )
}

export default DocsPage