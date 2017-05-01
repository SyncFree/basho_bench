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

folder = sys.argv[1]
dict={}
sub_folders = glob.glob(root+'/20*') 
for f in sub_folders:
    input_folder = f #os.path.join(root, f)
    if os.path.isdir(input_folder):
        throughput_file = os.path.join(input_folder, 'specula_out')
        #for node in dict[config]['nodes']: 
        #    dict[config]['nodes'][node]['throughput'] = []
        #    add_throughput(dict[config]['nodes'][node]['throughput'], os.path.join(input_folder, 'summary.csv-'+node))
        add_real_latency('percv_latency', dict[config]['percv_latency'], dict[config]['nodes'], input_folder)
        add_real_latency('final_latency', dict[config]['final_latency'], dict[config]['nodes'], input_folder)
        dict[config]['files'].append(input_folder)

time = strftime("%Y-%m-%d-%H%M%S", gmtime())
output_fold = os.path.join(output, time)
os.mkdir(output_fold)
for config in dict:
    print(config)
    entry = dict[config]
    config_folder = os.path.join(output_fold, config)
    os.mkdir(config_folder)
    files = entry['files']
    nums_file = config_folder +'/' + str(len(files))
    file = open(nums_file, 'w')
    for f in files:
        file.write(f+'\n')
    file.close()

    throughput = os.path.join(config_folder, 'throughput')
    total_throughput = os.path.join(config_folder, 'total_throughput')
    real_latency = os.path.join(config_folder, 'real_latency')

    if len(entry['final_latency']) != 0:
        write_to_file(real_latency, entry, ['percv_latency', 'final_latency'], 'percvlat finallat') 
        write_std(real_latency, entry['percv_latency'])
        write_std(real_latency, entry['final_latency'])

    write_to_file(total_throughput, entry, ['total_throughput'], 'N/A committed all_abort immediate_abort specula_abort abort_rate specula_abort_rate') 
    write_std(total_throughput, entry['total_throughput'])
    #node_file = open(output_fold+'/'+config+'/node_info', 'w')
    #node_file.write('nodes committed all_abort immediate_abort specula_abort abort_rate specula_abort_rate percv_lat real_lat\n')
    #for node in entry['nodes']:
    #    #print(entry['nodes'][node])
    #    throughput = entry['nodes'][node]['throughput']
    #    percv_lat = entry['nodes'][node]['percv_latency']
    #    final_lat = entry['nodes'][node]['final_latency']
    #    node_file.write(node+' '+' '.join(map(str, throughput))+' '+str(percv_lat)+' '+str(final_lat)+'\n')
    #node_file.close()
    
