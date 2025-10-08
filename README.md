# Contributing to the RISC-V APU Project

**Contribution & Project Diary Notice**

Following this workflow is essential. All commits are logged and will be used to create a detailed contribution map for the final project diary. This ensures a clear and accurate progress report of the entire project.

- **Contribution Record:** All work must be submitted via pull requests. This creates a permanent record of who contributed what and when.
- **Automated Project Diary:** The Git log serves as our official project diary. Your commit messages will directly inform the final progress report.

## 1. Setting Up Your Development Environment

This project uses Nix to provide a consistent development environment with all the necessary tools.

### Install Nix

First, install Nix on your system (Linux, macOS, or WSL on Windows) using the Determinate Systems installer, which is the recommended method:

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate
```

## 2. Getting the Code

This project uses the fork-and-pull-request workflow.

### Fork the Repository

1. Click the "Fork" button at the top right of the main repository page: [https://github.com/ethycS0/risc-v-apu](https://github.com/ethycS0/risc-v-apu)

### Clone Your Fork

Clone your forked repository to your local machine. Replace `your_github_username` with your actual username.

```bash
git clone git@github.com:your_github_username/risc-v-apu.git
cd risc-v-apu  # This is your Project Root
```

## 3. The Development Workflow

All development work should be done within the Nix development shell.

### Activate the Environment

From the project's root directory, run the following command. You must do this every time you open a new terminal to work on the project.

```bash
nix develop
```

This command will make all required tools (`GHDL`, `GTKWave`, etc.) available in your shell.

### Implement Your Code

- Place new module implementations (e.g., `module.vhd`) in the `src/` directory.
- Place corresponding testbenches (e.g., `tb_module.vhd`) in the `tb/` directory.

### Build and Test

Use the provided `Makefile` to simulate your design.

#### Run a simulation

```bash
make run TB=tb_module
```

Replace `tb_module` with the name of your testbench file, without the `.vhd` extension.

#### View waveforms

After running a simulation, you can view the resulting waveforms with GTKWave:

```bash
make view TB=tb_module
```

## 4. Submitting Your Contribution

Once your implementation is working correctly and fully tested, please follow these steps to submit a pull request.

### Clean the Project

**Always** run the clean command before committing to remove generated simulation files.

```bash
make clean
```

### Commit and Push Your Changes

Stage, commit, and push your changes to your forked repository. It is a best practice to create a new branch for your feature.

```bash
git add .
git commit -m "feat: Implement the ALU and its testbench"  # Change Message to Implementation Details
git push origin main
```

### Create a Pull Request

1. Go to your forked repository on GitHub (`https://github.com/your_github_username/risc-v-apu`).
2. You should see a prompt to "Contribute" and "Open a pull request." Click it.
3. Provide a clear title and a detailed description of your changes in the pull request.
4. The maintainer will review the pull request and may request changes. If so, simply make the required changes, commit, and push them to your branch again. The pull request will update automatically.

## Project Structure

```
risc-v-apu/
├── src/           # VHDL module implementations
├── tb/            # Testbench files
├── Makefile       # Build and simulation commands
├── flake.nix      # Nix development environment configuration
└── README.md      # Project documentation
```

## Best Practices

### Commit Messages

Follow conventional commit format for clear version history:

- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation changes
- `test:` for adding or modifying tests
- `refactor:` for code refactoring

Example:

```bash
git commit -m "feat: implement instruction decoder module"
git commit -m "test: add comprehensive ALU testbench"
git commit -m "fix: correct sign extension in immediate decoder"
```

### Code Quality

- Write clean, well-commented VHDL code
- Follow consistent naming conventions
- Create comprehensive testbenches for all modules
- Verify simulation results before submitting PRs
- Always run `make clean` before committing

### Testing

- Test edge cases and boundary conditions
- Verify timing constraints
- Check for proper signal initialization
- Validate against RISC-V ISA specifications

## Tools Used

- **GHDL**: Open-source VHDL simulator
- **GTKWave**: Waveform viewer
- **Nix**: Reproducible development environment
- **Make**: Build automation
- **Git**: Version control

## Getting Help

If you encounter issues:

1. Check existing issues on the repository
2. Review the RISC-V specification for reference
3. Ensure your Nix environment is properly configured
4. Verify all dependencies are available in the dev shell

## Resources

- [RISC-V Specification](https://riscv.org/technical/specifications/)
- [GHDL Documentation](https://ghdl.github.io/ghdl/)
- [GTKWave Documentation](http://gtkwave.sourceforge.net/)
- [Nix Manual](https://nixos.org/manual/nix/stable/)

---

**Repository:** [https://github.com/ethycS0/risc-v-apu](https://github.com/ethycS0/risc-v-apu)

**License:** Check repository for license details

**Maintainer:** ethycS0
