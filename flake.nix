{
  description = "RISC-V VHDL Development Environment with GHDL and GTKWave";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
        riscvPkgs =
          (import nixpkgs {
            inherit system;
            crossSystem = {
              config = "riscv32-unknown-linux-gnu";
            };
          }).buildPackages;
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
            yosys-ghdl
            gnumake # Build automation
            python312
            python312Packages.riscof
            python312Packages.distutils

            # Documentation tools
            pandoc # Document conversion
            graphviz # Diagram generation
            netlistsvg

            texlive.combined.scheme-full

            riscvPkgs.gcc
            riscvPkgs.gdb

            sail-riscv
            spike
          ];
          shellHook = ''
            if command -v zsh &> /dev/null; then
              exec zsh
            fi
          '';

        };
      }
    );
}
