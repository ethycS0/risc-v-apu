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
            if [ -x "${pkgs.zsh}/bin/zsh" ]; then
              export SHELL=${pkgs.zsh}/bin/zsh
              echo "Using zsh shell"
              exec ${pkgs.zsh}/bin/zsh
            else
              echo "zsh not found, skipping shell switch"
            fi
          '';

          GHDL_STD = "08";
        };
      }
    );
}
