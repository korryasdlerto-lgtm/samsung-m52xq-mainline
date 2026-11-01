#!/usr/bin/env python3
# M52XQ: give the WCN6750 Bluetooth controller this phone's own BD address.
#
# The NVM (qca/msnv11.bin) carries a placeholder address, so btqca marks the
# controller "unconfigured" (HCI_QUIRK_USE_BDADDR_PROPERTY). The real address is
# per device, stored by Samsung in EFS (bluetooth/bt_addr); the installer
# (update-binary, in TWRP on this very phone) copies it to /etc/m52xq/bt_addr.
# It is handed to the kernel with mgmt "Set Public Address". If the file is
# missing, nothing is set (no shared fallback address).
import ctypes
import os
import re
import socket
import struct
import sys
import time

ADDR_FILE = "/etc/m52xq/bt_addr"
AF_BLUETOOTH = 31
BTPROTO_HCI = 1
HCI_DEV_NONE = 0xFFFF
HCI_CHANNEL_CONTROL = 3
MGMT_OP_SET_PUBLIC_ADDRESS = 0x0039
MGMT_EV_CMD_COMPLETE = 0x0001
MGMT_EV_CMD_STATUS = 0x0002


def read_addr():
    try:
        with open(ADDR_FILE) as f:
            text = f.read().strip()
    except OSError:
        return None
    if not re.fullmatch(r"([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", text):
        return None
    return text


def hci_index():
    for _ in range(100):
        for name in sorted(os.listdir("/sys/class/bluetooth")) if os.path.isdir("/sys/class/bluetooth") else []:
            m = re.fullmatch(r"hci(\d+)", name)
            if m:
                return int(m.group(1))
        time.sleep(0.1)
    return None


def set_public_addr(index, addr):
    libc = ctypes.CDLL(None, use_errno=True)
    fd = libc.socket(AF_BLUETOOTH, socket.SOCK_RAW | socket.SOCK_CLOEXEC, BTPROTO_HCI)
    if fd < 0:
        raise OSError(ctypes.get_errno(), "socket")
    try:
        sa = struct.pack("<HHH", AF_BLUETOOTH, HCI_DEV_NONE, HCI_CHANNEL_CONTROL)
        if libc.bind(fd, sa, len(sa)) < 0:
            raise OSError(ctypes.get_errno(), "bind")
        bdaddr = bytes(int(b, 16) for b in reversed(addr.split(":")))
        os.write(fd, struct.pack("<HHH", MGMT_OP_SET_PUBLIC_ADDRESS, index, len(bdaddr)) + bdaddr)
        deadline = time.time() + 5
        while time.time() < deadline:
            ev = os.read(fd, 512)
            code, idx, _ = struct.unpack_from("<HHH", ev)
            if code in (MGMT_EV_CMD_COMPLETE, MGMT_EV_CMD_STATUS) and idx == index:
                op, status = struct.unpack_from("<HB", ev, 6)
                if op == MGMT_OP_SET_PUBLIC_ADDRESS:
                    return status
        return None
    finally:
        os.close(fd)


def main():
    addr = read_addr()
    if not addr:
        print("m52xq-bt-addr: no BD address in %s, leaving the controller as is" % ADDR_FILE)
        return 0
    index = hci_index()
    if index is None:
        print("m52xq-bt-addr: no hci device")
        return 0
    # the controller only accepts it once its setup (firmware download) is done
    status = None
    for _ in range(20):
        status = set_public_addr(index, addr)
        if status == 0:
            break
        time.sleep(0.5)
    print("m52xq-bt-addr: hci%d set public address, mgmt status %s" % (index, status))
    return 0


if __name__ == "__main__":
    sys.exit(main())
