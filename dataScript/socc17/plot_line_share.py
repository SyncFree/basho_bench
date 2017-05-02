#!/usr/bin/env python3

import matplotlib.pyplot as plt
from pylab import *
import sys
import random
import os
import numpy as np
import matplotlib.gridspec as gridspec

def swap(l, i1, i2):
    tmp = l[i1]
    l[i1] = l[i2]
    l[i2] = tmp


def plot_multi_lines(throughput_list, base1, base2, ax1, plot_dict):
    xticks_entry = dict() 
    
    fsize=18
    xlabsize=22
    underlabsize=22
    ylabsize=22
    maxv=0
    max_latency = 0
    handlers = []
    abort_handlers = []
    legend_type = plot_dict['legend_type'] 
    #markers=["o", "v", "s", "o", "D", "v"]
    colors=['#253694', '#41b7c4', '#045a8d', '#a6bddb', '#d0d1e6', '#f6eff7']
    markers=["^", "o", "D", "v"]
    #colors=['#30a152', '#a7bdd9']
    #colors=['#30a152', '#e34932', '#035a8c', '#a7bdd9']
    dashed_ls = ['--', '-.', ':']
    line_index=0
    olsize=20
    marker_size=16
    line_width=5
    num_xticks = 0
    start_pos = 0

    line_index=0
    total_bars = len(throughput_list)
    for i, line in enumerate(base1):
        h, = ax1.plot([0, 2, 4], [line, line, line], color=colors[i], marker=markers[0], linewidth=line_width, ls='--', markersize=marker_size)
        handlers.append(h)

    for th_list in throughput_list:
        #location = [i-offset+line_index*barwidth for i in range(len(th_list))]
        location = [i for i in range(len(th_list))]
        print(location)
        [h] = ax1.plot(location, th_list, color=colors[line_index], linewidth=line_width, marker=markers[2], markersize=marker_size)
        line_index += 1
        handlers.append(h)


    for i, line in enumerate(base2):
        h, = ax1.plot([0, 2, 4], [line, line, line], color=colors[i], marker=markers[1], linewidth=line_width,  markersize=marker_size)
        handlers.append(h)
        
    if  'no_title' not in plot_dict:
        fig.suptitle(plot_dict['title'], fontsize=fsize)

    #ax1.set_xlim([0,4])

    if plot_dict['y_labels'] != False:
        ax1.set_ylabel(plot_dict['y_labels'], fontsize=ylabsize, labelpad=0) 

    if plot_dict['under_labels'] != False:
        ax1.set_xlabel(plot_dict['under_labels'], fontsize=underlabsize) 

    ax1.set_ylim([0,plot_dict['y_lim']])
    #ax1.set_xticks([-0.5,1,2,3,4.5])
    ax1.set_xlim([-0.15, len(plot_dict['x_ticks'])-0.85])
    ax1.set_xticklabels(['']+plot_dict['x_ticks'], minor=False, fontsize=xlabsize)

    #ticks = ax1.get_xticks()
    #ax1.set_xticks(plot_dict['x_ticks'])

    #ax1.set_xticks([0,1,2,3,4],plot_dict['x_ticks'])
    ax1.yaxis.grid(True)
    #mpl.rcParams['ytick.labelsize'] = fsize
    ax1.tick_params(labelsize=fsize)
    if 'y_ticks' in plot_dict and plot_dict['y_ticks'] == False:
        ax1.yaxis.set_major_formatter(NullFormatter())
        
    lgd=0

    print handlers
    if 'has_legend' in plot_dict and plot_dict['has_legend']:
        if 'out_legend' in plot_dict and plot_dict['out_legend']:
            commit_legend = plot_dict['commit_legend']
            print(handlers)
            lgd = ax1.legend(handlers, commit_legend, fontsize=olsize, loc=9, labelspacing=0.1, handletextpad=0.15, borderpad=0.26, bbox_to_anchor=plot_dict['bbox_loc'], ncol=3)
        else:
            pass

    return lgd
