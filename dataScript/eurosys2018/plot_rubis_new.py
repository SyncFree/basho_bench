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


baseline_folder='processed_data/rubissocc/baseline'
planet_folder='processed_data/rubissocc/planet'
int_folder='processed_data/rubissocc/internal'
#ext_folder='processed_data/rubissocc/external'

fig = plt.figure()
ax11 = plt.subplot2grid((3,1), (0,0))
ax12 = plt.subplot2grid((3,1), (1,0))
ax13 = plt.subplot2grid((3,1), (2,0))

#ax1.yaxis.labelpad = 22
#ax2.yaxis.labelpad = 11
time=datetime.now().strftime("%Y%m%d-%H:%M:%S")
output_folder='./figures/eurosys/rubis/' + time
os.mkdir(output_folder)
dict1={'y_lim':20, 'y3_lim':40000, 'legend_type':'warehouse', 'legends':['ClockSI-Rep', 'Ext-Spec', 'STR'], 'y1_label':'Commits (K txs/s)', 'y2_label':'Abort rate', 'y3_label':'Latency(ms) in log', 'abort_legend':['Abort rate  ', 'Baseline', 'STR: i. abort', 'STR: s. abort'], 'no_title':True, 'x_label': 'Client number', 'th_lim':5, 'lat_lim':100000, 'bbox_loc':(0.15,1.06), 'under_labels':False, 'y1pad':18, 'y2pad':13, 'y3pad':10}
dict1['x_ticks']=[50, 500, 1000, 2000, 3000, 4000]
dict1['sc']={1,3}

[baselineLL]=get_matching_series_delete([baseline_folder, 'rubis', 4, 'rubis', 1], [], {'order':'ascend'})
baselineLL=sort_by_num(baselineLL)
#baselineLL=baselineLL[:-1]
[planetLL]=get_matching_series_delete([planet_folder, 'rubis', 4, 'rubis', 1], [], {'order':'ascend'})
planetLL=sort_by_num(planetLL)
#planetLL=planetLL[:-1]
[internalLL]=get_matching_series_delete([int_folder, 'rubis', 4, 'rubis', 1], [], {'order':'ascend'})
internalLL=sort_by_num(internalLL)
#[externalLL]=get_matching_series_delete([ext_folder, 'rubis', 4, 'rubis', 1], [], {'order':'ascend'})
#externalLL=sort_by_num(externalLL)
th, abort, spec_abort, lat = get_compare_data([baseline_folder, planet_folder, int_folder], [baselineLL, planetLL, internalLL])
lgd=plot_lines(th, abort, spec_abort, lat, ax11, ax12, ax13, dict1)

plt.figtext(0.35, 0.01, "Number of clients per server", fontsize=18)

fig.set_size_inches(10, 7)

plt.tight_layout(pad=2, w_pad=0, h_pad=-1)
plt.subplots_adjust(top=0.9)

#plt.tight_layout()
#fig.savefig(output_folder+'/tpcc.pdf', format='pdf', bbox_extra_artists=(lgd,), bbox_inches='tight')
fig.savefig(output_folder+'/rubis.pdf', format='pdf', bbox_extra_artists=(lgd,))

