
" See the article http://dmitryfrank.com/articles/vim_project_code_navigation
" for details on advanced Indexer + Vimprj usage

" get path to ".vimprj" folder
let s:sPath = expand('<sfile>:p:h')

" specify project settings
let &tabstop = 3
let &shiftwidth = 3

let g:indexer_ctagsDontSpecifyFilesIfPossible = 1
let g:indexer_ctagsCommandLineOptions = '--c++-kinds=+p+l --c-kinds=+l --fields=+iaS --extra=+q'


" specify our ".vimprj/.indexer_files"
let g:indexer_indexerListFilename = s:sPath.'/.indexer_files'

