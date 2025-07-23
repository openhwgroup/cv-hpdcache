#!/bin/python3


import matplotlib.pyplot as plt
import numpy as np
from  sys import argv
from os import path
import re
import subprocess 

def usage(file_name: str) -> None:
    print(f"usage : {file_name} <name of a .log file>")

def get_nb_cycle(content_file : str ) -> int:
    matches : list[str] = re.findall(r"^SB.NB_CYCLES            : .*", content_file, re.MULTILINE)
    if not matches:
        print(" Can't find number of cycle")
        exit(1)

    result : int = int(matches[0].split(" ")[-1])
    return result

def get_nb_miss( content_file : str, is_read : bool) -> float:
    """

    Args:
        content_file: 
        is_read:  true -> we search read misses rate false -> write misses

    Returns: the percentage of miss
        
    """
    which : str = "Read" if is_read else "Write"
    to_search : str = f"^{which} miss rate.*"
    matches : list[str] = re.findall(to_search, content_file, re.MULTILINE)

    if not matches:
        print(" Can't find rate of miss")
        exit(1)
    result : float = float(matches[0].split(" ")[-1])
    return result

def display_data(nb_cycles : list[float], read_miss : list[float], write_miss : list[float]) -> None:
    configs : list[str] = ['Default', 'HPC']
    colors : list[str] = ['blue', 'red']
    names : list[str] = ['Number of cycles', 'Read Miss', 'Write miss']
    Y_labels : list[str] = [ 'cycles', 'Rate read', 'Rate write' ]
    range_data : list[list[float]] = []
    real_min : list[float] = []
    data : list[list[float]] = [nb_cycles, read_miss, write_miss]
    for cur_list in data:
        real_min.append(min(cur_list))
        for i in range(len(cur_list)):
            cur_list[i]= cur_list[i] / real_min[-1] 
        range_data.append([ 1 - (max(cur_list) - 1), max(cur_list)])
    
    x = np.arange(len(configs))
    fig, axes = plt.subplots(1, 3, figsize=(15, 5))
    for i in range(3):
        axes[i].bar(x, data[i], color=colors)
        axes[i].set_title(names[i])
        axes[i].set_ylabel(Y_labels[i] + f" minimum reach = {real_min[i]}")
        axes[i].set_xticks(x)
        axes[i].set_ylim(range_data[i][0], range_data[i][1])
        axes[i].set_xticklabels(configs)

    plt.tight_layout()
    plt.show()

def main(parameter: list[str]) -> None:
    if len(parameter) != 2 :
        usage(parameter[0])
        exit(1)
    file_name : str = parameter[1]
    #file_embedded = file_name.replace(".log", "_embedded.log")
    file_HPC : str = file_name.replace(".log", "_HPC.log")
    nb_cycles : list[float] = []
    read_miss : list[float] = []
    write_miss : list[float] = []
    for current_file in [file_name, file_HPC]:
        if not path.exists(current_file):
            print(f"File {current_file} can't be open")
            exit(1)
        result = subprocess.run(f"tail -100 {current_file}", shell=True, capture_output=True, text=True)
        nb_cycles.append(get_nb_cycle(result.stdout))
        read_miss.append(get_nb_miss(result.stdout, True))
        write_miss.append(get_nb_miss(result.stdout, False))

    display_data(nb_cycles, read_miss, write_miss)
    return

if  __name__ == "__main__":
    main(argv)
