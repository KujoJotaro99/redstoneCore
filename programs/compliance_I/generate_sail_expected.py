#!/usr/bin/env python3
import argparse
import shutil
import shlex
import subprocess
import tempfile
from pathlib import Path

def signature_words(path):
    words = []
    for line in path.read_text().splitlines():
        word = line.strip().split()[0] if line.strip() else ""
        if not word:
            continue
        word = word.lower().removeprefix("0x")
        if len(word) <= 8:
            words.append(word.zfill(8))
            continue
        for i in range(0, len(word), 8):
            words.append(word[i:i + 8].zfill(8))
    return words

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("test_dir", type=Path)
    parser.add_argument("--sail-sim", default="sail_riscv_sim")
    parser.add_argument("--config-override", type=Path, default=Path("sail_rv32_redstone_config.json"))
    parser.add_argument("--inst-limit", default="1000000")
    parser.add_argument("--sail-args", default="")
    args = parser.parse_args()

    sail_sim = shutil.which(args.sail_sim)
    if sail_sim is None:
        raise SystemExit(
            f"{args.sail_sim} not found. Install Sail RISC-V 0.11 and put sail_riscv_sim on PATH."
        )

    elf_path = args.test_dir / "program.elf"
    if not elf_path.exists():
        raise SystemExit(f"missing ELF: {elf_path}")

    with tempfile.TemporaryDirectory() as tmpdir:
        signature_path = Path(tmpdir) / "sail.sig"
        cmd = [
            sail_sim,
            "--rv32",
            f"--config-override={args.config_override}",
            f"--inst-limit={args.inst_limit}",
            f"--test-signature={signature_path}",
            "--signature-granularity=4",
            *shlex.split(args.sail_args),
            str(elf_path),
        ]
        result = subprocess.run(cmd)
        if result.returncode != 0 and not signature_path.exists():
            result.check_returncode()

        words = signature_words(signature_path)
        if not words:
            raise SystemExit(f"Sail did not write a signature: {signature_path}")

    with (args.test_dir / "expected_signature.mem").open("w") as out:
        for word in words:
            out.write(f"{word}\n")

if __name__ == "__main__":
    main()
