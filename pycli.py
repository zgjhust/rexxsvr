# -*- coding:utf8 -*-
import sys
import socket
import select
import datetime
# import threading
from multiprocessing import Process


PKG_HEAD_LENGTH = 18
PKG_TYPE_LENGTH = 8
PKG_CONT_LENGTH = 10


def recv_packet(sock):
    pkt = ''
    data = True
    while data:
        data = sock.recv(1024)
        pkt = pkt + data
        if isValidPacket(pkt):
            return pkt
        if not data:
            raise Exception('no data recieved or connection closed!')


def recv_packetX(sock, timeout=10):
    sock.setblocking(0)
    data = ''
    stime = datetime.datetime.now()
    while True:
        rlist, _, xlist = select.select([sock, ], [], [sock, ], 0.5)
        if sock in rlist:
            data = data + sock.recv(1024)
        etime = (datetime.datetime.now() - stime).total_seconds()
        if isValidPacket(data):
            return data
        if etime > timeout:
            raise Exception("socket recv timeout!")
        if sock in xlist:
            raise Exception("sock exception ocurred!")


def isValidPacket(pkt):
    if len(pkt) < PKG_HEAD_LENGTH:
        return False
    try:
        contlen = int(pkt[PKG_TYPE_LENGTH:PKG_HEAD_LENGTH])
        if len(pkt) != PKG_HEAD_LENGTH+contlen:
            return False
        else:
            return True
    except TypeError:
        return False


def do_work():
    HOST = 'www.mainframe.com'
    PORT = 5000
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((HOST, PORT))
    cmds = [
        'pkpdsmgt30        SYS1.PLEXCD1.PARMLIB(BPXPRM01)',
        'pksyscmd10        /d parmlib',
        'pksyscmd10        /d xcf,str'
    ]
    try:
        for cmd in cmds:
            s.sendall(cmd)
            pkt = recv_packetX(s)
            print pkt
        s.close()
    except Exception:
        print sys.exc_info()[0]
        s.close()


if __name__ == '__main__':
    # for i in xrange(50):
    #     t = threading.Thread(target=do_work)
    #     t.start()
    #     t.join()
    for i in xrange(50):
        p = Process(target=do_work)
        p.start()
        p.join()
