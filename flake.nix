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
        toolchain = pkgs.stdenvNoCC.mkDerivation {
          name = "toolchain";
          src = pkgs.fetchurl {
            url = "https://github.com/ethycS0/eSC-V/releases/download/toolchain/toolchain.tar.gz";
            sha256 = "sha256:5b82aa9e830b5bed4a2ac2b1b5b8ea2c6fb3b4a8f477e84c618efbe8f848129a";
          };
          sourceRoot = ".";
          dontBuild = true;
          dontConfigure = true;
          dontPatchELF = true;
          dontStrip = true;
          dontFixup = true;
          installPhase = ''
            mkdir -p $out
            if [ -d "bin" ]; then
              cp -r ./* $out/
            else
              cd */
              cp -r ./* $out/
            fi
            chmod +x $out/bin/* 2>/dev/null || true
          '';
        };
        commonPackages = with pkgs; [
          # Language Runtimes
          python312
          python312Packages.pyserial
          nodejs_24

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
          spike
          dtc

          # Documentation
          texlive.combined.scheme-full
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
        packages.default = toolchain;
        devShells.default = pkgs.mkShell {
          buildInputs = commonPackages ++ [ toolchain ];
          shellHook = ''
            export PATH="${toolchain}/bin:$PATH"
            echo "Environment loaded with: ${toolchain.name}"
          '';
        };
      }
    );
}
