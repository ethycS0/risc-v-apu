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
            vhdl-ls
            ghdl
            gtkwave
            yosys
            yosys-ghdl
            gnumake
            python312
            python312Packages.riscof
            python312Packages.distutils
            pandoc
            graphviz
            netlistsvg
            texlive.combined.scheme-full
            sail-riscv
            spike
            dtc
            asm-lsp
            clang
            autoconf
            automake
            libtool
            patchutils
            gcc
            cmake
            ninja
            pkg-config
            gawk
            bison
            flex
            texinfo
            gperf
            bc
            libmpc
            mpfr
            gmp
            zlib
            expat
            curl
            wget
            git
            util-linux
            binutils
          ];

          shellHook = ''
            export PATH=$PWD/toolchain/bin:$PATH
            if command -v zsh &> /dev/null; then
              exec zsh
            fi
          '';
        };
      }
    );
}
