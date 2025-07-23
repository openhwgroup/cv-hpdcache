## Installation

You can run it from a virtual environement. For this 
```bash
    python3 -m venv <name of your directory>
    source <name of your directory>/bin/activate
    pip install -U matplotlib
    pip install PyQt6
```

To exit the virtual environnement :

```bash
    deactivate
```

The purpose of this tool is to have a visualization of differences between 2 configs of the HPDcache.
To use the script you must have three different file for HPC and classic config.
You need to give the path of the default config to the script an it will search the HPC one directly
