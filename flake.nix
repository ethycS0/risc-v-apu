{
  description = "RISC-V VHDL Development Environment with GHDL and GTKWave";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            vhdl-ls
            # Core VHDL simulation tools
            ghdl # VHDL simulator
            gtkwave # Waveform viewer
            # Synthesis tools (for future use)
            yosys # Logic synthesizer
            # Development tools
            gnumake # Build automation
            python3 # Scripting support
            python3Packages.matplotlib # For plotting/analysis
            python3Packages.numpy # Numerical computing
            # Documentation tools
            pandoc # Document conversion
            graphviz # Diagram generation
          ];
          shellHook = ''
            echo "🚀 RISC-V VHDL Development Environment"
            echo "====================================="
            echo ""
            echo "Available tools:"
            echo "  • ghdl      - VHDL simulator"
            echo "  • gtkwave   - Waveform viewer"
            echo "  • yosys     - Logic synthesizer"
            echo "  • python3   - Scripting & analysis"
            echo ""
            echo "Quick start:"
            echo "  1. Write your VHDL files"
            echo "  2. ghdl -a design.vhd"
            echo "  3. ghdl -a testbench.vhd"
            echo "  4. ghdl -e testbench"
            echo "  5. ghdl -r testbench --vcd=sim.vcd"
            echo "  6. gtkwave sim.vcd"
            echo ""
            echo "GHDL version: $(ghdl --version | head -n1)"
            echo "GTKWave version: $(gtkwave --version 2>/dev/null || echo 'Available')"
            echo ""
            export SHELL=${pkgs.zsh}/bin/zsh
            echo "Using zsh shell"
            exec ${pkgs.zsh}/bin/zsh
          '';
          GHDL_STD = "08";
        };
      }
    );
}
