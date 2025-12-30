{
  description = "RISC-V VHDL Development Environment";
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
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Language Runtimes
            python312

            # Language Servers
            vhdl-ls
            asm-lsp

            # Compilation & Simulation
            ghdl
            gtkwave

            # Synthesis & Implementation
            yosys
            yosys-ghdl
            nextpnr
            python312Packages.apycula
            openfpgaloader

            # Verification & Compliance
            python312Packages.riscof
            python312Packages.distutils
            sail-riscv

            # Documentation
            texlive.combined.scheme-full

            # Build Toolchains
            pkgsCross.riscv32-embedded.stdenv.cc
            clang
            gnumake

            # Serial Interface
            screen

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
