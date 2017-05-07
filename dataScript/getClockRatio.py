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

def parse_file(mydict, config, myfile):
    with open(myfile) as f:
        for i, l in enumerate(f):
            pass
    line_num = i + 1
    if line_num > 18:
        SKIP_FIRST=13
    elif line_num >= 14:
        SKIP_FIRST=7
    elif line_num >= 11:
        SKIP_FIRST=5
    elif line_num > 9:
        SKIP_FIRST=4
    else:
        SKIP_FIRST=2
    SKIP_LAST=2

    committed = 0
    aborted = 0
    duration = 0
    with open(myfile) as stream:
        oldlines = stream.read().splitlines()
        lines = oldlines[SKIP_FIRST+1:-SKIP_LAST-1] ##Skip the header line        
        if lines == []:
            lines = oldlines[SKIP_FIRST:-SKIP_LAST] ##Skip the header line        

        for line in lines:
            nums = line.split(",")
            #print words[3]+words[4]
            committed += int(nums[3])
            aborted += int(nums[4])+int(nums[5])
            duration += 10
    avg_throughput = committed / duration
    avg_abort = aborted / duration
    if config not in mydict:
        mydict[config] = [(avg_throughput, avg_abort)] 
    else:
        mydict[config].append((avg_throughput, avg_abort))

def convert(array):
    for i, c in enumerate(array):
        if c[0].isdigit():
            array[i] = float(c) 

th_total=[]
abort_total=[]
names=[]
for folder in sys.argv[1:]:
    th_data=[]
    abort_data=[]
    
    dict={}
    sub_folders = glob.glob(folder+'/4*') 
    folder_list=[]
    for f in sub_folders:
        real_name = f.split('/')[-1]
        real_name_array = real_name.split('_')
        convert(real_name_array)
        folder_list.append((real_name_array, f))

    folder_list.sort()
    for (name, f) in folder_list:
        th_file = os.path.join(f, "total_throughput")
        data = np.loadtxt(th_file, skiprows=1, usecols=range(1,7))
        th_data.append(data[0,0])
        abort_data.append(data[0,4])
    th_total.append(th_data)
    abort_total.append(abort_data)
    names.append(folder)

for i in range(len(names)):
    print names[i]
    #print len(th_total[i])
    print [v/th_total[0][j] for j, v in enumerate(th_total[i])]

for i in range(len(names)):
    print names[i]
    print abort_total[i]


    #if os.path.isdir(input_folder):
    #    throughput_file = os.path.join(input_folder, 'specula_out')
    #    config_file = open(os.path.join(input_folder, 'config'))
    #    config = config_file.read()[:-1]
    #    throughput = parse_file(dict, config, throughput_file)
    #    if len(key_list) < 15:
    #        key_list.append(config)

