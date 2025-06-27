# HOW TO INSTALL THIS PLUGIN

In order to use the plugin, you need to put this directory in qemu. The path is qemu/contrib/plugins.
In qemu/contrib/plugins you will find a file named "meson.build". In order to compiler this plugin, you just need to add "qemu_plugin" in contrib_plugin array. and, because this plugin need miniz to work, you need to add dependencies for this plugin. To do that :
```
plugin_sources = { 
  'qemu_plugin': files('qemu_plugin/qemu_plugin.c', 'qemu_plugin/miniz.c'),
}

# Then in the for loop :

if i == 'qemu_plugin' 
	srcs = plugin_sources.get(i, files('qemu_plugin/' + i + '.c'))
    include_dir = ['../../include/qemu', 'qemu_plugin']
else
	srcs = plugin_sources.get(i, files(i + '.c'))
    include_dir = ['../../include/qemu']
endif

# end to finish  in shared_module function change 
include_directories : ['../../include/qemu'],
by
include_directories : include_dir,
    
 ```

After this, you can just build qemu like indicate in their README and if you just want to recompile this plugins, you can do 
``` bash
ninja contrib-plugins
```
in qemu/build directory

This plugin is tested only on qemu 10 (stable).

# HOW TO USE THIS PLUGIN

This plugin is compatible with 32 and 64 bits. His purpose is to create trace of memory access. 

##  PARAMETERS
	. mode=<0,1,2> 
	
		# 0 -> we will save operation in binary ( not readeable by humans)
		# 1 -> we will save operation in ascii ( for debugging purpose )  		 
		# 2 -> we don't save operation ( the plugin do nothing, it just register on 
		each operations).
		
	. file_to_write=<path_to_a_file> 
	
		This parameter is used to set the file where the lugin will write
		
	. compress=<true,false> 
	
		 # true ->  We compress data with miniz to gain space on the disk
		 # false -> data are just write directly in te file

You can contact me [here](mailto:tommy.prats@etu.univ-grenoble-alpes.fr)

