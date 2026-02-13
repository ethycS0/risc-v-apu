import os
import shutil
import subprocess
import shlex
import logging
import riscof.utils as utils
from riscof.pluginTemplate import pluginTemplate

logger = logging.getLogger()


class eSC_V(pluginTemplate):
    __model__ = "eSC_V"
    __version__ = "1.0"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        config = kwargs.get("config")

        self.dut_exe = os.path.join(config["PATH"] if "PATH" in config else "", "eSC_V")
        self.num_jobs = str(config["jobs"] if "jobs" in config else 1)
        self.pluginpath = os.path.abspath(config["pluginpath"])
        self.isa_spec = os.path.abspath(config["ispec"])
        self.platform_spec = os.path.abspath(config["pspec"])
        self.target_run = config.get("target_run") != "0"

    def initialise(self, suite, work_dir, archtest_env):
        self.work_dir = work_dir
        self.suite_dir = suite

        # 1. PATH SETUP: Get the absolute path to your VHDL project root
        self.vhdl_root = os.path.abspath(os.path.join(self.pluginpath, "../../.."))

        # 2. VHDL COMPILATION
        # We compile here to ensure 'work-obj08.cf' is created with ABSOLUTE PATHS
        logger.info("Compiling VHDL design units...")

        # A. Compile Package First
        pkg_file = os.path.join(self.vhdl_root, "src/common.vhd")
        analyze_cmd = f"ghdl -a --std=08 -frelaxed --workdir={work_dir} {pkg_file}"
        utils.shellCommand(analyze_cmd).run(cwd=work_dir)

        # B. Compile Source Files (Order matches your Makefile)
        src_files = [
            # Common (Compile first)
            "src/common.vhd",
            # Core
            "src/core.vhd",
            "src/hazard_detection_unit.vhd",
            # IF Stage
            "src/IF_stage/instruction_fetch_stage.vhd",
            # ID Stage
            "src/ID_stage/id_control_unit.vhd",
            "src/ID_stage/immediate_reconstruct_unit.vhd",
            "src/ID_stage/instruction_decode_stage.vhd",
            "src/ID_stage/register_file.vhd",
            # EX Stage
            "src/EX_stage/alu.vhd",
            "src/EX_stage/branch_adder.vhd",
            "src/EX_stage/branch_control_unit.vhd",
            "src/EX_stage/csr_unit.vhd",
            "src/EX_stage/ex_control_unit.vhd",
            "src/EX_stage/execution_stage.vhd",
            "src/EX_stage/forwarding_unit.vhd",
            # MEM Stage
            "src/MEM_stage/memory_stage.vhd",
            # WB Stage
            "src/WB_stage/writeback_stage.vhd",
            # Memory
            "src/unified_memory_unit.vhd",
            # UART
            "src/uart.vhd",
            # SoC
            "src/soc.vhd",
            # Testbench
            "tb/tb_soc_riscof.vhd",
        ]

        for src in src_files:
            full_path = os.path.join(self.vhdl_root, src)
            # Added -frelaxed because common.vhd usually needs it
            analyze_cmd = f"ghdl -a --std=08 -frelaxed --workdir={work_dir} {full_path}"
            utils.shellCommand(analyze_cmd).run(cwd=work_dir)

        # C. Elaborate
        elaborate_cmd = f"ghdl -e --std=08 -frelaxed --workdir={work_dir} tb_soc_riscof"
        utils.shellCommand(elaborate_cmd).run(cwd=work_dir)

        logger.info("VHDL compilation complete.")

        # 3. COMPILER SETUP
        self.compile_cmd = (
            f"riscv32-unknown-elf-gcc -march={{0}} -mabi=ilp32 "
            "-static -mcmodel=medany -fvisibility=hidden "
            "-nostdlib -nostartfiles -fno-plt -fno-pic -g "
            f"-T {self.pluginpath}/env/link.ld "
            f"-I {self.pluginpath}/env/ "
            f"-I {archtest_env} {{1}} -o {{2}} {{3}}"
        )
        logger.info(f"Using Linker Script at: {self.pluginpath}/env/link.ld")

    def build(self, isa_yaml, platform_yaml):
        ispec = utils.load_yaml(isa_yaml)["hart0"]
        self.xlen = "64" if 64 in ispec["supported_xlen"] else "32"

    def runTests(self, testList):
        def to_signed32(n):
            n = n & 0xFFFFFFFF
            return (n - 0x100000000) if n > 0x7FFFFFFF else n

        for file in testList:
            testentry = testList[file]
            test = testentry["test_path"]
            test_dir = testentry["work_dir"]

            elf = "mycpu.elf"
            hex_file = "code.hex"
            sig_file = "signature.output"
            wave_file = "sim.ghw"

            # Setup ISA String
            march_string = "rv32i_zicsr"

            # STEP 1: Compile Test to ELF
            compile_macros = " -D" + " -D".join(testentry["macros"])
            cmd = self.compile_cmd.format(march_string, test, elf, compile_macros)

            try:
                utils.shellCommand(cmd).run(cwd=test_dir)
            except Exception as e:
                logging.error(f"Compilation failed for {test}: {e}")
                continue

            if not self.target_run:
                continue

            # STEP 2: Create Hex File
            bin_file = os.path.join(test_dir, "mem.bin")
            objcopy_cmd = f"riscv32-unknown-elf-objcopy -O binary " f"{elf} {bin_file}"
            utils.shellCommand(objcopy_cmd).run(cwd=test_dir)

            if os.path.exists(bin_file):
                with open(bin_file, "rb") as f_bin, open(
                    os.path.join(test_dir, hex_file), "w"
                ) as f_hex:
                    byte_content = f_bin.read()
                    for i in range(0, len(byte_content), 4):
                        chunk = byte_content[i : i + 4]
                        if len(chunk) == 4:
                            val = int.from_bytes(chunk, byteorder="little")
                            f_hex.write(f"{val:08x}\n")
                        else:
                            val = int.from_bytes(
                                chunk + b"\x00" * (4 - len(chunk)), byteorder="little"
                            )
                            f_hex.write(f"{val:08x}\n")
            else:
                logging.error(f"Binary generation failed for {test}")
                continue

            # STEP 3: Extract Signature Addresses
            nm_cmd = f"riscv32-unknown-elf-nm {elf}"
            try:
                output = subprocess.check_output(
                    shlex.split(nm_cmd), cwd=test_dir
                ).decode("utf-8")
            except Exception as e:
                logging.error(f"nm failed for {test}: {e}")
                continue

            sig_begin = None
            sig_end = None
            mem_base = 0x00000000
            tohost = 0

            # Parse nm output once for all symbols
            for line in output.splitlines():
                parts = line.split()
                if len(parts) >= 3:
                    addr = int(parts[0], 16)
                    symbol = parts[2]

                    if "begin_signature" in symbol:
                        sig_begin = addr
                    elif "end_signature" in symbol:
                        sig_end = addr
                    elif "tohost" in symbol:
                        tohost = addr

            # Fallback safety
            if sig_begin is None:
                sig_begin = mem_base
            if sig_end is None:
                sig_end = mem_base + 4
            if tohost is None:
                tohost = 0

            sig_start_offset = sig_begin - mem_base
            sig_end_offset = sig_end - mem_base
            term_offset = (tohost - mem_base) if tohost >= mem_base else 0

            # STEP 4: Copy the GHDL library file
            work_file = os.path.join(self.work_dir, "work-obj08.cf")
            if os.path.exists(work_file):
                shutil.copy(work_file, test_dir)

            # STEP 5: Run Simulation
            ghdl_cmd_list = [
                "ghdl",
                "-r",
                "--std=08",
                "-frelaxed",
                f"--workdir={test_dir}",
                "tb_soc_riscof",
                f"-gG_IMEM_FILENAME={hex_file}",
                f"-gG_SIG_FILENAME={sig_file}",
                f"-gG_SIG_START_OFFSET={sig_start_offset}",
                f"-gG_SIG_END_OFFSET={sig_end_offset}",
                f"-gG_TERMINATION_OFFSET={term_offset}",
                f"--wave={wave_file}",
                # "--stop-time=2ms",
            ]

            logger.debug(f"Running: {' '.join(ghdl_cmd_list)}")
            proc = None

            try:
                proc = subprocess.run(
                    ghdl_cmd_list, cwd=test_dir, capture_output=True, text=True
                )

                if not os.path.exists(os.path.join(test_dir, sig_file)):
                    logging.error(f"\n[FAIL] Test: {test}")
                    logging.error("--- GHDL STDOUT (VHDL Reports) ---")
                    if proc:
                        logging.error(proc.stdout)
                        logging.error("--- GHDL STDERR (System Errors) ---")
                        logging.error(proc.stderr)
                    logging.error("----------------------------------")

            except Exception as e:
                logging.error(f"Execution Error for {test}: {e}")
                if proc:
                    logging.error(proc.stdout)
                    logging.error(proc.stderr)
                continue

            src_sig = os.path.join(test_dir, sig_file)
            target_sig = os.path.join(test_dir, f"DUT-{self.__model__}.signature")

            if os.path.exists(src_sig):
                with open(src_sig, "r") as f_in:
                    lines = f_in.readlines()

                if lines and lines[-1].strip() == "00000000":
                    lines.pop()

                with open(target_sig, "w") as f_out:
                    for line in lines:
                        f_out.write(line.lower())

                testentry["dut_signature"] = target_sig
            else:
                logging.error(f"No signature generated for {test}")
                with open(target_sig, "w") as f:
                    sig_size = (sig_end - sig_begin) // 4 if sig_end > sig_begin else 1

                    for _ in range(max(1, sig_size)):
                        f.write("ffffffff\n")

                testentry["dut_signature"] = target_sig
                logging.warning(f"Created dummy signature for failed test: {test}")
