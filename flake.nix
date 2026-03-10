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
            "https://github.com/ethycS0/eSC-V/releases/download/rv32i_zicsr/rv32i-zicsr-toolchain.tar.gz"
            "sha256:3e7634ae400d834ae510a2057e525400fe14356aeba5dde2bb1457f70d3779cd";

        cfi-toolchain =
          mkToolchain "rv32i-zicsr-zicfilp-zicfiss-toolchain"
            "https://github.com/ethycS0/eSC-V/releases/download/rv32i_zicsr_zicfilp_zicfiss/rv32i-zicsr-zicfilp-zicfiss-toolchain.tar.gz"
            "sha256:2420d0031b14537c327da600fd047a066e1ca0e7c12811caaf7144cc0827e1f5";

        commonPackages = with pkgs; [
          # Language Runtimes
          python312
          python312Packages.pyserial

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
          cfi = cfi-toolchain;
        };

        devShells = {
          default = mkDevShell standard-toolchain;
          cfi = mkDevShell cfi-toolchain;
        };
      }
    );
}
