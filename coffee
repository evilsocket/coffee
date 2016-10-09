#!/usr/bin/python
# -*- coding: UTF-8 -*-
# This file is part of the Smarter Coffee console client.
#
# Copyright(c) 2016 Simone 'evilsocket' Margaritelli
# evilsocket@gmail.com
# http://www.evilsocket.net
#
# This file may be licensed under the terms of of the
# GNU General Public License Version 3 (the ``GPL'').
#
# Software distributed under the License is distributed
# on an ``AS IS'' basis, WITHOUT WARRANTY OF ANY KIND, either
# express or implied. See the GPL for the specific language
# governing rights and limitations.
#
# You should have received a copy of the GPL along with this
# program. If not, go to http://www.gnu.org/licenses/gpl.html
# or write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

import socket
import os
from optparse import OptionParser
from os.path import expanduser

class SmarterCoffee:
    STR_DIVIDER = "\x7d"

    STATUS_OK = 0x00
    STATUS_ALREADY_BREWING = 0x01
    STATUS_INVALID_ARGS = 0x04
    STATUS_NO_CARAFFE = 0x05
    STATUS_NO_WATER = 0x06
    STATUS_LOW_WATER = 0x07

    CMD_GET_WIFI_APS = 13
    CMD_START_BREWING = 51
    CMD_SET_STRENGTH = 53
    CMD_SET_CUPS     = 54
    CMD_SET_CONFIG   = 56
    CMD_ENABLE_WARMING = 62
    CMD_DISABLE_WARMING = 74
    CMD_END = 126

    def __init__( self, address, port = 2081 ):
        self.address = address
        self.port = port
        self.sock = socket.socket( socket.AF_INET, socket.SOCK_STREAM )
        self.sock.settimeout(5)
        self.sock.connect( ( self.address, self.port ) )
        self.save_rcfile(address)

    @staticmethod
    def parse_rcfile():
        filename = os.path.join( expanduser("~"), '.smartercoffee' )
        if os.path.isfile(filename):
            address = None
            with open( filename, 'r') as fd:
                address = fd.read()
            return address.strip()

        return None

    @staticmethod
    def save_rcfile(address):
        filename = os.path.join( expanduser("~"), '.smartercoffee' )
        with open( filename, 'w+t' ) as fd:
            fd.write( address )

    @staticmethod
    def __tohex(s):
        return " ".join("{:02x}".format(ord(c)) for c in s)

    def __status_string( self, status ):
        if status == self.STATUS_OK:
            return 'OK'

        elif status == self.STATUS_ALREADY_BREWING:
            return 'ALREADY BREWING'

        elif status == self.STATUS_NO_CARAFFE:
            return 'NO CARAFFE'

        elif status == self.STATUS_INVALID_ARGS:
            return 'ONE OR MORE CONFIGURATION VALUES ARE INVALID'

        elif status == self.STATUS_NO_WATER:
            return 'NO WATER'

        elif status == self.STATUS_LOW_WATER:
            return 'LOW WATER LEVEL'

        else:
            return "0x%02x" % status

    def __consume_response_code( self ):
        size = ord( self.sock.recv(1)[0] )
        status = ord( self.sock.recv(1)[0] )
        data = self.sock.recv( size - 2 )

        if status != self.STATUS_OK:
            print "! %s" % self.__status_string(status)
            return False
        else:
            return True

    def __consume_response_strings( self ):
        strs = []
        data = self.sock.recv(1024)
        if ord(data[0]) == 0x0e:
            elements = data[1:].split( self.STR_DIVIDER )[:-1]
            for el in elements:
                ssid, dbi = el.split(',')
                strs.append( ( ssid, dbi ) )
        else:
            print "! Unexpected response: %s" % self.__tohex(data)

        return strs

    def get_wifi_aps(self):
        packet = bytearray([ self.CMD_GET_WIFI_APS, self.CMD_END ])
        self.sock.send( packet )
        return self.__consume_response_strings()

    def set_cup_amount( self, n ):
        packet = bytearray([ self.CMD_SET_CUPS, n, self.CMD_END ])
        self.sock.send(packet)
        return self.__consume_response_code()

    def set_strength( self, n ):
        packet = bytearray([ self.CMD_SET_STRENGTH, n, self.CMD_END ])
        self.sock.send(packet)
        return self.__consume_response_code()

    def set_config( self, cups = 5, strength = 2, use_grind = 1, keepwarm_time = 0 ):
        packet = bytearray([ self.CMD_SET_CONFIG, strength, cups, use_grind, keepwarm_time, self.CMD_END ])
        self.sock.send(packet)
        return self.__consume_response_code()

    def enable_warming( self, minutes = 5 ):
        packet = bytearray([ self.CMD_ENABLE_WARMING, minutes, self.CMD_END ])
        self.sock.send(packet)
        return self.__consume_response_code()

    def disable_warming( self ):
        packet = bytearray([ self.CMD_DISABLE_WARMING, self.CMD_END ])
        self.sock.send(packet)
        return self.__consume_response_code()

    def start_brewing( self ):
        packet = bytearray([ self.CMD_START_BREWING, 12, 0, 0, 0, self.CMD_END ])
        self.sock.send(packet)
        return self.__consume_response_code()

    def close( self ):
        self.sock.close()


print "☕ ☕ ☕  SmarterCoffee Client ☕ ☕ ☕"
print "by Simone 'evilsocket' Margaritelli\n"

usage = "usage: %prog [options] (make|warm)"

parser = OptionParser(usage=usage)
parser.add_option( "-A", "--address", dest="address", help="IP address of the Smarter coffee machine.", metavar="ADDRESS" )
parser.add_option( "-M", "--make", action="store_true", dest="make", default=True, help="Make coffee." )
parser.add_option( "-W", "--warm", action="store_true", dest="warm", default=False, help="Warm coffee." )
parser.add_option( "-C", "--cups", dest="cups", type="int", default=1, help="Set number of cups.", metavar="CUPS" )
parser.add_option( "-S", "--strength", dest="strength", type="int", default=2, help="Set coffee strength ( 0-2 ).", metavar="STRENGTH" )
parser.add_option( "-G", "--grind", action="store_true", dest="grind", default=True, help="Use grind." )
parser.add_option( "-F", "--filter", action="store_true", dest="filter", default=False, help="Use filter." )
parser.add_option( "-K", "--keep-warm", dest="keep_warm_time", type="int",  default=5, help="Keep the coffee warm for TIME minutes.", metavar="TIME" )

(options, args) = parser.parse_args()

options.address = options.address if options.address is not None else SmarterCoffee.parse_rcfile()

if 'make' not in args and 'warm' not in args:
    parser.print_help()
    parser.error( 'No action specified, it can be either "make" to make coffee or "warm" to warm it.' )

elif options.address is None:
    parser.print_help()
    parser.error( "No coffee machine IP address specified and no ~/.smartercoffee file found." )


dev = SmarterCoffee( options.address )

if 'make' in args:
    print "☕  Making %d cup%s of coffee using %s ..." %  ( options.cups, 's' if options.cups > 1  else '', 'filter' if options.filter else 'grind' )

    dev.set_config( options.cups, options.strength, 0 if options.filter else 1, options.keep_warm_time )
    dev.start_brewing()

elif 'warm' in args:
    print "☕  Warming coffee for %d minute%s ..." % ( options.keep_warm_time, 's' if options.keep_warm_time > 1 else '' )

    dev.enable_warming( options.keep_warm_time )

dev.close()
