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
ax11 = plt.subplot2grid((2,1), (0,0))
ax12 = plt.subplot2grid((2,1), (1,0))

#ax1.yaxis.labelpad = 22
#ax2.yaxis.labelpad = 11
time=datetime.now().strftime("%Y%m%d-%H:%M:%S")
output_folder='./figures/vldb/tpcc/' + time
os.mkdir(output_folder)
dict1={'y_lim':2, 'y3_lim':40000, 'legend_type':'warehouse', 'legends':['ClockSI-Rep', 'PLANET', 'STR-Internal', 'STR-External'], 'y1_label':'Thousand txs/sec', 'y2_label':'Abort rate', 'y3_label':'Latency(ms) in log', 'abort_legend':['Abort rate  ', 'Baseline', 'STR: i. abort', 'STR: s. abort'], 'no_title':True, 'x_label': 'Client number', 'th_lim':5, 'lat_lim':100000, 'under_labels':'(a) 5% new order, 83% payment', 'bbox_loc':(2.1,1.42)}
dict1['x_ticks']=[10, 100, 200, 400, 600, 800]

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
th, abort, lat = get_compare_data([baseline_folder, planet_folder, int_folder, ext_folder], [baselineLL, planetLL, internalLL, externalLL])
print th
print dict1['x_ticks']
lgd=plot_lines(th, [], lat, ax11, ax12, ax12, dict1)

plt.figtext(0.42, 0.11, "Number of clients per server", fontsize=18)

fig.set_size_inches(10, 7)

plt.tight_layout(pad=2, w_pad=0, h_pad=-1)
plt.subplots_adjust(top=0.9)

#plt.tight_layout()
#fig.savefig(output_folder+'/tpcc.pdf', format='pdf', bbox_extra_artists=(lgd,), bbox_inches='tight')
fig.savefig(output_folder+'/poster_tpcc.pdf', format='pdf', bbox_extra_artists=(lgd,))

