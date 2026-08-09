{
  description = "RISC-V VHDL Development Environment";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    riscv-toolchains.url = "github:ethycS0/nix-riscv-toolchains";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      riscv-toolchains,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        toolchain = riscv-toolchains.packages.${system}.rv32i-cfi;

        commonPackages = with pkgs; [
          # Languages
          python312
          python312Packages.pyserial
          python312Packages.websockets
          nodejs_24

          # Language Servers
          vhdl-ls
          asm-lsp

          # Compilation & Simulation
          ghdl
          gtkwave

          # Synthesis & Implementation
          (pkgs.yosys.withPlugins [ pkgs.yosys-ghdl ])
          nextpnr
          python312Packages.apycula
          openfpgaloader

          # Verification & Compliance
          python312Packages.riscof
          python312Packages.distutils
          sail-riscv
          spike
          dtc

          # Documentation
          texliveFull
          doxygen

          # Build Tools
          clang
          gnumake
          bear
          flex

          # Serial Interface
          screen
          xxd
        ];
      in
      {
        devShells.default = pkgs.mkShell {

          packages = commonPackages ++ [ toolchain ];
          env = toolchain.envVars;
          shellHook = ''
            export NIX_YOSYS_PLUGIN_DIRS="${pkgs.yosys-ghdl}/share/yosys/plugins"
          '';
        };
      }
    );
}
