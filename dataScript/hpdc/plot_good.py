#!/usr/bin/env python

import matplotlib.pyplot as plt
from pylab import *
import sys
from copy import deepcopy
import random
from plot_single_thlat import *
from itertools import chain
import os
import numpy as np
import pandas as pd
import re
import matplotlib
matplotlib.rcParams['pdf.fonttype'] = 42
matplotlib.rcParams['ps.fonttype'] = 42

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


baseline_folder='processed_data/new_tune/2017-10-27-190943'
#planet_folder='processed_data/micro/planet'
planet_folder='processed_data/new_tune/2017-10-27-190943'
int_folder='processed_data/new_tune/2017-10-27-190943'

fig = plt.figure()
ax11 = plt.subplot2grid((3,1), (0,0))
ax12 = plt.subplot2grid((3,1), (1,0))
ax13 = plt.subplot2grid((3,1), (2,0))

#ax1.yaxis.labelpad = 22
#ax2.yaxis.labelpad = 11
time=datetime.now().strftime("%Y%m%d-%H:%M:%S")
output_folder='./figures/hpdc/micro/' + time
os.mkdir(output_folder)
dict1={'y_lim':1.9, 'legend_type':'warehouse', 'x_ticks':[2,5,10,20,30,40], 'legends':['ClockSI-Rep', 'Ext-Spec', 'STR'], 'y1_label':'Commits (K txs/s)', 'y2_label':'Abort rate', 'y3_label':'Latency in log(ms)', 'abort_legend':['Abort rate  ', 'Baseline', 'STR: i. abort', 'STR: s. abort'], 'no_title':True, 'x_label': 'Client number', 'th_lim':5, 'lat_lim':1000000, 'under_labels':'Number of clients per server', 'bbox_loc':(0.44,1.42), 'y1pad':10, 'y2pad':10, 'y3pad':4, 'y3_lim':5000, 'y3_minlim':100}
dict1['x_labels']=['300 cls', '600 cls', '900 cls', '1200 cls', '1500 cls']
dict1['sc']= {1,3}

[baselineLL]=get_matching_series_delete([baseline_folder, 'micro', 7, 9, 'false', 'false', 1], [], {'order':'ascend'})
baselineLL=sort_by_num(baselineLL)
[planetLL]=get_matching_series_delete([planet_folder, 'micro', 7, 9, 'true', 'false', 1], [], {'order':'ascend'})
planetLL=sort_by_num(planetLL)
[internalLL]=get_matching_series_delete([int_folder, 'micro', 7, 9, 'true', 'true', 1], [], {'order':'ascend'})
internalLL=sort_by_num(internalLL)
th, abort, spec_abort, lat = get_compare_data([baseline_folder, planet_folder, int_folder], [baselineLL, planetLL, internalLL])
th= [[t*3 for t in tt] for tt in th]
lgd=plot_lines(th, abort, spec_abort, lat, ax11, ax12, ax13, dict1)


fig.set_size_inches(9, 7)

plt.tight_layout(pad=1, w_pad=0, h_pad=-0)
plt.subplots_adjust(top=0.9)

#plt.tight_layout()
#fig.savefig(output_folder+'/micro.pdf', format='pdf', bbox_extra_artists=(lgd,), bbox_inches='tight')
fig.savefig(output_folder+'/micro_good.pdf', format='pdf', bbox_extra_artists=(lgd,))
#fig.savefig(output_folder+'/micro.png', bbox_extra_artists=(lgd,))

