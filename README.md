#RText VIM plugin

This is the RText plugin for VIM.

Learn more about [RText](http://github.com/mthiede/rtext).

##Prerequisites

You must have a version of VIM with Ruby support enabled.
You also have to install the ``rtext`` Ruby gem:

    > gem install rtext

##Installation

Make sure the ``syntax`` folder will be found by your VIM installation. Either copy it directly or use [pathogen](https://github.com/tpope/vim-pathogen) or [vundle](https://github.com/gmarik/vundle).

In order to associate a file type with the RText plugin you could add the following to your vimrc file:

    autocmd BufNewFile,BufReadPost *.myfileext set filetype=rtext

##Usage

When inside buffer with filetype set to "rtext", you can do the following:
* Folding: should work as expected
* Auto Completion: use omni complete
* Follow References: CTRL-]
* Find Elements: use the command RTextFind with a search string as parameter
* Error Annotations: in the quickfix list 

##License

The RText VIM plugin is released under the MIT license.
