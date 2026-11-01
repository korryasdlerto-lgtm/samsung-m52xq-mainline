#!/usr/bin/env python3
# m52xq-gnss: minimal QMI LOC (service 16) client over raw QRTR sockets.
#
# qmicli can only do one LOC action per process, and over QRTR every process
# is a separate client: the session started by `qmicli --loc-start` dies with
# that client, so a second `qmicli --loc-follow-*` never gets indications
# (live 2026-10-02, в31). This keeps ONE client: register events -> enable
# NMEA -> start a periodic session -> print NMEA / SV / position indications.
#
# Prereqs: modem remoteproc running, rmtfs + tqftpserv up, and (live-proven)
# `qmicli --loc-set-engine-lock=none`, `--loc-inject-time`,
# `--loc-set-operation-mode=standalone` done once beforehand.
import socket, struct, sys, time

AF_QIPCRTR = 42
QRTR_PORT_CTRL = 0xfffffffe
QRTR_TYPE_NEW_SERVER = 4
QRTR_TYPE_NEW_LOOKUP = 10
LOC_SERVICE = 16

LOC_REG_EVENTS = 0x0021
LOC_START = 0x0022
LOC_STOP = 0x0023
IND_POSITION = 0x0024
IND_SV_INFO = 0x0025
IND_NMEA = 0x0026
LOC_SET_NMEA_TYPES = 0x003E

EV_POSITION, EV_SV_INFO, EV_NMEA = 0x1, 0x2, 0x4
NMEA_ALL = 0x1F  # GGA | RMC | GSV | GSA | VTG


def tlv(t, fmt, *v):
    data = struct.pack('<' + fmt, *v)
    return struct.pack('<BH', t, len(data)) + data


def parse_tlvs(b):
    out, i = {}, 0
    while i + 3 <= len(b):
        t, ln = struct.unpack_from('<BH', b, i)
        out[t] = b[i + 3:i + 3 + ln]
        i += 3 + ln
    return out


def lookup(sock, node_local):
    pkt = struct.pack('<IIIII', QRTR_TYPE_NEW_LOOKUP, LOC_SERVICE, 0, 0, 0)
    sock.sendto(pkt, (node_local, QRTR_PORT_CTRL))
    sock.settimeout(5)
    while True:
        data, _ = sock.recvfrom(4096)
        cmd, svc, inst, node, port = struct.unpack_from('<IIIII', data)
        if cmd == QRTR_TYPE_NEW_SERVER and svc == LOC_SERVICE:
            return node, port
        if cmd == QRTR_TYPE_NEW_SERVER and svc == 0:
            raise SystemExit('LOC service 16 not found')


class Loc:
    def __init__(self):
        self.s = socket.socket(AF_QIPCRTR, socket.SOCK_DGRAM)
        # no bind(): the kernel autobinds a port on the first sendto();
        # getsockname() already reports our local node id
        local_node = self.s.getsockname()[0]
        self.addr = lookup(self.s, local_node)
        print('LOC service at node %d port %d' % self.addr, flush=True)
        self.txn = 1

    def request(self, msg, payload=b''):
        self.txn += 1
        pkt = struct.pack('<BHHH', 0, self.txn, msg, len(payload)) + payload
        self.s.sendto(pkt, self.addr)
        deadline = time.time() + 5
        while time.time() < deadline:
            self.s.settimeout(max(0.1, deadline - time.time()))
            try:
                data, src = self.s.recvfrom(65536)
            except socket.timeout:
                break
            if src != self.addr:
                continue
            flags, txn, mid, ln = struct.unpack_from('<BHHH', data)
            if flags == 2 and txn == self.txn and mid == msg:
                t = parse_tlvs(data[7:7 + ln])
                res, err = struct.unpack('<HH', t.get(2, b'\0\0\0\0'))
                print('resp 0x%04x: result=%d error=%d' % (msg, res, err), flush=True)
                return res == 0
            self.handle(data)
        print('resp 0x%04x: timeout' % msg, flush=True)
        return False

    def handle(self, data):
        flags, txn, mid, ln = struct.unpack_from('<BHHH', data)
        if flags != 4:
            return
        t = parse_tlvs(data[7:7 + ln])
        ts = time.strftime('%H:%M:%S')
        if mid == IND_NMEA and 1 in t:
            print(ts, 'NMEA', t[1].rstrip(b'\0').decode(errors='replace').strip(), flush=True)
        elif mid == IND_POSITION:
            status = struct.unpack('<I', t[1])[0] if 1 in t else -1
            lat = struct.unpack('<d', t[0x10])[0] if 0x10 in t else None
            lon = struct.unpack('<d', t[0x11])[0] if 0x11 in t else None
            unc = struct.unpack('<f', t[0x12])[0] if 0x12 in t else None
            print(ts, 'POS status=%d lat=%s lon=%s unc=%s' % (status, lat, lon, unc), flush=True)
        elif mid == IND_SV_INFO:
            n = 0
            if 0x11 in t:
                n = t[0x11][0]
            print(ts, 'SV-INFO list_len=%d tlvs=%s' % (n, sorted(hex(k) for k in t)), flush=True)
        else:
            print(ts, 'IND 0x%04x tlvs=%s' % (mid, sorted(hex(k) for k in t)), flush=True)

    def run(self, seconds):
        self.request(LOC_REG_EVENTS, tlv(0x01, 'Q', EV_POSITION | EV_SV_INFO | EV_NMEA))
        self.request(LOC_SET_NMEA_TYPES, tlv(0x01, 'I', NMEA_ALL))
        self.request(LOC_START, tlv(0x01, 'B', 1) + tlv(0x10, 'I', 1) +
                     tlv(0x11, 'I', 3) + tlv(0x12, 'I', 1) + tlv(0x13, 'I', 1000))
        end = time.time() + seconds
        try:
            while time.time() < end:
                self.s.settimeout(1)
                try:
                    data, src = self.s.recvfrom(65536)
                except socket.timeout:
                    continue
                if src == self.addr:
                    self.handle(data)
        finally:
            self.request(LOC_STOP, tlv(0x01, 'B', 1))


if __name__ == '__main__':
    Loc().run(int(sys.argv[1]) if len(sys.argv) > 1 else 600)
