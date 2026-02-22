import os
import re
import shutil
import subprocess
import shlex
import logging
import random
import string
from string import Template

import riscof.utils as utils
import riscof.constants as constants
from riscof.pluginTemplate import pluginTemplate
from riscv_isac.isac import isac

logger = logging.getLogger()


class spike(pluginTemplate):
    __model__ = "spike"
    __version__ = "1.0"

    def __init__(self, *args, **kwargs):
        sclass = super().__init__(*args, **kwargs)

        config = kwargs.get("config")
        if config is None:
            logger.error("Config node for spike missing.")
            raise SystemExit(1)

        self.num_jobs = str(config["jobs"] if "jobs" in config else 1)
        self.pluginpath = os.path.abspath(config["pluginpath"])

        # mimicking the dictionary structure from sail, though spike usually uses one binary
        path_to_spike = config["PATH"] if "PATH" in config else ""
        self.spike_exe = {
            "32": os.path.join(path_to_spike, "spike"),
            "64": os.path.join(path_to_spike, "spike"),
        }

        self.isa_spec = os.path.abspath(config["ispec"]) if "ispec" in config else ""
        self.platform_spec = (
            os.path.abspath(config["pspec"]) if "ispec" in config else ""
        )
        self.make = config["make"] if "make" in config else "make"

        logger.debug("Spike plugin initialised using the following configuration.")
        for entry in config:
            logger.debug(entry + " : " + config[entry])
        return sclass

    def initialise(self, suite, work_dir, archtest_env):
        self.suite = suite
        self.work_dir = work_dir
        self.objdump_cmd = "riscv{1}-unknown-elf-objdump -D {0} > {2};"
        self.compile_cmd = (
            "riscv{1}-unknown-elf-gcc -march={0} \
         -static -mcmodel=medany -mno-relax -fvisibility=hidden -nostdlib -nostartfiles\
         -T "
            + self.pluginpath
            + "/env/link.ld\
         -I "
            + self.pluginpath
            + "/env/\
         -I "
            + archtest_env
        )

    def build(self, isa_yaml, platform_yaml):
        ispec = utils.load_yaml(isa_yaml)["hart0"]
        self.xlen = "64" if 64 in ispec["supported_xlen"] else "32"
        self.isa = "rv" + self.xlen

        self.compile_cmd = (
            self.compile_cmd
            + " -mabi="
            + ("lp64 " if 64 in ispec["supported_xlen"] else "ilp32 ")
        )

        # Build ISA string exactly like Sail
        if "I" in ispec["ISA"]:
            self.isa += "i"

        # Robust Environment Checks (Copied from Sail logic)
        objdump = "riscv{0}-unknown-elf-objdump".format(self.xlen)
        if shutil.which(objdump) is None:
            logger.error(
                objdump + ": executable not found. Please check environment setup."
            )
            raise SystemExit(1)

        compiler = "riscv{0}-unknown-elf-gcc".format(self.xlen)
        if shutil.which(compiler) is None:
            logger.error(
                compiler + ": executable not found. Please check environment setup."
            )
            raise SystemExit(1)

        if shutil.which(self.spike_exe[self.xlen]) is None:
            logger.error(
                self.spike_exe[self.xlen]
                + ": executable not found. Please check environment setup."
            )
            raise SystemExit(1)

        if shutil.which(self.make) is None:
            logger.error(
                self.make + ": executable not found. Please check environment setup."
            )
            raise SystemExit(1)

    def runTests(self, testList, cgf_file=None):
        if os.path.exists(self.work_dir + "/Makefile." + self.name[:-1]):
            os.remove(self.work_dir + "/Makefile." + self.name[:-1])

        make = utils.makeUtil(
            makefilePath=os.path.join(self.work_dir, "Makefile." + self.name[:-1])
        )

        make.makeCommand = self.make + " -j" + self.num_jobs

        for file in testList:
            testentry = testList[file]
            test = testentry["test_path"]
            test_dir = testentry["work_dir"]
            test_name = test.rsplit("/", 1)[1][:-2]

            elf = "ref.elf"

            execute = "@cd " + testentry["work_dir"] + ";"

            cmd = (
                self.compile_cmd.format(testentry["isa"].lower(), self.xlen)
                + " "
                + test
                + " -o "
                + elf
            )

            compile_cmd = cmd + " -D" + " -D".join(testentry["macros"])
            execute += compile_cmd + ";"

            execute += self.objdump_cmd.format(elf, self.xlen, "ref.disass")
            sig_file = os.path.join(test_dir, self.name[:-1] + ".signature")

            # Spike Command Configuration
            # We use --isa to match the specific architecture (e.g., rv32i)
            # +signature and +signature-granularity are required for RISCOF verification
            # --log-commits and -l are added if coverage is needed to generate the log

            spike_cmd = self.spike_exe[
                self.xlen
            ] + " --isa={0} --priv=m --pmpregions=4 +signature={1} +signature-granularity=4 {2}".format(
                self.isa, sig_file, elf
            )

            # If coverage is enabled, we need Spike to produce a log
            if cgf_file is not None:
                spike_cmd += " -l --log-commits > {0}.log 2>&1".format(test_name)
            else:
                spike_cmd += " > {0}.log 2>&1".format(test_name)

            execute += spike_cmd + ";"

            cov_str = " "
            for label in testentry["coverage_labels"]:
                cov_str += " -l " + label

            if cgf_file is not None:
                # Adapted coverage command for Spike
                # parser-name changed from 'c_sail' to 'spike'
                coverage_cmd = "riscv_isac --verbose info coverage -d \
                        -t {0}.log --parser-name spike -o coverage.rpt  \
                        --sig-label begin_signature  end_signature \
                        --test-label rvtest_code_begin rvtest_code_end \
                        -e ref.elf -c {1} -x{2} {3};".format(
                    test_name, " -c ".join(cgf_file), self.xlen, cov_str
                )
            else:
                coverage_cmd = ""

            execute += coverage_cmd

            make.add_target(execute)

        make.execute_all(self.work_dir)
