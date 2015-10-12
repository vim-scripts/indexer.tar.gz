
" get path to ".vimprj" folder
let s:sPath = expand('<sfile>:p:h')

" set variable for plugin 'project'
" PLEASE NOTE! You need to modify 'project' plugin
" to make this work.
"
" See the article http://dmitryfrank.com/articles/vim_project_code_navigation
" for details
let g:proj_project_filename=s:sPath.'/.vimprojects'

" specify project settings
let &tabstop = 3
let &shiftwidth = 3


" set variable for plugin 'indexer'
let g:indexer_projectsSettingsFilename = s:sPath.'/.vimprojects'

