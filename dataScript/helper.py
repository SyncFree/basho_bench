#!/usr/bin/env python3

import matplotlib.pyplot as plt
from pylab import *
import glob
import sys
import random
from itertools import chain
from os.path import basename
import os
import numpy as np

def get_compare_data(root_folders, all_names):
    num_lines=len(root_folders)
    tl1=[]
    tl2=[]
    tl3=[]
    for i in range(num_lines):
        l1, l2, l3, l4 = get_data(root_folders[i], all_names[i])
        tl1.append(l1)        
        tl2.append(l2)
        tl3.append([l3, l4])
    return tl1, tl2, tl3

def get_data(root_folder, list_names): 
    th_list=[]
    abort_list=[]
    final_lat_list=[]
    percv_lat_list=[]
    for name in list_names:
        folder = os.path.join(root_folder, name)
        file = os.path.join(folder, 'total_throughput')
        data = np.loadtxt(file, skiprows=1, usecols=range(1,7))
        throughput=data[0,0]/1000
        abort_rate=data[0,4]
                
        lat_file = os.path.join(folder, 'real_latency')
        lat_data = np.loadtxt(lat_file, skiprows=1, usecols=range(1,2))
        percv_latency=lat_data[0]
        final_latency=lat_data[1]
        th_list.append(throughput)
        abort_list.append(abort_rate)
        final_lat_list.append(final_latency)
        percv_lat_list.append(percv_latency)

    #print(th_list)
    #print(abort_list)
    #print(final_lat_list)
    #print(percv_lat_list)
    return th_list, abort_list, final_lat_list, percv_lat_list
        

def get_matching_series(args):
    return get_matching_series_delete(args, [], [])

def get_matching_series_delete(args, toremove, options):
    input_folder = args[0]
    bench_type = args[1]
    length = len(args)
    field_len = int((length-3)/2)
    field_end = 2 + field_len
    value_begin = field_end
    value_end = value_begin + field_len
    diff_fields = args[2:field_end]
    field_values = args[value_begin:value_end]
    rotate_field = args[value_end]
    diff_fields.append(rotate_field)

    rotate_field_set = set()
    sub_folders = glob.glob(input_folder+'/' +('[0-9]')+'*')
    split_names={}
    for f in sub_folders:
        bname = basename(f)
        split_names[bname] = bname.split("_")

    field_dict={}
    for key,value in split_names.items():
        fields=""
        if toremove == []:
            skip = False 
        else:
            skip = True
        for (rindex, rvalue) in toremove:
            if value[rindex] != rvalue:
                skip = False
                break
        if skip == True:
            continue
        print(rotate_field)
        if isinstance(value[int(rotate_field)], int) or value[int(rotate_field)].isdigit(): 
            rotate_field_set.add(int(value[int(rotate_field)]))
        else:
            rotate_field_set.add(value[int(rotate_field)])

        for f in diff_fields:
            fields+="_"+str(value[int(f)]) 
        if fields in field_dict:
            field_dict[fields].append(key) 
        else:
            field_dict[fields] = [key]

    field_value_str = '_'+'_'.join(str(v) for v in field_values) 
    rotate_values=list(rotate_field_set)
    if 'order' in options and options['order'] == 'ascend':
        rotate_values.sort()
    else:
        rotate_values.sort()
        rotate_values.reverse()
    to_plot_params=[field_value_str+'_'+str(x)  for x in rotate_values]
    to_plot_list=[]
    for key in to_plot_params:
        #print(key)
        if key in field_dict:
            to_plot_list.append(field_dict[key])
        else:
            pass
            #print("Warning: "+key+" is not in dict!!!")
    return to_plot_list

def get_matching_serie(args):
    input_folder = args[0]
    bench_type = args[1]
    length = len(args)
    field_len = int((length-2)/2)
    field_end = 2 + field_len
    diff_fields = args[2:field_end]
    field_values = args[field_end:length]

    required_title = "" 
    for f in field_values:
        required_title +="_"+str(f)

    for f in diff_fields:
        sub_folders = glob.glob(input_folder+'/*')


    split_names={}
    for f in sub_folders:
        bname = basename(f)
        split_names[bname] = bname.split("_")

    field_dict={}
    for key,value in split_names.items():
        fields=""
        for f in diff_fields:
            fields+="_"+str(value[int(f)])
        if fields in field_dict:
            field_dict[fields].append(key)
        else:
            field_dict[fields] = [key]

    
    if  required_title not in field_dict:
        return None
    else:
        return field_dict[required_title] 



def get_legend(str_value, type, postfix):
    if type == 'locality':
        value = int(str_value) 
        if value == 20:
            return '80:20'
        elif value == 30:
            return '70:30'
        elif value == 50:
            return '50:50'
        elif value == 80:
            return '20:80'
    elif type == 'process':
        value = int(str_value) 
        if value == 0:
            return '0ms '+postfix
        elif value == 100:
            return '100ms '+postfix
        elif value == 500:
            return '500ms '+postfix
        else:
            return '1000ms '+postfix
    elif type == 'range':
        return str_value+' partitions '+postfix
    elif type == 'thread':
        return str_value+' threads'
    elif type == 'warehouse':
        return str_value+' warehouse'
    elif type == 'clock':
        return str_value+' clock'
    elif type == 'read':
        if str_value == 'nospecula':
            return 'no specula read'
        else:
            return str_value+' read'
    elif type == 'remote read':
        #return str_value+'% remote read'
        return str_value+'%'
    elif type == 'remote servers':
        if str_value == 'false':
            return 'High locality'
        else:
            return str_value+' remote servers'
    else:
        return str_value+' '+type

