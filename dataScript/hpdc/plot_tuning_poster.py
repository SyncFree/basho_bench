#!/usr/bin/env python

import matplotlib.pyplot as plt
from pylab import *
import sys
from copy import deepcopy
import random
#from plot_stress import *
#from plot_speedup_abort import *
from plot_line_share import *
from itertools import chain
import os
import numpy as np
import pandas as pd
import re
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

#s_ss1 = sort_by_num([val for sublist in ss1 for val in sublist])
#s_ns1 = sort_by_num([val for sublist in ns1 for val in sublist])
#plot_stress(s_ss1, s_ns1, input_folder, './figures/macro_stress/', '80,10,10')

#input_folder='./stat/2016-07-20-210337/'
#input_folder='./stat/2016-07-22-024749/'
#input_folder='./stat/2016-07-22-120825/'
#input_folder='./stat/2016-07-22-120825new/'
fig = plt.figure()
ax1 = plt.subplot2grid((1,2), (0,0))
ax2 = plt.subplot2grid((1,2), (0,1))
ax1.yaxis.labelpad = 22
ax2.yaxis.labelpad = 11
time=datetime.now().strftime("%Y%m%d-%H:%M:%S")
output_folder='./figures/vldb/tuning/' + time
os.mkdir(output_folder)
dict1={'y_labels':'Thousand txs/s', 'x_ticks':['No SR', 'SR', 'SR+SL1', 'SR+SL4', 'SR+SL8'], 'y_lim':4.9, 'legend_type':'warehouse', 'commit_legend':['10 clients ClockSI-Rep', '80 clients ClockSI-Rep', '10 clients STR static', '80 clients STR static', '10 clients STR tuning', '80 clients STR tuning'], 'x_labels':'Thousand txs/sec', 'abort_legend':['Abort rate  ', 'Baseline', 'STR: i. abort', 'STR: s. abort'], 'latency_legend':['Latency', 'Baseline', 'STR: observed', 'STR: final'], 'has_legend':True, 'no_title':True, 'out_legend':True, 'x_label': 'Client number', 'th_lim':4.5, 'lat_lim':100000, 'under_labels':'(a) Low local conflict, low remote conflict', 'bbox_loc':(1,1.185)}
dict1['x_labels']=['300 cls', '600 cls', '900 cls', '1200 cls', '1500 cls']
#lgd=plot_multi_lines([[0.84, 0.88, 1.59, 2.77, 3.5], [4.54,4.51,4.02,1.47,0.76]], [0.785, 3.738], [3.6, 4.167], ax1, dict1)
lgd=plot_multi_lines([[0.84, 0.88, 1.59, 2.77, 3.5], [4.01,4.11,3.78,2.3,1.3]], [0.785, 3.738], [3.6, 4.167], ax1, dict1)

#dict1['under_labels']='(b) High local conflict, high remote conflict'
#dict1['out_legend']=False
#dict1['y_labels']=False
#dict1['y_lim']=2.5
#plot_multi_lines([[0.62, 0.74, 1.19, 0.93, 0.59], [2.03, 2.08, 1.24, 0.87, 0.63]], [0.615, 1.876], [1.278, 2.021], ax2, dict1)
dict1['under_labels']='(b) Low local conflict, high remote conflict'
dict1['out_legend']=False
dict1['y_labels']=False
dict1['y_lim']=3.5
plot_multi_lines([[0.733, 0.81, 1.45, 1.93, 1.71], [2.39, 3.07, 2.45, 1.07, 0.89]], [0.732, 2.483], [1.857, 2.967], ax2, dict1)

fig.set_size_inches(16, 7)
#fig.subplots_adjust(hspace = -1)

plt.tight_layout(pad=1.5, w_pad=0, h_pad=0)
plt.subplots_adjust(top=0.87)

#plt.tight_layout()
#fig.savefig(output_folder+'/micro.pdf', format='pdf', bbox_extra_artists=(lgd,), bbox_inches='tight')
fig.savefig(output_folder+'/tuning_poster.pdf', format='pdf', bbox_extra_artists=(lgd,))

