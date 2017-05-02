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

def plot_lines(th_list, abort_list, spec_abort_list, lat_list, ax1, ax2, ax3, plot_dict):
    xticks_entry = dict() 
    
    fsize=18
    xlabsize=22
    underlabsize=18
    markersize=10
    ylabsize=14
    maxv=0
    max_latency = 0
    handlers = []
    abort_handlers = []
    legend_type = plot_dict['legend_type'] 
    markers=["^", "v", "s", "o", "D", "v"]
    #colors=['#253694', '#41b7c4', '#045a8d', '#a6bddb', '#d0d1e6', '#f6eff7']
    colors=['#30a152', '#e34932', '#035a8c', '#a7bdd9']
    dashed_ls = ['--', '-.', ':']
    line_index=0
    barwidth = 0.3
    olsize=20
    marker_size=14
    line_width=4
    num_xticks = 0
    start_pos = 0

    line_index=0
    total_bars = len(th_list)
    offset = barwidth*total_bars/2
    for i, th in enumerate(th_list):
        if th == []:
            pass
        else:
            if 'x_ticks' in plot_dict:
                print th
                print plot_dict['x_ticks']
                h,  = ax1.plot(plot_dict['x_ticks'], th, color=colors[line_index], marker=markers[line_index], linewidth=line_width, markersize=markersize)
                ax2.plot(plot_dict['x_ticks'], abort_list[line_index], color=colors[line_index], marker=markers[line_index], linewidth=line_width, markersize=markersize)
                if i in plot_dict['sc']:
                    ax2.plot(plot_dict['x_ticks'], spec_abort_list[line_index], color=colors[line_index], ls='--', marker=markers[line_index], linewidth=line_width, markersize=markersize)


                ax3.plot(plot_dict['x_ticks'], lat_list[line_index][0], color=colors[line_index], marker=markers[line_index], linewidth=line_width, markersize=markersize)
                if lat_list[line_index][1][0] != 0:
                    ax3.plot(plot_dict['x_ticks'], lat_list[line_index][1], color=colors[line_index], ls=dashed_ls[0], marker=markers[line_index], linewidth=line_width, markersize=markersize)
            else:
                h,  = ax1.plot(th, color=colors[line_index], marker=markers[line_index], linewidth=line_width, markersize=markersize)
                ax2.plot(abort_list[line_index], color=colors[line_index], marker=markers[line_index], linewidth=line_width, markersize=markersize)
                if i in plot_dict['sc']:
                    ax2.plot(plot_dict['x_ticks'], spec_abort_list[line_index], color=colors[line_index], ls='--', marker=markers[line_index], linewidth=line_width, markersize=markersize)

                ax3.plot(lat_list[line_index][0], color=colors[line_index], marker=markers[line_index], linewidth=line_width, markersize=markersize)
                if lat_list[line_index][1][0] != 0:
                    ax3.plot(lat_list[line_index][1], color=colors[line_index], ls=dashed_ls[0], marker=markers[line_index], linewidth=line_width, markersize=markersize)
        line_index += 1
        handlers.append(h)
        
    if  'no_title' not in plot_dict:
        fig.suptitle(plot_dict['title'], fontsize=fsize)

    ax1.xaxis.set_major_formatter(NullFormatter())
    ax2.xaxis.set_major_formatter(NullFormatter())

    ax2.set_ylim([0,0.99])
    if 'y3_lim' in plot_dict:
        ax3.set_ylim([5, plot_dict['y3_lim']])
    else:
        ax3.set_ylim([5,4000])
    ax3.set_yscale('log')
    #if plot_dict['y_lim'] != 0:
    ax1.set_ylim([0,plot_dict['y_lim']])

    if plot_dict['y1_label'] != False:
        ax1.set_ylabel(plot_dict['y1_label'], fontsize=ylabsize, labelpad=16) 
        ax2.set_ylabel(plot_dict['y2_label'], fontsize=ylabsize, labelpad=14) 
        ax3.set_ylabel(plot_dict['y3_label'], fontsize=ylabsize, labelpad=15) 
    else:
        ax1.yaxis.set_major_formatter(NullFormatter())
        ax2.yaxis.set_major_formatter(NullFormatter())
        ax3.yaxis.set_major_formatter(NullFormatter())

    if plot_dict['under_labels'] != False:
        ax3.set_xlabel(plot_dict['under_labels'], fontsize=underlabsize, labelpad=40) 

    #ax3.set_xticklabels(plot_dict['x_ticks'], minor=False, fontsize=xlabsize)

    #ax1.set_xlim([-0.5,len(plot_dict['x_ticks'])-0.5])
    ax1.yaxis.grid(True)
    ax2.yaxis.grid(True)
    ax3.yaxis.grid(True)
    #mpl.rcParams['ytick.labelsize'] = fsize
    ax1.tick_params(labelsize=fsize)
    if 'y_ticks' in plot_dict and plot_dict['y_ticks'] == False:
        ax1.yaxis.set_major_formatter(NullFormatter())
        
    lgd=0

    if 'legends' in plot_dict and plot_dict['legends']:
        lgd = ax1.legend(handlers, plot_dict['legends'], fontsize=olsize, loc=9, labelspacing=0.1, handletextpad=0.15, borderpad=0.26, bbox_to_anchor=plot_dict['bbox_loc'], ncol=len(handlers))

    return lgd
