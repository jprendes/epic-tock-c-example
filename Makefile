# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

export PATH := $(PATH):$(HOME)/tools/gnu-elf-rv32imac-compact/bin
export PATH := $(PWD)/elf2tab/target/debug:$(PATH)

qemu=qemu-6.1.0
example=libtock-c/examples/c_hello
tbf=build/rv32imac/rv32imac.tbf
elf2tab=elf2tab/target/debug/elf2tab

run: $(example)/$(tbf) tock $(qemu)/build/qemu-system-riscv32
	cd tock/boards/hifive1 && qemu=$(PWD)/$(qemu)/build/qemu-system-riscv32 APP=$(PWD)/$(example)/$(tbf) make qemu-app

relocate: tock
	cd tock && patch -p1 < ../change-app-load-addr.diff

$(example)/$(tbf): libtock-c $(elf2tab) $(HOME)/tools/gnu-elf-rv32imac-compact/bin/riscv32-unknown-elf-gcc $(HOME)/tools/gnu-elf-rv32imac-compact/bin/riscv32-unknown-elf-clang
	cd $(example) && make V=1 TOCK_TARGETS="rv32imac|rv32imac" CC=-clang CPPFLAGS="-fepic" WLFLAGS="-Wl,--emit-relocs"

libtock-c:
	git clone -b epic-example https://github.com/luismarques/libtock-c.git

tock:
	git clone --recursive https://github.com/tock/tock.git

$(elf2tab): elf2tab
	cd elf2tab && cargo build

elf2tab:
	git clone -b rela https://github.com/luismarques/elf2tab.git

$(HOME)/tools/gnu-elf-rv32imac-compact/bin/riscv32-unknown-elf-gcc:
	cp ctng-config-compact-rv32imac .config && ct-ng build

llvm-project:
	git clone -b epic --depth=1 https://github.com/lowRISC/llvm-project.git

$(HOME)/tools/gnu-elf-rv32imac-compact/bin/riscv32-unknown-elf-clang: llvm-project
	mkdir -p llvm-project/build && cd llvm-project/build && cmake ../llvm -G Ninja -DCMAKE_BUILD_TYPE="Release" -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DLLVM_ENABLE_LLD=True -DLLVM_TARGETS_TO_BUILD="RISCV" -DLLVM_ENABLE_PROJECTS="clang" -DCMAKE_INSTALL_PREFIX=$(HOME)/tools/gnu-elf-rv32imac-compact -DCLANG_LINKS_TO_CREATE=riscv32-unknown-elf-clang && ninja install

$(qemu)/build/qemu-system-riscv32:
	curl https://download.qemu.org/$(qemu).tar.xz --output $(qemu).tar.xz && tar xf $(qemu).tar.xz && cd $(qemu) && ./configure --target-list=riscv32-softmmu --disable-linux-io-uring --disable-libdaxctl && make

.PHONY: run relocate
