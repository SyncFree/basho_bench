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


clocksi='processed_data/remote_reads/clocksi'
external='processed_data/remote_reads/external'
internal='processed_data/remote_reads/internal'

clocksif = open(clocksi)
externalf = open(external)
internalf = open(internal)

clocksilines = clocksif.readlines()
externallines = externalf.readlines()
internallines = internalf.readlines()
to_print=""
for i, line in enumerate(clocksilines):
    if i % 2 == 0:
        to_print+=line[:-1]
    else:
        basenum = float(line[:-1])
        externalnum = float(externallines[i][:-1])
        internalnum = float(internallines[i][:-1])
        print(to_print+": "+str(externalnum/basenum)+", "+str(internalnum/basenum))
        to_print=""
