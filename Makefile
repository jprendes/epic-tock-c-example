# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Don't go parallel
# The ct-ng recipies for `riscv32-unknown-elf-gcc` shouldn't run in parallel.
.NOTPARALLEL:

export PATH := $(PWD)/elf2tab/target/debug:$(PATH)

example=libtock-c/examples/c_hello
rv32imac_tbf=build/rv32imac/rv32imac.tbf
rv32imc_tbf=build/rv32imc/rv32imc.tbf
elf2tab=elf2tab/target/debug/elf2tab

run: $(example)/$(rv32imac_tbf) $(example)/$(rv32imc_tbf) tock qemu
	cd tock/boards/hifive1 && QEMU=../../tools/qemu/build/qemu-system-riscv32 APP=$(PWD)/$(example)/$(rv32imac_tbf) make qemu-app
	cd tock/boards/opentitan/earlgrey-cw310 && OPENTITAN_BOOT_ROM=../../../tools/qemu-runner/opentitan-boot-rom.elf APP=$(PWD)/$(example)/$(rv32imc_tbf) make qemu-app

relocate: tock
	cd tock && patch -p1 < ../change-app-load-addr.diff

$(example)/$(rv32imac_tbf): libtock-c $(elf2tab) $(HOME)/tools/gnu-elf-rv32imac-compact/bin/riscv32-unknown-elf-gcc $(HOME)/tools/gnu-elf-rv32imac-compact/bin/riscv32-unknown-elf-clang $(example)/main.c libtock-c/newlib/rv32/rv32imac/libc.a
	rm -f $(example)/build/c_hello.tab
	cd $(example) && env PATH=$(HOME)/tools/gnu-elf-rv32imac-compact/bin:$(PATH) make V=1 TOCK_TARGETS="rv32imac|rv32imac" CC=-clang CPPFLAGS="-fepic" WLFLAGS="-Wl,--emit-relocs -fuse-ld=lld"

$(example)/$(rv32imc_tbf): libtock-c $(elf2tab) $(HOME)/tools/gnu-elf-rv32imc-compact/bin/riscv32-unknown-elf-gcc $(HOME)/tools/gnu-elf-rv32imc-compact/bin/riscv32-unknown-elf-clang $(example)/main.c libtock-c/newlib/rv32/rv32im/libc.a
	rm -f $(example)/build/c_hello.tab
	cd $(example) && env PATH=$(HOME)/tools/gnu-elf-rv32imc-compact/bin:$(PATH) make V=1 TOCK_TARGETS="rv32imc|rv32imc" CC=-clang CPPFLAGS="-fepic" WLFLAGS="-Wl,--emit-relocs -fuse-ld=lld"

libtock-c/newlib/rv32/rv32imac/libc.a: $(HOME)/tools/gnu-elf-rv32imac-compact/bin/riscv32-unknown-elf-gcc $(HOME)/tools/gnu-elf-rv32imac-compact/bin/riscv32-unknown-elf-clang
	env PATH=$(HOME)/tools/gnu-elf-rv32imac-compact/bin:$(PATH) make OUT_SUFFIX=rv32imac -C libtock-c/newlib rebuild-newlib-rv32
	mkdir -p libtock-c/newlib/rv32/rv32imac
	cp libtock-c/newlib/newlib-riscv-4.1.0-rv32imac/riscv32-unknown-elf/newlib/lib{c,m}.a libtock-c/newlib/rv32/rv32imac/

libtock-c/newlib/rv32/rv32im/libc.a: $(HOME)/tools/gnu-elf-rv32imc-compact/bin/riscv32-unknown-elf-gcc $(HOME)/tools/gnu-elf-rv32imc-compact/bin/riscv32-unknown-elf-clang
	env PATH=$(HOME)/tools/gnu-elf-rv32imc-compact/bin:$(PATH) make OUT_SUFFIX=rv32imc -C libtock-c/newlib rebuild-newlib-rv32
	mkdir -p libtock-c/newlib/rv32/rv32im
	cp libtock-c/newlib/newlib-riscv-4.1.0-rv32imc/riscv32-unknown-elf/newlib/lib{c,m}.a libtock-c/newlib/rv32/rv32im/

libtock-c:
	git clone -b epic-example https://github.com/luismarques/libtock-c.git

tock:
	git clone --recursive https://github.com/tock/tock.git

$(elf2tab): elf2tab
	cd elf2tab && cargo build

elf2tab:
	git clone -b rela_lld https://github.com/luismarques/elf2tab.git

$(HOME)/tools/gnu-elf-rv32imac-compact/bin/riscv32-unknown-elf-gcc:
	cp ctng-config-compact-rv32imac .config && ct-ng build

$(HOME)/tools/gnu-elf-rv32imc-compact/bin/riscv32-unknown-elf-gcc:
	cp ctng-config-compact-rv32imc .config && ct-ng build

llvm-project:
	git clone -b epic --depth=1 https://github.com/lowRISC/llvm-project.git

$(HOME)/tools/gnu-elf-rv32imac-compact/bin/riscv32-unknown-elf-clang: llvm-project
	mkdir -p llvm-project/build-rv32imac && cd llvm-project/build-rv32imac && cmake ../llvm -G Ninja -DCMAKE_BUILD_TYPE="Release" -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DLLVM_ENABLE_LLD=True -DLLVM_TARGETS_TO_BUILD="RISCV" -DLLVM_ENABLE_PROJECTS="clang;lld" -DCMAKE_INSTALL_PREFIX=$(HOME)/tools/gnu-elf-rv32imac-compact -DCLANG_LINKS_TO_CREATE=riscv32-unknown-elf-clang && ninja install

$(HOME)/tools/gnu-elf-rv32imc-compact/bin/riscv32-unknown-elf-clang: llvm-project
	mkdir -p llvm-project/build-rv32imc && cd llvm-project/build-rv32imc && cmake ../llvm -G Ninja -DCMAKE_BUILD_TYPE="Release" -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DLLVM_ENABLE_LLD=True -DLLVM_TARGETS_TO_BUILD="RISCV" -DLLVM_ENABLE_PROJECTS="clang;lld" -DCMAKE_INSTALL_PREFIX=$(HOME)/tools/gnu-elf-rv32imc-compact -DCLANG_LINKS_TO_CREATE=riscv32-unknown-elf-clang && ninja install

qemu:
	cd tock && CI=y make ci-setup-qemu

.PHONY: run relocate
