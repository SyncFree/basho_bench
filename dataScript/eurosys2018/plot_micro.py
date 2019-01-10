#!/usr/bin/env python

import matplotlib.pyplot as plt
from pylab import *
import sys
from copy import deepcopy
import random
from plot_th_abort_lat import *
from itertools import chain
import os
import numpy as np
import pandas as pd
import re
from plot_line_share import *

sys.path.append('/Users/liz/Documents/MyDocument/repositories/basho_bench/dataScript')
from helper import *
from datetime import datetime

def list_folders(path):
    files=glob.glob(path+"/*")
    specula = []
    for f in  files[:-1]:
        specula.append([f])
    nospecula = [files[-1]]
    return specula, nospecula

def get_field(l, num):
    ll = l.split('_')
    return ll[num]

def get_lists(root_folder, config_str):
    folders = glob.glob(root_folder)
    pattern = re.compile(config_str)
    config_list = []
    for f in folders:
        config_file = os.path.join(f, "config")
        with open(config_file) as fl:
            for line in fl:
                if re.match(pattern, line): 
                    config_list.append((line, f)) 

    return config_list


baseline_folder='processed_data/micro/baseline'
#planet_folder='processed_data/micro/planet'
planet_folder='processed_data/planet_sa'
int_folder='processed_data/micro/internal'
ext_folder='processed_data/micro/external'

fig = plt.figure()
ax11 = plt.subplot2grid((3,4), (0,0))
ax12 = plt.subplot2grid((3,4), (1,0))
ax13 = plt.subplot2grid((3,4), (2,0))
ax21 = plt.subplot2grid((3,4), (0,1))
ax22 = plt.subplot2grid((3,4), (1,1))
ax23 = plt.subplot2grid((3,4), (2,1))
ax31 = plt.subplot2grid((3,4), (0,2))
ax32 = plt.subplot2grid((3,4), (1,2))
ax33 = plt.subplot2grid((3,4), (2,2))
ax41 = plt.subplot2grid((3,4), (0,3))
ax42 = plt.subplot2grid((3,4), (1,3))
ax43 = plt.subplot2grid((3,4), (2,3))


#ax1.yaxis.labelpad = 22
#ax2.yaxis.labelpad = 11
time=datetime.now().strftime("%Y%m%d-%H:%M:%S")
output_folder='./figures/eurosys/micro/' + time
os.mkdir(output_folder)
dict1={'y_lim':4.9, 'legend_type':'warehouse', 'x_ticks':[10,20,40,80], 'legends':['ClockSI-Rep', 'PLANET', 'STR-Internal', 'STR-External'], 'y1_label':'Thousand txs/sec', 'y2_label':'Abort rate', 'y3_label':'Latency(ms) in log', 'abort_legend':['Abort rate  ', 'Baseline', 'STR: i. abort', 'STR: s. abort'], 'no_title':True, 'x_label': 'Client number', 'th_lim':5, 'lat_lim':100000, 'under_labels':'(a) Low local, low remote', 'bbox_loc':(1.48,1.42), 'y1pad':10, 'y2pad':10, 'y3pad':10}
dict1['x_labels']=['300 cls', '600 cls', '900 cls', '1200 cls', '1500 cls']
dict1['sc']= {1,3}

[baselineLL]=get_matching_series_delete([baseline_folder, 'micro', 4, 6, 30000, 15000, 1], [], {'order':'ascend'})
baselineLL=sort_by_num(baselineLL)
baselineLL=baselineLL[:-1]
[planetLL]=get_matching_series_delete([planet_folder, 'micro', 4, 6, 30000, 15000, 1], [], {'order':'ascend'})
planetLL=sort_by_num(planetLL)
#planetLL=planetLL[:-1]
[internalLL]=get_matching_series_delete([int_folder, 'micro', 4, 6, 30000, 15000, 1], [], {'order':'ascend'})
internalLL=sort_by_num(internalLL)
[externalLL]=get_matching_series_delete([ext_folder, 'micro', 4, 6, 30000, 15000, 1], [], {'order':'ascend'})
externalLL=sort_by_num(externalLL)
th, abort, spec_abort, lat = get_compare_data([baseline_folder, planet_folder, int_folder, ext_folder], [baselineLL, planetLL, internalLL, externalLL])
th1=th
abort1=abort
lat1=lat
#print th
lgd=plot_lines(th, abort, spec_abort, lat, ax11, ax12, ax13, dict1)

