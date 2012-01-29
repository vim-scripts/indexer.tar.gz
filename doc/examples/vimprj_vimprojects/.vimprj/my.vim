
" get path to ".vimprj" folder
let s:sPath = expand('<sfile>:p:h')

" set variable for plugin 'project'
" PLEASE NOTE! You need to modify 'project' plugin
" to make this work
let g:proj_project_filename=s:sPath.'/.vimprojects'

" specify project settings
let &tabstop = 3
let &shiftwidth = 3

let g:indexer_ctagsCommandLineOptions = '--c++-kinds=+p+l --c-kinds=+l --fields=+iaS --extra=+q'


" set variable for plugin 'indexer'
let g:indexer_projectsSettingsFilename = s:sPath.'/.vimprojects'

