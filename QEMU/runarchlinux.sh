#!/bin/bash

# === VARIÁVEIS CONFIGURÁVEIS ===
DISK_IMG="./archlinux.qcow2"
ARCH_ISO="/home/cerff_gur_sheel/archiso_out/archlinux-2026.02.21-x86_64.iso"
CPU_MODEL="Skylake-Client-v4"
CPU_FLAGS="hv_relaxed,hv_vpindex,hv_time,hv_vapic,hv_runtime,hv_synic,hv_stimer,hv_tlbflush,hv_ipi,hv_frequencies"
NUM_CPUS=2
MEMORY_MB=8192
USER_ID=$(id -u)
PULSE_SOCKET="/run/user/${USER_ID}/pulse/native"
AUDIO_FREQ=44100
QGA_SOCKET="/tmp/qga.sock"
HOST_SHARE_DIR="./qemu-share"
GUEST_MOUNT_TAG="hostshare"

if [ ! -f ${DISK_IMG}]; then
  qemu-img create -f qcow2 ${DISK_IMG} 80G
fi

if [ ! -f ./OVMF_VARS.fd ]; then
  cp /usr/share/edk2/x64/OVMF_VARS.4m.fd ./OVMF_VARS.fd
  chmod u+rw ./OVMF_VARS.fd
fi

mkdir -p "$HOST_SHARE_DIR"

# === COMANDO QEMU ===
qemu-system-x86_64 \
  -display gtk,window-close=off \
  -machine type=q35,accel=kvm \
  -enable-kvm \
  -cpu ${CPU_MODEL},${CPU_FLAGS} \
  -smp ${NUM_CPUS} \
  -m ${MEMORY_MB} \
  -vga virtio \
  -device ich9-intel-hda \
  -device hda-duplex,audiodev=hda \
  -audiodev pa,id=hda,server=unix:${PULSE_SOCKET},out.frequency=${AUDIO_FREQ} \
  -device qemu-xhci,id=xhci \
  -device usb-tablet,bus=xhci.0 \
  -chardev socket,path=${QGA_SOCKET},server=on,wait=off,id=qga0 \
  -device virtio-serial \
  -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  -object rng-random,id=rng0,filename=/dev/urandom \
  -device virtio-rng-pci,max-bytes=1024,period=1000 \
  -drive format=qcow2,file=${DISK_IMG} \
  -drive file="${ARCH_ISO}",media=cdrom \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=./OVMF_VARS.fd \
  -boot menu=on \
  -rtc base=localtime \
  -netdev user,id=vmnic -device virtio-net,netdev=vmnic \
  -fsdev local,path=${HOST_SHARE_DIR},security_model=none,id=fsdev0 \
  -device virtio-9p-pci,fsdev=fsdev0,mount_tag=${GUEST_MOUNT_TAG}
