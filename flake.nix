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

        mkToolchain =
          name: url: sha256:
          pkgs.stdenvNoCC.mkDerivation {
            inherit name;
            src = pkgs.fetchurl { inherit url sha256; };

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

        standard-toolchain =
          mkToolchain "rv32i-zicsr-toolchain"
            "https://github.com/ethycS0/eSC-V/releases/download/Toolchain/rv32i-zicsr-toolchain.tar.gz"
            "sha256:3e7634ae400d834ae510a2057e525400fe14356aeba5dde2bb1457f70d3779cd";

        zicfilp-toolchain =
          mkToolchain "rv32i-zicfilp-zicsr-toolchain"
            "https://github.com/ethycS0/eSC-V/releases/download/CFI_LPAD_toolchain/rv32i-zicfilp-zicsr-toolchain.tar.gz"
            "sha256:e60bf58303bc5b60419e94b2e65dac20d310d1a613a0bf3cd71de0936a64b46a";

        commonPackages = with pkgs; [
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

          # Build Tools
          clang
          gnumake
          bear
          flex

          # Serial Interface
          screen
          xxd
        ];

        mkDevShell =
          toolchain:
          pkgs.mkShell {
            buildInputs = commonPackages ++ [ toolchain ];
            shellHook = ''
              export PATH="${toolchain}/bin:$PATH"
              echo "Environment loaded with: ${toolchain.name}"
            '';
          };

      in
      {
        packages = {
          default = standard-toolchain;
          standard = standard-toolchain;
          zicfilp = zicfilp-toolchain;
        };

        devShells = {
          default = mkDevShell standard-toolchain;
          zicfilp = mkDevShell zicfilp-toolchain;
        };
      }
    );
}
