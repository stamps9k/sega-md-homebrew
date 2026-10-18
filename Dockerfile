# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Stage 1: build the ROM
#
# Alpine 3.24, vasm v2.0 + binutils built from source (m68k-elf target).
# ---------------------------------------------------------------------------
FROM alpine:3.24 AS builder

ARG BINUTILS_VERSION=2.46.1

RUN apk add --no-cache \
    build-base \
    curl \
    texinfo \
    zlib-dev \
    bison \
    flex

# --- Build binutils (m68k-elf target) ----------------------------------------
#
# We need:
#   m68k-elf-ld       — linker
#   m68k-elf-objcopy  — convert ELF to raw binary (.bin ROM)
#   m68k-elf-nm       — symbol listing (useful for debugging)
#   m68k-elf-objdump  — disassembler / inspection
#
# We explicitly disable gold, gprof, and other tools we don't need to keep
# build time and binary size down.
# -----------------------------------------------------------------------------
RUN curl -fsSL \
    "https://sourceware.org/pub/binutils/releases/binutils-${BINUTILS_VERSION}.tar.xz" \
    -o /tmp/binutils.tar.xz \
  && tar -xJf /tmp/binutils.tar.xz -C /tmp \
  && rm /tmp/binutils.tar.xz

RUN cd /tmp/binutils-${BINUTILS_VERSION} \
  && ./configure \
       --target=m68k-elf \
       --prefix=/opt/m68k \
       --disable-nls \
       --disable-werror \
       --disable-gold \
       --disable-gprof \
       --disable-gprofng \
       --with-sysroot \
  && make -j$(nproc) \
  && make install \
  && rm -rf /tmp/binutils-${BINUTILS_VERSION}

# --- Build vasm (m68k CPU, Motorola syntax) -----------------------------------
#
# vasm is built as a single binary: vasmm68k_mot
# We use the Motorola ("mot") syntax module because:
#   - It matches the official 68000 documentation syntax
#   - It is standard in Megadrive/Amiga homebrew and all reference material
#   - Alternatives (std, madmac) differ in directive naming
#
# The resulting binary is placed in /opt/vasm/bin/
# -----------------------------------------------------------------------------
RUN curl -fsSL \
    "http://sun.hasenbraten.de/vasm/release/vasm.tar.gz" \
    -o /tmp/vasm.tar.gz \
  && tar -xzf /tmp/vasm.tar.gz -C /tmp \
  && rm /tmp/vasm.tar.gz

RUN cd /tmp/vasm \
  && make CPU=m68k SYNTAX=mot \
  && mkdir -p /opt/vasm/bin \
  && cp vasmm68k_mot /opt/vasm/bin/ \
  && rm -rf /tmp/vasm

# Toolchain built above isn't on PATH by default — the makefile invokes
# vasmm68k_mot / m68k-elf-ld / m68k-elf-objcopy by bare name, so it must be.
ENV PATH="/opt/m68k/bin:/opt/vasm/bin:${PATH}"

# --- Build the ROM ------------------------------------------------------------
#
# Only rom/ is copied, so changes to web/, docs, etc. don't invalidate this
# layer. Anything added under rom/ (e.g. assets/) is picked up automatically.
# -----------------------------------------------------------------------------
WORKDIR /rom
COPY rom/ .

# Produces pkg/hello.bin via the project's makefile + rom.ld
RUN make

# ---------------------------------------------------------------------------
# Stage 2: serve the ROM via EmulatorJS
# ---------------------------------------------------------------------------
FROM nginx:alpine AS runtime

COPY web/index.html /usr/share/nginx/html/index.html
COPY web/robots.txt /usr/share/nginx/html/robots.txt

# makefile's TARGET is "hello", output lands in pkg/hello.bin.
COPY --from=builder /rom/pkg/hello.bin /usr/share/nginx/html/rom.bin

EXPOSE 80

