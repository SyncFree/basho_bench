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


baseline_folder='processed_data/tpcc/baseline'
planet_folder='processed_data/tpcc/planet'
int_folder='processed_data/tpcc/internal'
ext_folder='processed_data/tpcc/external'

fig = plt.figure()
ax11 = plt.subplot2grid((3,3), (0,0))
ax12 = plt.subplot2grid((3,3), (1,0))
ax13 = plt.subplot2grid((3,3), (2,0))
ax21 = plt.subplot2grid((3,3), (0,1))
ax22 = plt.subplot2grid((3,3), (1,1))
ax23 = plt.subplot2grid((3,3), (2,1))
ax31 = plt.subplot2grid((3,3), (0,2))
ax32 = plt.subplot2grid((3,3), (1,2))
ax33 = plt.subplot2grid((3,3), (2,2))

#ax1.yaxis.labelpad = 22
#ax2.yaxis.labelpad = 11
time=datetime.now().strftime("%Y%m%d-%H:%M:%S")
output_folder='./figures/eurosys/tpcc/' + time
os.mkdir(output_folder)
dict1={'y_lim':2.5, 'y3_lim':40000, 'legend_type':'warehouse', 'legends':['ClockSI-Rep', 'PLANET', 'STR', 'STR-External'], 'y1_label':'Commits (K txs/s)', 'y2_label':'Abort rate', 'y3_label':'Latency(ms) in log', 'abort_legend':['Abort rate  ', 'Baseline', 'STR: i. abort', 'STR: s. abort'], 'no_title':True, 'x_label': 'Client number', 'th_lim':5, 'lat_lim':100000, 'under_labels':'(a) 5% new order, 83% payment', 'bbox_loc':(1.5,1.42), 'y1pad':14, 'y2pad':14, 'y3pad':10}
dict1['x_ticks']=[10, 100, 200, 400, 600, 800, 1000, 1200]
dict1['sc']={1,3}

[baselineLL]=get_matching_series_delete([baseline_folder, 'tpcc', 7, 8, 5, 83, 1], [], {'order':'ascend'})
baselineLL=sort_by_num(baselineLL)
#baselineLL=baselineLL[:-1]
[planetLL]=get_matching_series_delete([planet_folder, 'tpcc', 7, 8, 5, 83, 1], [], {'order':'ascend'})
planetLL=sort_by_num(planetLL)
#planetLL=planetLL[:-1]
[internalLL]=get_matching_series_delete([int_folder, 'tpcc', 7, 8, 5, 83, 1], [], {'order':'ascend'})
internalLL=sort_by_num(internalLL)
[externalLL]=get_matching_series_delete([ext_folder, 'tpcc', 7, 8, 5, 83, 1], [], {'order':'ascend'})
externalLL=sort_by_num(externalLL)
th, abort, spec_abort, lat = get_compare_data([baseline_folder, planet_folder, int_folder, ext_folder], [baselineLL, planetLL, internalLL, externalLL])
lgd=plot_lines(th, abort, spec_abort, lat, ax11, ax12, ax13, dict1)

dict1['under_labels']='(b) 45% new order, 43% payment'
dict1['legends']=False
dict1['y1_label']=False
dict1['y2_label']=False
dict1['y3_label']=False
dict1['x_ticks']=[20, 200, 400, 800, 1200, 1600]
[baselineLL]=get_matching_series_delete([baseline_folder, 'tpcc', 7, 8, 45, 43, 1], [], {'order':'ascend'})
baselineLL=sort_by_num(baselineLL)
#baselineLL=baselineLL[:-1]
[planetLL]=get_matching_series_delete([planet_folder, 'tpcc', 7, 8, 45, 43, 1], [], {'order':'ascend'})
planetLL=sort_by_num(planetLL)
#planetLL=planetLL[:-1]
[internalLL]=get_matching_series_delete([int_folder, 'tpcc', 7, 8, 45, 43, 1], [], {'order':'ascend'})
internalLL=sort_by_num(internalLL)
[externalLL]=get_matching_series_delete([ext_folder, 'tpcc', 7, 8, 45, 43, 1], [], {'order':'ascend'})
externalLL=sort_by_num(externalLL)
#print("Planet: "+" ".join(planetLL))
#print("Internal: "+" ".join(internalLL))
#print("External: "+" ".join(externalLL))
th, abort, spec_abort, lat = get_compare_data([baseline_folder, planet_folder, int_folder, ext_folder], [baselineLL, planetLL, internalLL, externalLL])
plot_lines(th, abort, spec_abort, lat, ax21, ax22, ax23, dict1)

dict1['under_labels']='(c) 5% new order, 43% payment'
dict1['x_ticks']=[20, 200, 400, 600, 800, 1000, 1200]
[baselineLL]=get_matching_series_delete([baseline_folder, 'tpcc', 7, 8, 5, 43, 1], [], {'order':'ascend'})
baselineLL=sort_by_num(baselineLL)
#baselineLL=baselineLL[:-1]
[planetLL]=get_matching_series_delete([planet_folder, 'tpcc', 7, 8, 5, 43, 1], [], {'order':'ascend'})
planetLL=sort_by_num(planetLL)
#planetLL=planetLL[:-1]
[internalLL]=get_matching_series_delete([int_folder, 'tpcc', 7, 8, 5, 43, 1], [], {'order':'ascend'})
internalLL=sort_by_num(internalLL)
[externalLL]=get_matching_series_delete([ext_folder, 'tpcc', 7, 8, 5, 43, 1], [], {'order':'ascend'})
externalLL=sort_by_num(externalLL)
th, abort, spec_abort, lat = get_compare_data([baseline_folder, planet_folder, int_folder, ext_folder], [baselineLL, planetLL, internalLL, externalLL])
#print("Planet: "+" ".join(planetLL))
#print("Internal: "+" ".join(internalLL))
#print("External: "+" ".join(externalLL))
plot_lines(th, abort, spec_abort, lat, ax31, ax32, ax33, dict1)
#plot_lines(th1, abort1, lat1, ax31, ax32, ax33, dict1)

plt.figtext(0.42, 0.07, "Number of clients per server", fontsize=18)

fig.set_size_inches(20, 7)

plt.tight_layout(pad=1, w_pad=0.5, h_pad=-1)
plt.subplots_adjust(top=0.9)

#plt.tight_layout()
#fig.savefig(output_folder+'/tpcc.pdf', format='pdf', bbox_extra_artists=(lgd,), bbox_inches='tight')
fig.savefig(output_folder+'/tpcc.pdf', format='pdf', bbox_extra_artists=(lgd,))

