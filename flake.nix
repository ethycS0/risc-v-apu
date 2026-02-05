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

        riscv32i-toolchain = pkgs.stdenvNoCC.mkDerivation {
          name = "riscv32-rv32i-zicsr-toolchain";

          src = pkgs.fetchurl {
            url = "https://github.com/ethycS0/eSC-V/releases/download/Toolchain/riscv32-rv32i-zicsr-toolchain.tar.gz";
            sha256 = "sha256:3e7634ae400d834ae510a2057e525400fe14356aeba5dde2bb1457f70d3779cd";
          };

          sourceRoot = ".";

          dontBuild = true;
          dontConfigure = true;

          installPhase = ''
            mkdir -p $out
            cp -r ./* $out/ || cp -r * $out/
            chmod +x $out/bin/* 2>/dev/null || true
          '';

          dontPatchELF = true;
          dontStrip = true;
          dontFixup = true;
        };

      in
      {
        packages.riscv32i-toolchain = riscv32i-toolchain;

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
            doxygen

            # Build Toolchains
            riscv32i-toolchain
            clang
            gnumake
            bear

            # Serial Interface
            screen
            xxd
          ];

          shellHook = ''
            export PATH="${riscv32i-toolchain}/bin:$PATH"
          '';
        };
      }
    );
}
