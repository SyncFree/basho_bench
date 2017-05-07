#!/usr/bin/env python

###!/usr/bin/env python3
from __future__ import division
import sys
import os
import glob
import numpy as np
from operator import add
from os import rename, listdir
from time import gmtime, strftime
import sys


if len(sys.argv) == 1:
    base='processed_data/remote_reads/clocksi'
    folders=['processed_data/remote_reads/external', 'processed_data/remote_reads/internal']
else:
    base=sys.argv[1]
    folders=sys.argv[2:]

baselines = open(base).readlines()
flines=[]
for f in folders:
    flines.append(open(f).readlines())

to_print=""
for i, line in enumerate(baselines):
    if i % 2 == 0:
        to_print+=line[:-1]+": "
    else:
        if ',' in line:
            basenum = float(line.split(',')[0])
        else:
            basenum = float(line[:-1])
        for clines in flines:
            if i < len(clines):
                if ',' in clines[i]:
                    num = float(clines[i].split(',')[0])
                else:
                    num = float(clines[i][:-1])
                to_print+= str(num/basenum)+ ","
        print(to_print[:-1])
        to_print=""