def get_same(list1, list2):
    index=0
    same=[]
    for e in list1:
        if e == list2[index]:
            same.append(index)  
        index+=1
    return same

def rreplace(s, old, new, occurrence):
    li = s.rsplit(old, occurrence)
    return new.join(li)

def get_title(param_list, type):
    if type == 'tpcc':
        return get_tpcc_title(param_list)
    elif type == 'micro':
        return get_micro_title(param_list)

def get_tpcc_title(param_list):
    split_f=[]
    params=[' threads','% m','% s', 'do_specula', 'fast_reply', ' length',' Ws', '% NewOrder', '% Payment', 'rep', '', '']
    name_params=['T','%M','%S', 'Spec', 'Fast', 'SL', 'W', '%N', '%P', 'R', '', '']
    for f in param_list:
        f=f.replace('false','f').replace('true','t')
        split_f.append(f.split("_"))
    common=split_f[0]
    old_same=set(range(0, len(params)))
    for f in split_f:
        new_same=get_same(f, common)
        old_same=set(old_same) & set(new_same)
    old_same=list(old_same)
    new_split_f=[]
    for f in split_f:
        new_name=[(j, i) for j, i in enumerate(f) if j not in old_same]
        new_str_name=""
        flag=False
        for (i, p) in new_name:
            if i == 3:
                if p=='f':
                    new_str_name+='nosp,'
                    flag=True
                else:
                    new_str_name+='sp,'
            elif i == 4:
                new_str_name=new_str_name
            elif i == 5:
                if flag == True: 
                    new_str_name=new_str_name
                else:
                    new_str_name+=str(p)+str(name_params[i])+','
            else:
                new_str_name+=str(p)+str(name_params[i])+','
        new_split_f.append(new_str_name[:-1])

    title=""
    for f in old_same:
        if f == 3:
            if split_f[0][f]=='f':
                title+='no_spec, '
            else:
                title+='spec, '
        elif f == 4:
            title=title
        else:
            title+=str(split_f[0][f])+str(params[f])+", "
    return title[:-2], new_split_f

def sort_by_num(l):
    d = []
    for s in l:
        sl = s.split('_')
        ssl = []
        for x in sl:
            if is_int(x):
                ssl.append(int(x)) 
            else:
                ssl.append(x)
        d.append((ssl, s))
    d.sort()
    sorted_l = [ y for (x, y) in d ]
    return sorted_l 

def get_micro_title(param_list):
    split_f=[]
    #params=[' threads',' mk',' sk',' ck',' mr', ' sr', ' cr', ' spec', ' spec length', '', 'rep', 'lp']
    #name_params=['T','MK','SK','CK','MR', 'SR', 'CR', 'SPEC', 'SL', 'ap', 'R', 'LP']
    params=[' threads',' mk',' sk',' ck',' mr', ' sr', ' cr', ' spec', ' len', ' read', 'rep', '', 'det', '']
    name_params=['T','MK','SK','CK','MR', 'SR', 'CR', 'SPEC', 'SL', 'SR', 'R', 'LP', '', '']
    for f in param_list:
        f=f.replace('false','f').replace('true','t')
        f=rreplace(f, '000000', 'm', 4)
        f=rreplace(f, '000', 'k', 4)
        split_f.append(f.split("_"))
    common=split_f[0]
    old_same=set(range(0, len(params)))
    for f in split_f:
        new_same=get_same(f, common)
        old_same=set(old_same) & set(new_same)
    old_same=list(old_same)
    new_split_f=[]
    for f in split_f:
        new_name=[(j, i) for j, i in enumerate(f) if j not in old_same]
        new_str_name=""
        flag=False
        for (i, p) in new_name:
            if i == 7:
                if p=='f':
                    new_str_name+='nosp,'
                else:
                    new_str_name+='sp,'
            elif i == 8:
                if flag == True: 
                    new_str_name=new_str_name
                else:
                    new_str_name+=str(p)+str(name_params[i])+','
            else:
                new_str_name+=str(p)+str(name_params[i])+','
        new_split_f.append(new_str_name[:-1])

    title=""
    no_specula_flag=0
    for f in old_same:
        if f == 7:
            if split_f[0][f]=='f':
                title+='no_spec, '
                no_specula_flag=1
            else:
                title=title
        elif f == 8:
            if no_specula_flag==1:
                title=title
            else:
                title+=str(split_f[0][f])+str(params[f])+", "
        else:
            title+=str(split_f[0][f])+str(params[f])+", "
    return title[:-2], new_split_f

def is_int(s):
    try: 
        int(s)
        return True
    except ValueError:
        return False

def draw_bar_if_need(plot, index, width, val_list, color, prev_width, handler):
    base = 0
    i = 0
    if val_list[-1][0] != 0.0:
        for v in val_list:
            if base == 0:
                if isinstance(color[i], tuple):
                    (col, hat) = color[i]
                    plot.bar(index, v[0], width, color=col, hatch=hat)
                else:
                    plot.bar(index, v[0], width, color=color[i])
                base = v[0]
            else:
                if isinstance(color[i], tuple):
                    (col, hat) = color[i]
                    hr = plot.bar(index, v[0], width, color=col, hatch=hat, bottom=base, yerr=v[1])
                else:
                    hr = plot.bar(index, v[0], width, color=color[i], bottom=base, yerr=v[1])
                base += v[0]
            i += 1
        return (prev_width+width, hr)
    else:
        return (prev_width, handler)