dict1['under_labels']='(b) High local, low remote'
dict1['legends']=False
dict1['y1_label']=False
dict1['y2_label']=False
dict1['y3_label']=False
[baselineLL]=get_matching_series_delete([baseline_folder, 'micro', 4, 6, 1000, 15000, 1], [], {'order':'ascend'})
baselineLL=sort_by_num(baselineLL)
baselineLL=baselineLL[:-1]
[planetLL]=get_matching_series_delete([planet_folder, 'micro', 4, 6, 1000, 15000, 1], [], {'order':'ascend'})
planetLL=sort_by_num(planetLL)
#planetLL=planetLL[:-1]
[internalLL]=get_matching_series_delete([int_folder, 'micro', 4, 6, 1000, 15000, 1], [], {'order':'ascend'})
internalLL=sort_by_num(internalLL)
[externalLL]=get_matching_series_delete([ext_folder, 'micro', 4, 6, 1000, 15000, 1], [], {'order':'ascend'})
externalLL=sort_by_num(externalLL)
#print("Planet: "+" ".join(planetLL))
#print("Internal: "+" ".join(internalLL))
#print("External: "+" ".join(externalLL))
th, abort, spec_abort, lat = get_compare_data([baseline_folder, planet_folder, int_folder, ext_folder], [baselineLL, planetLL, internalLL, externalLL])
#th, abort, lat = get_compare_data([baseline_folder, planet_folder], [baselineLL, planetLL])
plot_lines(th, abort, spec_abort, lat, ax21, ax22, ax23, dict1)

dict1['under_labels']='(c) Low local, high remote'
[baselineLL]=get_matching_series_delete([baseline_folder, 'micro', 4, 6, 30000, 500, 1], [], {'order':'ascend'})
baselineLL=sort_by_num(baselineLL)
baselineLL=baselineLL[:-1]
[planetLL]=get_matching_series_delete([planet_folder, 'micro', 4, 6, 30000, 500, 1], [], {'order':'ascend'})
planetLL=sort_by_num(planetLL)
#planetLL=planetLL[:-1]
[internalLL]=get_matching_series_delete([int_folder, 'micro', 4, 6, 30000, 500, 1], [], {'order':'ascend'})
internalLL=sort_by_num(internalLL)
[externalLL]=get_matching_series_delete([ext_folder, 'micro', 4, 6, 30000, 500, 1], [], {'order':'ascend'})
externalLL=sort_by_num(externalLL)
th, abort, spec_abort, lat = get_compare_data([baseline_folder, planet_folder, int_folder, ext_folder], [baselineLL, planetLL, internalLL, externalLL])
#print("Planet: "+" ".join(planetLL))
#print("Internal: "+" ".join(internalLL))
#print("External: "+" ".join(externalLL))
plot_lines(th, abort, spec_abort, lat, ax31, ax32, ax33, dict1)
#plot_lines(th1, abort1, lat1, ax31, ax32, ax33, dict1)

dict1['under_labels']='(d) High local, high remote'
[baselineLL]=get_matching_series_delete([baseline_folder, 'micro', 4, 6, 1000, 500, 1], [], {'order':'ascend'})
baselineLL=sort_by_num(baselineLL)
baselineLL=baselineLL[:-1]
[planetLL]=get_matching_series_delete([planet_folder, 'micro', 4, 6, 1000, 500, 1], [], {'order':'ascend'})
planetLL=sort_by_num(planetLL)
#planetLL=planetLL[:-1]
[internalLL]=get_matching_series_delete([int_folder, 'micro', 4, 6, 1000, 500, 1], [], {'order':'ascend'})
internalLL=sort_by_num(internalLL)
[externalLL]=get_matching_series_delete([ext_folder, 'micro', 4, 6, 1000, 500, 1], [], {'order':'ascend'})
externalLL=sort_by_num(externalLL)
th, abort, spec_abort, lat = get_compare_data([baseline_folder, planet_folder, int_folder, ext_folder], [baselineLL, planetLL, internalLL, externalLL])
#print("Planet: "+" ".join(planetLL))
#print("Internal: "+" ".join(internalLL))
#print("External: "+" ".join(externalLL))
#plot_lines([[0.62, 0.74, 1.19, 0.93, 0.59], [2.41, 2.43, 1.14, 0.94, 0.72]], [], [[],[]], ax41, ax42, ax43, dict1)
#plot_lines([[0]], [[0]], [[[0],[0]]], ax41, ax42, ax43, dict1)
#th, abort, lat = get_compare_data([baseline_folder, planet_folder], [baselineLL, planetLL])
plot_lines(th, abort, spec_abort, lat, ax41, ax42, ax43, dict1)

plt.figtext(0.42, 0.11, "Number of clients per server", fontsize=18)

fig.set_size_inches(20, 7)

plt.tight_layout(pad=2, w_pad=0, h_pad=-1)
plt.subplots_adjust(top=0.9)

#plt.tight_layout()
#fig.savefig(output_folder+'/micro.pdf', format='pdf', bbox_extra_artists=(lgd,), bbox_inches='tight')
fig.savefig(output_folder+'/micro_full.pdf', format='pdf', bbox_extra_artists=(lgd,))
#fig.savefig(output_folder+'/micro_full.png', bbox_extra_artists=(lgd,))

