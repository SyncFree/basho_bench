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

def get_stats(mydict, config, myfolder):
    latency_files = glob.glob(myfolder+"/percv_latency-*")
    num_blocked = 0
    time_blocked = 0
    hit_count = 0
    for f in latency_files:
        with open(f) as stream:
            lines = stream.readlines()
            for line in lines:
                if line.startswith("Num blocked is"):
                    comma_split = line.split(',')    
                    num_blocked+=int(comma_split[0].split(' ')[-1])
                    time_blocked+=int(comma_split[1].split(' ')[-1])/1000000
                    hit_count+=int(comma_split[2].split(' ')[-2])

    if config not in mydict:
        mydict[config] = [(num_blocked, time_blocked, hit_count)]
    else:
        mydict[config].append((num_blocked, time_blocked, hit_count))

def get_latency(mydict, config, myfolder):
    latency_files = glob.glob(myfolder+"/final_latency-*")
    total_latency = 0
    num_lines = 0
    for f in latency_files:
        with open(f) as stream:
            lines = stream.readlines()
            for line in lines:
                total_latency += int(line)                    
                num_lines += 1
    avg_latency= total_latency / num_lines
    if config not in mydict:
        mydict[config] = [avg_latency]
    else:
        mydict[config].append(avg_latency) 
    
def get_param(mydict, config, myfolder):
    myfile = myfolder+"/specula_out"
    duration = open(myfile).readlines()[-1].split(',')[0]
    committed = 0
    with open(myfile) as stream:
        lines = stream.read().splitlines()

        for line in lines:
            nums = line.split(",")
            #print words[3]+words[4]
            if nums[3][1].isdigit():
                committed += int(nums[3][1:])

    remote_rate = 100-float(config.split(' ')[1])-float(config.split(' ')[2])
    if config not in mydict:
        mydict[config] = [(float(duration), remote_rate, committed)]
    else:
        mydict[config].append((float(duration), remote_rate, committed)) 
    

folder = sys.argv[1]
lat_dict={}
stat_dict={}
param_dict={}
key_list=[]
sub_folders = glob.glob(folder+'/20*') 
print("Latency, Num blocked, time blocked, hit count")
for f in sub_folders:
    input_folder = f #os.path.join(root, f)
    if os.path.isdir(input_folder):
        config_file = open(os.path.join(input_folder, 'config'))
        config = config_file.read()[:-1]

        get_latency(lat_dict, config, input_folder)
        get_stats(stat_dict, config, input_folder)
        get_param(param_dict, config, input_folder)
        
        if len(key_list) < 15:
            key_list.append(config)

output=""
for key in key_list:
    output += key
    avg_lat = np.average(lat_dict[key])
    nb = sum([v[0] for v in stat_dict[key]])
    tb = sum([v[1] for v in stat_dict[key]])
    ch = sum([v[2] for v in stat_dict[key]])

    remote_rate = param_dict[key][0][1] 
    tdur = sum([v[0] for v in param_dict[key]])
    tcom = sum([v[2] for v in param_dict[key]])
    cache_hit_rate = ch / (remote_rate * 10 * tcom) 
    blocked_duration = tb / (tdur * 40 * len(param_dict[key])) 
    output += ": "+str(remote_rate)+", latency is "+str(avg_lat)+", nb is "+str(nb)+", tb is "+str(tb)+", cache hit is "+str(ch)+", total duration "+str(tdur)+", total committed "+str(tcom)+", cache hit is "+str(cache_hit_rate)+", blocked perct is "+str(blocked_duration)
    print output
    output = ""
