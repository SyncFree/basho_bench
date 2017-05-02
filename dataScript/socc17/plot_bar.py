#!/usr/bin/env python

import matplotlib.pyplot as plt
from pylab import *
import matplotlib as mpl
from helper import *
import sys
import random
import os
import numpy as np
import re

def setHatchThickness(value):
    libpath = matplotlib.__path__[0]
    backend_pdf = libpath + "/backends/backend_pdf.py"
    with open(backend_pdf, "r") as r:
        code = r.read()
        code = re.sub(r'self\.output\((\d+\.\d+|\d+)\,\ Op\.setlinewidth\)',
                   "self.output(%s, Op.setlinewidth)" % str(value), code)
        with open('/tmp/hatch.tmp', "w") as w:
            w.write(code)
        #print backend_pdf
        os.system('sudo mv /tmp/hatch.tmp %s' % backend_pdf)

def output_label(legends, colors, hatches):
    fig = plt.figure()
    figlegend = plt.figure(figsize=(5,2))
    ax = fig.add_subplot(111)
    handlers=[]
    for i in range(len(colors)):
        hlt, = ax.bar(0, 0, 0, hatch=hatches[i], color=colors[i])
        handlers.append(hlt)
    figlegend.legend(handlers, legends, 'center')
    fig.show()
    figlegend.show()
    figlegend.savefig(output_folder+'/'+'legend.pdf', format='pdf', bbox_inches='tight')

# input data
def plot_multi_bars(input_folders, output_folder, specula_list, nospecula_list, legends, types, name, colors, hatches):
    plot_multi_bars(input_folders, output_folder, specula_list, nospecula_list, legends, types, name, colors, hatches, [])

def plot_multi_bars(input_folders, output_folder, specula_list, nospecula_list, legends, types, name, colors, hatches, size):
    setHatchThickness(2)
    width = 0.35
    maxv=0
    handlers = []
    legend = list() 
    marksize=12
    fsize=21
    lsize=20
    mpl.rcParams['ytick.labelsize'] = fsize
    fig, ax = plt.subplots()
    data_l = []
    line_index=0
    length = len(specula_list)
    handlers=[]
    for index, input_folder in enumerate(input_folders):
        bar_width=0.8/length
        bar_start=index+1-0.4
        for i in range(length):
            pos=bar_width*i + bar_start
            specula = specula_list[i]
            nospecula = nospecula_list[i]
            specula_folder = glob.glob(os.path.join(input_folder, specula))[0]
            sppath = specula_folder+'/total_throughput'
            spdata = np.loadtxt(sppath, skiprows=1, usecols=range(1,7))

            #nosppath = os.path.join(input_folder, nospecula+'/total_throughput')
            nospecula_folder = glob.glob(os.path.join(input_folder, nospecula))[0]
            nosppath = nospecula_folder+'/total_throughput'
            nospdata = np.loadtxt(nosppath, skiprows=1, usecols=range(1,7))
            nospthroughput = nospdata[0,0]
            spthroughput = spdata[0,0]
            print(input_folder + nospecula)
            print(spthroughput/nospthroughput)
            if hatches[i] == '':
                hlt, = plt.bar(pos, spthroughput/nospthroughput, bar_width, color=colors[i])
            else:
                #hlt, = plt.bar(pos, spthroughput/nospthroughput, bar_width, color=colors[i], hatch=hatches[i], fill=False)
                #hlt.hatch=hatches[i]
                #hlt.color=color=colors[i]
                #hlt.fill=False
                hlt = ax.add_patch(Polygon([[pos,0], [pos,spthroughput/nospthroughput], [pos+bar_width,spthroughput/nospthroughput], [pos+bar_width,0]], hatch=hatches[i], color=colors[i], fill=False))
            if index == 0:
                handlers.append(hlt)

    plt.legend(handlers, legends, loc=2, fontsize=lsize,labelspacing=0.2, columnspacing=0.2, handletextpad=0.2, borderpad=0.2, ncol=3)
    plt.xticks([x+1 for x in range(len(types))], types, fontsize=fsize)
    plt.xlim([0.5, len(input_folders)+0.5])
    plt.ylim([0, 10])
    plt.ylabel('Speedup', fontsize=fsize)
    plt.gca().yaxis.grid(True)
    if size != []: 
        (w,h) = size 
        fig.set_size_inches(w, h)
    plt.savefig(output_folder+'/'+name+'.pdf', format='pdf', bbox_inches='tight')

