
" See the article http://dmitryfrank.com/articles/vim_project_code_navigation
" for details on advanced Indexer + Vimprj usage

" path to .vimprj folder
let s:sVimprjPath = expand('<sfile>:p:h')

" point Indexer to our local .indexer_files
let g:indexer_indexerListFilename = s:sVimprjPath.'/.indexer_files'

" use libraries tags
exec "set tags+=".$VIMPRJ_ENV__PATH__LIB_1__TAGS
exec "set tags+=".$VIMPRJ_ENV__PATH__LIB_2__TAGS


" setup indentation options for project
set tabstop=4
set shiftwidth=4
set expandtab

