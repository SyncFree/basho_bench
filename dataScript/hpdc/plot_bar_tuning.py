#!/usr/bin/env python

import matplotlib.pyplot as plt
from pylab import *
import sys
from copy import deepcopy
import random
from itertools import chain
import os
import numpy as np
import pandas as pd
import re
from datetime import datetime
import matplotlib
matplotlib.rcParams['pdf.fonttype'] = 42
matplotlib.rcParams['ps.fonttype'] = 42

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


def plot_lines(lines1, lines2, lines3, lines4, ax1, plot_dict):
    fsize=18
    xlabsize=25
    underlabsize=25
    ylabsize=25
    yticksize=18
    maxv=0
    max_latency = 0
    handlers = []
    abort_handlers = []
    colors=['#253694', '#41b7c4', '#045a8d', '#a6bddb', '#d0d1e6', '#f6eff7']
    dashed_ls = ['--', '-.', ':']
    olsize=25

    first = max(lines1[:2])
    lines1 = [1.0*n/first for n in lines1]
    first = max(lines2[:2])
    lines2 = [1.0*n/first for n in lines2]
    first = max(lines3[:2])
    lines3 = [1.0*n/first for n in lines3]
    first = max(lines4[:2])
    lines4 = [1.0*n/first for n in lines4]
    location1 = [0.6, 0.8, 1]
    location2 = [n+1 for n in location1]
    location3 = [n+1 for n in location2]
    location4 = [n+1 for n in location3]

    NOSR=[lines1[0], lines2[0], lines3[0], lines4[0]]
    SR=[lines1[1], lines2[1], lines3[1], lines4[1]]
    Tuning=[lines1[2], lines2[2], lines3[2], lines4[2]]

    NOSRLoc=[location1[0], location2[0], location3[0], location4[0]]
    SRLoc=[location1[1], location2[1], location3[1], location4[1]]
    TuningLoc=[location1[2], location2[2], location3[2], location4[2]]

    h = ax1.bar(NOSRLoc, NOSR, color=colors[0], width=0.2)
    handlers.append(h)
    h = ax1.bar(SRLoc, SR, color=colors[1], width=0.2)
    handlers.append(h)
    h = ax1.bar(TuningLoc, Tuning, color=colors[2], width=0.2)
    handlers.append(h)

    text_h = 0.09
    plt.figtext(0.09, text_h, "Synth-A, 2 clients", fontsize=fsize)
    plt.figtext(0.33, text_h, "Synth-A, 40 clients", fontsize=fsize)
    plt.figtext(0.57, text_h, "Synth-B, 2 clients", fontsize=fsize)
    plt.figtext(0.8, text_h, "Synth-B, 40 clients", fontsize=fsize)

    ax1.set_ylim([0, 1.5])
    ax1.yaxis.grid(True)
    ax1.xaxis.set_major_formatter(NullFormatter())
    lgd = ax1.legend(handlers, ['No SR', 'SR', 'Auto'], fontsize=olsize, labelspacing=0.1, handletextpad=0.15, borderpad=0.26)
    for tick in ax1.yaxis.get_major_ticks():
        tick.label.set_fontsize(yticksize) 
    ax1.set_ylabel('Normalized throughput', fontsize=ylabsize, labelpad=20)
    ax1.set_xlabel('Workload configurations', fontsize=ylabsize, labelpad=30)

fig = plt.figure()
ax1 = fig.gca() 
time = datetime.now().strftime("%Y%m%d-%H:%M:%S")
output_folder='./figures/hpdc/tuning/' + time
os.mkdir(output_folder)
dict1={'y_labels':'Commits (K txs/s)', 'x_ticks':['No SR', 'SR', 'SR+SL1', 'SR+SL4', 'SR+SL8'], 'y_lim':4.9, 'legend_type':'warehouse', 'commit_legend':['10 clients ClockSI-Rep', '80 clients ClockSI-Rep', '10 clients STR static', '80 clients STR static', '10 clients STR tuning', '80 clients STR tuning'], 'x_labels':'Thousand txs/sec', 'abort_legend':['Abort rate  ', 'Baseline', 'STR: i. abort', 'STR: s. abort'], 'latency_legend':['Latency', 'Baseline', 'STR: observed', 'STR: final'], 'has_legend':True, 'no_title':True, 'out_legend':True, 'x_label': 'Client number', 'th_lim':4.5, 'lat_lim':100000, 'under_labels':'(a) High local, low remote', 'bbox_loc':(1.1,1.24)}
dict1['x_labels']=['300 cls', '600 cls', '900 cls', '1200 cls', '1500 cls']
th1=[47, 60, 60]
th2=[46, 554, 541]
th3=[57, 58, 57]
th4=[272, 175, 279]
lgd=plot_lines(th1, th2, th3, th4, ax1, dict1)

#if dict1['y_labels'] != False:
#    ax1.set_ylabel(plot_dict['y_labels'], fontsize=ylabsize, labelpad=0)

fig.set_size_inches(12, 7)

plt.tight_layout(pad=1, w_pad=0, h_pad=0)
#plt.subplots_adjust(top=0.82)

fig.savefig(output_folder+'/bar_tuning.pdf', format='pdf', bbox_extra_artists=(lgd,))

