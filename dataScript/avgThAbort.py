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


def write_to_file(file_name, dict, keys, title):
    file = open(file_name, 'w')
    file.write(title+'\n')
    for key in keys:
        if key in dict:
            data_list = dict[key]
            data_array = np.array(data_list).astype(np.float)
            if data_array.ndim == 2:
                data_avg = list(np.average(data_array, axis=0))
            else:
                data_avg = list(data_array)
            file.write(key+' '+' '.join(map(str, data_avg))+'\n')
    file.close()

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

folder = sys.argv[1]
dict={}
sub_folders = glob.glob(folder+'/20*') 
key_list = []
for f in sub_folders:
    input_folder = f #os.path.join(root, f)
    if os.path.isdir(input_folder):
        throughput_file = os.path.join(input_folder, 'specula_out')
        config_file = open(os.path.join(input_folder, 'config'))
        config = config_file.read()[:-1]
        throughput = parse_file(dict, config, throughput_file)
        if len(key_list) < 15:
            key_list.append(config)

for key in key_list:
    print key
    #print str(np.average(dict[key])) +","+str(np.std(dict[key]))
    avg_th = np.average([v[0] for v in dict[key]])
    avg_abort = np.average([v[1] for v in dict[key]])
    #print np.average(dict[key])
    #print np.average(dict[key])
    print str(avg_th) +", "+ str(avg_abort)+", rate is "+str(avg_abort/(avg_th+avg_abort))
