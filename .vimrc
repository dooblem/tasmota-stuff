" Set the filetype based on the file's extension, but only if
" 'filetype' has not already been set

" tasmota scripts looks good with lisp syntax
au BufRead,BufNewFile *.scr setfiletype lisp
