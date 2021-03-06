#!/usr/bin/env python

import argparse
import errno
import os
import os.path
import re
import sys

from subprocess import Popen, PIPE

gnuplot = "gnuplot"
#gnuplot = "cat"

#
# Functions
#

def parse_args():
    parser = argparse.ArgumentParser(
        description='process log file generated by "iostat -x -t -p {PERIOD} {COUNT}" command'
        )
    parser.add_argument(
        'datadir',
        help='where to put generated files',
        )
    parser.add_argument(
        'name',
        help='used in generated file names',
        )
    args = parser.parse_args()
    return args

def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc: # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else: raise

def main():
    ctx = parse_args()

    # 07/27/15 11:59:24
    # avg-cpu:  %user   %nice %system %iowait  %steal   %idle
    #            3.95    0.00    1.24    7.85    0.00   86.96
    #
    # Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
    # sdf               0.00  1174.00    0.60   18.40    24.80  4769.60   504.67     1.53   80.42    1.33   83.00   1.56   2.96
    # ...

    time_r  = re.compile('^\s*(\d\d/\d\d/\d\d \d\d:\d\d:\d\d)\s*$')
    cols_r = re.compile('^\s*Device:\s+(.+)$')
    data_r  = re.compile('^\s*(sd[a-e]|sdg[0-9])\s+(.+)$')

    time = ''
    cols = []
    data = []
    res  = {}
    for line in sys.stdin:
        m = time_r.match(line)
        if m:
            time = m.group(1)
            continue
        m = cols_r.match(line)
        if m:
            cols = m.group(1).split()
        m = data_r.match(line)
        if m:
            disk = m.group(1)
            data = m.group(2).split()
            for key in cols:
                i = cols.index(key)
                if not res.get(key):
                    res[key] = {}
                if not res[key].get(time):
                    res[key][time] = {}
                res[key][time][disk] = data[i]
            continue

    mkdir_p(ctx.datadir)

    for key in res.keys():
        disks = None
        filename = os.path.join(ctx.datadir, format('%s.%s.dat' % (ctx.name, key)).replace('/', '_'))
        f = open(filename, 'w')
        print >>f, "#", ctx.name, key
        for time in sorted(res[key].keys()):
            if not disks:
                disks = sorted(res[key][time].keys())
                print >>f, "#%s\t%s" % ('date time'.ljust(len(time) - 1), "\t".join(disks))
            line = time
            for disk in disks:
                line += "\t" + res[key][time][disk]
            print >>f, line
        f.close()
        plot = Popen(gnuplot, shell=True, stdin=PIPE).stdin
        output = filename + '.png'
        print >>plot, 'set term png size 1600,1200'
        print >>plot, 'set style data l'
        print >>plot, 'set grid'
        print >>plot, 'set output "%s"' % output
        print >>plot, 'set xdata time'
        print >>plot, 'set timefmt "%m/%d/%y %H:%M:%S"'
        print >>plot, 'set format x "%H:%M"'
        print >>plot, 'set xlabel "time"'
        print >>plot, 'set ylabel "%s"' % key
        print >>plot, 'set title "%s [%s]"' % (key, ctx.name)
        print >>plot, 'plot', ', '.join(['"%s" using 1:($%d + %d) title "%s"' % (filename, 3 + disks.index(disk), disks.index(disk) * 100, disk) for disk in disks])
        #print >>plot, 'plot', ', '.join(['"%s" using 1:%d title "%s"' % (filename, 3 + disks.index(disk), disk) for disk in disks])
        plot.close()
#
# Main
#

main()
