#!/usr/bin/env python

import argparse
import json
import os
import re
import sys
import time

#
# Global
#

CEPH_LOG_DIR = os.environ.get('CEPH_LOG_DIR') or \
               '/var/log/ceph'
CEPHSTATS_LOG_DIR = os.environ.get('CEPHSTATS_LOG_DIR') or \
                    CEPH_LOG_DIR
CEPHSTATS_LOG_FILE = os.environ.get('CEPHSTATS_LOG_FILE') or \
                     CEPHSTATS_LOG_DIR + '/ceph-stats.{DATE}.log'

CEPHSTATS_DATE = os.environ.get('CEPHSTATS_DATE') or \
                 time.strftime("%F")

#
# Functions
#

def parse_args():
    parser = argparse.ArgumentParser(
        description='process stats from logs generated by ceph-stats'
        )
    parser.add_argument(
        '-d', '--date',
        metavar='YYYY-MM-DD',
        help='date to parse data for',
        default=CEPHSTATS_DATE,
        )
    parser.add_argument(
        '-p', '--json-pretty',
        action='store_true',
        default=False,
        help='json-prettify output',
        )
    parser.add_argument(
        'name',
        help='statistics name to look for',
        )
    parser.add_argument(
        'key',
        nargs='*',
        help='key in statistics to look for',
        default=['']
        )
    args = parser.parse_args()
    return args

def logfile(date):
    return CEPHSTATS_LOG_FILE.replace('{DATE}', date)

def main():
    ctx = parse_args()
    f = open(logfile(ctx.date), 'r')
    r = re.compile('^(\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d) \[%s\] \s*(.*)$' % (ctx.name))
    if not ctx.json_pretty:
        print '#"date" "time"', ' '.join(['"' + x + '"' for x in ctx.key])
    for line in f:
        m = r.match(line)
        if not m:
            continue
        t = m.group(1)
        val = json.loads(m.group(2))
        print t,
        if ctx.json_pretty:
            print ctx.name
        for key in ctx.key:
            v = val
            for k in key.split():
                if k.isdigit():
                    k = int(k)
                try:
                    v = v[k]
                except:
                    v = None
                    break
            if ctx.json_pretty:
                print key, ' = ', json.dumps(v, sort_keys=True, indent=4, separators=(',', ': '))
            else:
                print v is None and '-' or v,
        print

main()
