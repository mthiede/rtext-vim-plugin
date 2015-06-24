#RText VIM plugin

This is the RText plugin for VIM.

Learn more about [RText](http://github.com/mthiede/rtext).

##Prerequisites

You must have a version of VIM with Ruby support enabled.
You also have to install the ``rtext`` Ruby gem:

    > gem install rtext

If you don't have the latest version, you might have problems. So in this case just update:

    > gem update rtext

##Installation

Make sure the ``syntax`` folder will be found by your VIM installation. Either copy it directly or use [pathogen](https://github.com/tpope/vim-pathogen) or [vundle](https://github.com/gmarik/vundle).

In order to associate a file type with the RText plugin you could add the following to your vimrc file:

    autocmd BufNewFile,BufReadPost *.myext set filetype=rtext

##Usage

The plugin starts the backend service when you first invoke one of the RText commands.
It will find the backend by searching for a ``.rtext`` file in the filesystem, going upwards from the location of the file being edited.

The ``.rtext`` file should have at least two lines:

    *.myext:
    command line of rtext service to start

When inside buffer with filetype set to "rtext", you can do the following:
* Folding: should work as expected
* Auto Completion: use omni complete
* Follow References: CTRL-]
* Find Elements: use the command RTextFind with a search string as parameter
* Error Annotations: in the quickfix list 

Any output from the backend service will be written to your system's temp folder in a file named ``rtext.temp.<sequence number>``.
Check these files if the backend doesn't startup, there may be an exception thrown by the backend. You may also run your backend once directly from the command line, just to make sure that it starts at all.

##License

The RText VIM plugin is released under the MIT license.
