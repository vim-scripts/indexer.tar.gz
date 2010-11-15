"=============================================================================
" File:        indexer.vim
" Author:      Dmitry Frank (dimon.frank@gmail.com)
" Last Change: 15 Nov 2010
" Version:     2.01
"=============================================================================
" See documentation in accompanying help file
" You may use this code in whatever way you see fit.

"TODO:
" *) test on paths with spaces, both on Linux and Windows
" *) test with one .vimprojects and .indexer_files file, define projectName
" *) rename indexer_ctagsDontSpecifyFilesIfPossible to indexer_ctagsUseDirs or
"    something
" *) make #pragma_index_none,
"         #pragma_index_dir,
"         #pragma_index_files
" *) ability to define one file in .indexer_files
" *) maybe checking whether or not ctags is version 5.8.1
" *) maybe checking whether or not sed is present
" *) maybe checking whether or not sed is correctly parsing ( \\\\ or \\ )

" s:ParsePath(sPath)
"   changing '\' to '/' or vice versa depending on OS (MS Windows or not) also calls simplify()
function! s:ParsePath(sPath)
   if (has('win32') || has('win64'))
      let l:sPath = substitute(a:sPath, '/', '\', 'g')
   else
      let l:sPath = substitute(a:sPath, '\', '/', 'g')
   endif
   let l:sPath = simplify(l:sPath)

   " removing last "/" or "\"
   let l:sLastSymb = strpart(l:sPath, (strlen(l:sPath) - 1), 1)
   if (l:sLastSymb == '/' || l:sLastSymb == '\')
      let l:sPath = strpart(l:sPath, 0, (strlen(l:sPath) - 1))
   endif
   return l:sPath
endfunction

" s:Trim(sString)
" trims spaces from begin and end of string
function! s:Trim(sString)
   return substitute(substitute(a:sString, '^\s\+', '', ''), '\s\+$', '', '')
endfunction

" s:IsAbsolutePath(path) <<<
"   this function from project.vim is written by Aric Blumer.
"   Returns true if filename has an absolute path.
function! s:IsAbsolutePath(path)
   if a:path =~ '^ftp:' || a:path =~ '^rcp:' || a:path =~ '^scp:' || a:path =~ '^http:'
      return 2
   endif
   let path=expand(a:path) " Expand any environment variables that might be in the path
   if path[0] == '/' || path[0] == '~' || path[0] == '\\' || path[1] == ':'
      return 1
   endif
   return 0
endfunction " >>>



function! s:GetDirsAndFilesFromIndexerList(aLines, projectName, dExistsResult)
   let l:aLines = a:aLines
   let l:dResult = a:dExistsResult
   let l:boolInNeededProject = (a:projectName == '' ? 1 : 0)
   let l:boolInProjectsParentSection = 0
   let l:sProjectsParentFilter = ''

   let l:sCurProjName = ''

   for l:sLine in l:aLines

      " if line is not empty
      if l:sLine !~ '^\s*$' && l:sLine !~ '^\s*\#.*$'

         " look for project name [PrjName]
         let myMatch = matchlist(l:sLine, '^\s*\[\([^\]]\+\)\]')

         if (len(myMatch) > 0)

            " check for PROJECTS_PARENT section

            if (strpart(myMatch[1], 0, 15) == 'PROJECTS_PARENT')
               " this is projects parent section
               let l:sProjectsParentFilter = ''
               let filterMatch = matchlist(myMatch[1], 'filter="\([^"]\+\)"')
               if (len(filterMatch) > 0)
                  let l:sProjectsParentFilter = filterMatch[1]
               endif
               let l:boolInProjectsParentSection = 1
            else
               let l:boolInProjectsParentSection = 0


               if (a:projectName != '')
                  if (myMatch[1] == a:projectName)
                     let l:boolInNeededProject = 1
                  else
                     let l:boolInNeededProject = 0
                  endif
               endif

               if l:boolInNeededProject
                  let l:sCurProjName = myMatch[1]
                  let l:dResult[l:sCurProjName] = { 'files': [], 'paths': [], 'not_exist': [], 'pathsForCtags': [], 'pathsRoot': [] }
               endif
            endif
         else

            if l:boolInProjectsParentSection
               " parsing one project parent

               let l:lFilter = split(l:sProjectsParentFilter, ' ')
               if (len(l:lFilter) == 0)
                  let l:lFilter = ['*']
               endif
               " removing \/* from end of path
               let l:projectsParent = substitute(<SID>Trim(l:sLine), '[\\/*]\+$', '', '')

               " creating list of projects
               let l:lProjects = split(expand(l:projectsParent.'/*'), '\n')
               let l:lIndexerFilesList = []
               for l:sPrj in l:lProjects
                  if (isdirectory(l:sPrj))
                     call add(l:lIndexerFilesList, '['.substitute(l:sPrj, '^.*[\\/]\([^\\/]\+\)$', '\1', '').']')
                     for l:sCurFilter in l:lFilter
                        call add(l:lIndexerFilesList, l:sPrj.'/**/'.l:sCurFilter)
                     endfor
                     call add(l:lIndexerFilesList, '')
                  endif
               endfor
               " parsing this list
               let l:dResult = <SID>GetDirsAndFilesFromIndexerList(l:lIndexerFilesList, a:projectName, l:dResult)
               
            elseif l:boolInNeededProject
               " looks like there's path
               if l:sCurProjName == ''
                  let l:sCurProjName = 'noname'
                  let l:dResult[l:sCurProjName] = { 'files': [], 'paths': [], 'not_exist': [], 'pathsForCtags': [], 'pathsRoot': [] }
               endif

               " we should separately expand every variable
               " like $BLABLABLA
               let l:sPatt = "\\v(\\$[a-zA-Z0-9_]+)"
               while (1)
                  let varMatch = matchlist(l:sLine, l:sPatt)
                  " if there's any $BLABLA in string
                  if (len(varMatch) > 0)
                     " changing one slash in value to doubleslash
                     let l:sTmp = substitute(expand(varMatch[1]), "\\\\", "\\\\\\\\", "g")
                     " changing $BLABLA to its value (doubleslashed)
                     let l:sLine = substitute(l:sLine, l:sPatt, l:sTmp, "")
                  else 
                     break
                  endif
               endwhile

               let l:sTmpLine = l:sLine
               " removing last part of path (removing all after last slash)
               let l:sTmpLine = substitute(l:sTmpLine, '^\(.*\)[\\/][^\\/]\+$', '\1', 'g')
               " removing asterisks at end of line
               let l:sTmpLine = substitute(l:sTmpLine, '^\([^*]\+\).*$', '\1', '')
               " removing final slash
               let l:sTmpLine = substitute(l:sTmpLine, '[\\/]$', '', '')

               let l:dResult[l:sCurProjName].pathsRoot = <SID>ConcatLists(l:dResult[l:sCurProjName].pathsRoot, [<SID>ParsePath(l:sTmpLine)])
               let l:dResult[l:sCurProjName].paths = <SID>ConcatLists(l:dResult[l:sCurProjName].paths, [<SID>ParsePath(l:sTmpLine)])

               " -- now we should generate all subdirs

               " getting string with all subdirs
               let l:sDirs = expand(l:sTmpLine."/**/")
               " removing final slash at end of every dir
               let l:sDirs = substitute(l:sDirs, '\v[\\/](\n|$)', '\1', 'g')
               " getting list from string
               let l:lDirs = split(l:sDirs, '\n')


               let l:dResult[l:sCurProjName].paths = <SID>ConcatLists(l:dResult[l:sCurProjName].paths, l:lDirs)


               if (!s:boolUseDirsInsteadOfFiles)
                  " adding every file.
                  let l:dResult[l:sCurProjName].files = <SID>ConcatLists(l:dResult[l:sCurProjName].files, split(expand(substitute(<SID>Trim(l:sLine), '\\\*\*', '**', 'g')), '\n'))
               else
                  " adding just paths. (much more faster)
                  let l:dResult[l:sCurProjName].pathsForCtags = l:dResult[l:sCurProjName].pathsRoot
               endif
            endif

         endif
      endif

   endfor

   return l:dResult
endfunction

" getting dictionary with files, paths and non-existing files from indexer
" project file
function! s:GetDirsAndFilesFromIndexerFile(indexerFile, projectName)
   let l:aLines = readfile(a:indexerFile)
   let l:dResult = {}
   let l:dResult = <SID>GetDirsAndFilesFromIndexerList(l:aLines, a:projectName, l:dResult)
   return l:dResult
endfunction

" getting dictionary with files, paths and non-existing files from
" project.vim's project file
function! s:GetDirsAndFilesFromProjectFile(projectFile, projectName)
   let l:aLines = readfile(a:projectFile)
   " if projectName is empty, then we should add files from whole projectFile
   let l:boolInNeededProject = (a:projectName == '' ? 1 : 0)

   let l:iOpenedBraces = 0 " current count of opened { }
   let l:iOpenedBracesAtProjectStart = 0
   let l:aPaths = [] " paths stack
   let l:sLastFoundPath = ''

   let l:dResult = {}
   let l:sCurProjName = ''

   for l:sLine in l:aLines
      " ignoring comments
      if l:sLine =~ '^#' | continue | endif

      let l:sLine = substitute(l:sLine, '#.\+$', '' ,'')
      " searching for closing brace { }
      let sTmpLine = l:sLine
      while (sTmpLine =~ '}')
         let l:iOpenedBraces = l:iOpenedBraces - 1

         " if projectName is defined and there was last brace closed, then we
         " are finished parsing needed project
         if (l:iOpenedBraces <= l:iOpenedBracesAtProjectStart) && a:projectName != ''
            let l:boolInNeededProject = 0
            " TODO: total break
         endif
         call remove(l:aPaths, len(l:aPaths) - 1)

         let sTmpLine = substitute(sTmpLine, '}', '', '')
      endwhile

      " searching for blabla=qweqwe
      let myMatch = matchlist(l:sLine, '\s*\(.\{-}\)=\(.\{-}\)\\\@<!\(\s\|$\)')
      if (len(myMatch) > 0)
         " now we found start of project folder or subfolder
         "
         if !l:boolInNeededProject
            if (a:projectName != '' && myMatch[1] == a:projectName)
               let l:iOpenedBracesAtProjectStart = l:iOpenedBraces
               let l:boolInNeededProject = 1
            endif
         endif

         if l:boolInNeededProject && (l:iOpenedBraces == l:iOpenedBracesAtProjectStart)
            let l:sCurProjName = myMatch[1]
            let l:dResult[myMatch[1]] = { 'files': [], 'paths': [], 'not_exist': [], 'pathsForCtags': [], 'pathsRoot': [] }
         endif

         let l:sLastFoundPath = myMatch[2]
         " ADDED! Jkooij
         " Strip the path of surrounding " characters, if there are any
         let l:sLastFoundPath = substitute(l:sLastFoundPath, "\"\\(.*\\)\"", "\\1", "g")
         let l:sLastFoundPath = expand(l:sLastFoundPath) " Expand any environment variables that might be in the path
         let l:sLastFoundPath = s:ParsePath(l:sLastFoundPath)

      endif

      " searching for opening brace { }
      let sTmpLine = l:sLine
      while (sTmpLine =~ '{')

         if (s:IsAbsolutePath(l:sLastFoundPath) || len(l:aPaths) == 0)
            call add(l:aPaths, s:ParsePath(l:sLastFoundPath))
         else
            call add(l:aPaths, s:ParsePath(l:aPaths[len(l:aPaths) - 1].'/'.l:sLastFoundPath))
         endif

         let l:iOpenedBraces = l:iOpenedBraces + 1

         " adding current path to paths list if we are in needed project.
         if (l:boolInNeededProject && l:iOpenedBraces > l:iOpenedBracesAtProjectStart && isdirectory(l:aPaths[len(l:aPaths) - 1]))
            " adding to paths (that are with all subfolders)
            call add(l:dResult[l:sCurProjName].paths, l:aPaths[len(l:aPaths) - 1])
            " if last found path was absolute, then adding it to pathsRoot
            if (s:IsAbsolutePath(l:sLastFoundPath))
               call add(l:dResult[l:sCurProjName].pathsRoot, l:aPaths[len(l:aPaths) - 1])
            endif
         endif

         let sTmpLine = substitute(sTmpLine, '{', '', '')
      endwhile

      " searching for filename (if there's files-mode, not dir-mode)
      if (!s:boolUseDirsInsteadOfFiles)
         if (l:sLine =~ '^[^={}]*$' && l:sLine !~ '^\s*$')
            " here we found something like filename
            "
            if (l:boolInNeededProject && (!g:indexer_enableWhenProjectDirFound || s:indexer_projectName != '') && l:iOpenedBraces > l:iOpenedBracesAtProjectStart)
               " we are in needed project
               "let l:sCurFilename = expand(s:ParsePath(l:aPaths[len(l:aPaths) - 1].'/'.s:Trim(l:sLine)))
               " CHANGED! Jkooij
               " expand() will change slashes based on 'shellslash' flag,
               " so call s:ParsePath() on expand() result for consistent slashes
               let l:sCurFilename = s:ParsePath(expand(l:aPaths[len(l:aPaths) - 1].'/'.s:Trim(l:sLine)))
               if (filereadable(l:sCurFilename))
                  " file readable! adding it
                  call add(l:dResult[l:sCurProjName].files, l:sCurFilename)
               elseif (!isdirectory(l:sCurFilename))
                  call add(l:dResult[l:sCurProjName].not_exist, l:sCurFilename)
               endif
            endif

         endif
      endif

   endfor

   " if there's dir-mode then let's set pathsForCtags = pathsRoot
   if (s:boolUseDirsInsteadOfFiles)
      for l:sKey in keys(l:dResult)
         let l:dResult[l:sKey].pathsForCtags = l:dResult[l:sKey].pathsRoot
      endfor
      
   endif

   return l:dResult
endfunction

" returns whether or not file exists in list
function! s:IsFileExistsInList(aList, sFilename)
   let l:sFilename = s:ParsePath(a:sFilename)
   if (index(a:aList, l:sFilename, 0, 1)) >= 0
      return 1
   endif
   return 0
endfunction

" generates command to call ctags apparently params.
" params:
"   dParams {
"      append,    // 1 or 0
"      recursive, // 1 or 0
"      sTagsFile, // ".."
"      sFiles,    // ".."
"   }
function! s:GetCtagsCommand(dParams)
   let l:sAppendCode = ''
   let l:sRecurseCode = ''

   if (a:dParams.append)
      let l:sAppendCode = '-a'
   endif

   if (a:dParams.recursive)
      let l:sRecurseCode = '-R'
   endif

   " when using append without Sed we SHOULD use sort, because of if there's no sort, then
   " symbols will be doubled.
   "
   " when using append with Sed we SHOULD NOT use sort, because of if there's sort, then
   " tags file becomes damaged, i can't figure out why.
   "
   if (g:indexer_ctagsJustAppendTagsAtFileSave && g:indexer_useSedWhenAppend)
      let l:sSortCode = '--sort=no'
   else
      let l:sSortCode = '--sort=yes'
   endif

   let l:sTagsFile = '"'.a:dParams.sTagsFile.'"'
   if (has('win32') || has('win64'))
      let l:sCmd = 'ctags -f '.l:sTagsFile.' '.l:sRecurseCode.' '.l:sAppendCode.' '.l:sSortCode.' '.g:indexer_ctagsCommandLineOptions.' '.a:dParams.sFiles
   else
      let l:sCmd = 'ctags -f '.l:sTagsFile.' '.l:sRecurseCode.' '.l:sAppendCode.' '.l:sSortCode.' '.g:indexer_ctagsCommandLineOptions.' '.a:dParams.sFiles.' &'
   endif
   return l:sCmd
endfunction

" executes ctags called with specified params.
" params look in comments to s:GetCtagsCommand()
function! s:ExecCtags(dParams)
   let l:sCmd = <SID>GetCtagsCommand(a:dParams)
   let l:resp = system(l:sCmd)
endfunction


" builds list of files (or dirs) and executes Ctags.
" If list is too long (if command is more that g:indexer_maxOSCommandLen)
" then executes ctags several times.
" params:
"   dParams {
"      lFilelist, // [..]
"      sTagsFile, // ".."
"      recursive  // 1 or 0
"   }
function! s:ExecCtagsForListOfFiles(dParams)

   " we need to know length of command to call ctags (without any files)
   let l:sCmd = <SID>GetCtagsCommand({'append': 1, 'recursive': a:dParams.recursive, 'sTagsFile': a:dParams.sTagsFile, 'sFiles': ""})
   let l:iCmdLen = strlen(l:sCmd)


   " now enumerating files
   let l:sFiles = ''
   for l:sCurFile in a:dParams.lFilelist

      " if command with next file will be too long, then executing command
      " BEFORE than appending next file to list
      if ((strlen(l:sFiles) + strlen(l:sCurFile) + l:iCmdLen) > g:indexer_maxOSCommandLen)
         call <SID>ExecCtags({'append': 1, 'recursive': a:dParams.recursive, 'sTagsFile': a:dParams.sTagsFile, 'sFiles': l:sFiles})
         let l:sFiles = ''
      endif

      let l:sFiles = l:sFiles.' "'.l:sCurFile.'"'
   endfor

   if (l:sFiles != '')
      call <SID>ExecCtags({'append': 1, 'recursive': a:dParams.recursive, 'sTagsFile': a:dParams.sTagsFile, 'sFiles': l:sFiles})
   endif

endfunction


function! s:ExecSed(dParams)
   " linux: all should work
   " windows: cygwin works, non-cygwin needs \\ instead of \\\\
   let l:sFilenameToDeleteTagsWith = a:dParams.sFilenameToDeleteTagsWith
   let l:sFilenameToDeleteTagsWith = substitute(l:sFilenameToDeleteTagsWith, "\\\\", "\\\\\\\\\\\\\\\\", "g")
   let l:sFilenameToDeleteTagsWith = substitute(l:sFilenameToDeleteTagsWith, "\\.", "\\\\\\\\.", "g")
   let l:sFilenameToDeleteTagsWith = substitute(l:sFilenameToDeleteTagsWith, "\\/", "\\\\\\\\/", "g")
   
   let l:sCmd = "sed -e \"/".l:sFilenameToDeleteTagsWith."/d\" -i \"".a:dParams.sTagsFile."\""
   let l:resp = system(l:sCmd)
endfunction

" updating tags using ctags.
" if boolAppend then just appends existing tags file with new tags from
" current file (%)
function! s:UpdateTags(boolAppend)

   " one tags file
   
   let l:sTagsFileWOPath = substitute(join(g:indexer_indexedProjects, '_'), '\s', '_', 'g')
   let l:sTagsFile = s:tagsDirname.'/'.l:sTagsFileWOPath
   if !isdirectory(s:tagsDirname)
      call mkdir(s:tagsDirname, "p")
   endif

   " if saved file is present in non-existing filelist then moving file from non-existing list to existing list
   let l:sSavedFile = <SID>ParsePath(expand('%:p'))
   let l:sSavedFilePath = <SID>ParsePath(expand('%:p:h'))
   if (<SID>IsFileExistsInList(s:dParseGlobal.not_exist, l:sSavedFile))
      call remove(s:dParseGlobal.not_exist, index(s:dParseGlobal.not_exist, l:sSavedFile))
      call add(s:dParseGlobal.files, l:sSavedFile)
   endif

   let l:sRecurseCode = ''


   if (<SID>IsFileExistsInList(s:dParseGlobal.files, l:sSavedFile) || <SID>IsFileExistsInList(s:dParseGlobal.paths, l:sSavedFilePath))

      if (a:boolAppend && filereadable(l:sTagsFile))
         " just appending tags from just saved file. (from one file!)
         if (g:indexer_useSedWhenAppend)
            call <SID>ExecSed({'sTagsFile': l:sTagsFile, 'sFilenameToDeleteTagsWith': l:sSavedFile})
         endif
         call <SID>ExecCtags({'append': 1, 'recursive': 0, 'sTagsFile': l:sTagsFile, 'sFiles': l:sSavedFile})
      else
         " need no rebuild all tags.
         
         " deleting old tagsfile
         if (filereadable(l:sTagsFile))
             call delete(l:sTagsFile)
         endif

         " generating tags for files
         call <SID>ExecCtagsForListOfFiles({'lFilelist': s:dParseGlobal.files,          'sTagsFile': l:sTagsFile,  'recursive': 0})
         " generating tags for directories
         call <SID>ExecCtagsForListOfFiles({'lFilelist': s:dParseGlobal.pathsForCtags,  'sTagsFile': l:sTagsFile,  'recursive': 1})

      endif
   endif

   " specifying tags in Vim
   exec 'set tags+='.substitute(s:tagsDirname.'/'.l:sTagsFileWOPath, ' ', '\\\\\\ ', 'g')
endfunction

function! s:ApplyProjectSettings()
   " paths for Vim
   "set path=.
   for l:sPath in s:dParseGlobal.paths
      if isdirectory(l:sPath)
         exec 'set path+='.substitute(l:sPath, ' ', '\\ ', 'g')
      endif
   endfor

   augroup Indexer_SavSrcFile
      autocmd! Indexer_SavSrcFile BufWritePost
   augroup END

   if (!s:boolUseDirsInsteadOfFiles)
      " If plugin knows every filename, then
      " collect extensions of files in project to make autocmd on save these
      " files
      let l:sExtsList = ''
      let l:lFullList = s:dParseGlobal.files + s:dParseGlobal.not_exist
      for l:lFile in l:lFullList
         let l:sExt = substitute(l:lFile, '^.*\([.\\/][^.\\/]\+\)$', '\1', '')
         if strpart(l:sExt, 0, 1) != '.'
            let l:sExt = strpart(l:sExt, 1)
         endif
         if (stridx(l:sExtsList, l:sExt) == -1)
            if (l:sExtsList != '')
               let l:sExtsList = l:sExtsList.','
            endif
            let l:sExtsList = l:sExtsList.'*'.l:sExt
         endif
      endfor

      " defining autocmd at source files save
      exec 'autocmd Indexer_SavSrcFile BufWritePost '.l:sExtsList.' call <SID>UpdateTags('.(g:indexer_ctagsJustAppendTagsAtFileSave ? '1' : '0').')'
   else
      " if plugin knows just directories, then it will update tags at any
      " filesave.
      exec 'autocmd Indexer_SavSrcFile BufWritePost * call <SID>UpdateTags('.(g:indexer_ctagsJustAppendTagsAtFileSave ? '1' : '0').')'
   endif

   " start full tags update
   call <SID>UpdateTags(0)
endfunction

" concatenates two lists preventing duplicates
function! s:ConcatLists(lExistingList, lAddingList)
   let l:lResList = a:lExistingList
   for l:sItem in a:lAddingList
      if (index(l:lResList, l:sItem) == -1)
         call add(l:lResList, l:sItem)
      endif
   endfor
   return l:lResList
endfunction

function! s:GetDirsAndFilesFromAvailableFile()
   if (filereadable(g:indexer_indexerListFilename))
      " read all projects from proj file

      let s:sMode = 'IndexerFile'
      let s:dParseAll = s:GetDirsAndFilesFromIndexerFile(g:indexer_indexerListFilename, s:indexer_projectName)

   elseif (filereadable(g:indexer_projectsSettingsFilename))
      " read all projects from indexer file
      let s:sMode = 'ProjectFile'
      let s:dParseAll = s:GetDirsAndFilesFromProjectFile(g:indexer_projectsSettingsFilename, s:indexer_projectName)
   else
      let s:sMode = ''
      let s:dParseAll = {}
   endif
endfunction

function! s:ParseProjectSettingsFile()
   call <SID>GetDirsAndFilesFromAvailableFile()

   " let's found what files we should to index.
   " now we will search for project directory up by dir tree
   let l:i = 0
   let l:sCurPath = ''

   while (g:indexer_enableWhenProjectDirFound && s:indexer_projectName == '' && l:i < 10)
      for l:sKey in keys(s:dParseAll)
         if (<SID>IsFileExistsInList(s:dParseAll[l:sKey].paths, expand('%:p:h').l:sCurPath))
            let s:indexer_projectName = l:sKey
            if !(s:boolUseDirsInsteadOfFiles)
               call <SID>GetDirsAndFilesFromAvailableFile()
            else
               call add(g:indexer_indexedProjects, l:sKey)
            endif
            break
         endif
      endfor
      let l:sCurPath = l:sCurPath.'/..'
      let l:i = l:i + 1
   endwhile

   if !(s:boolUseDirsInsteadOfFiles)
      let s:iTotalFilesAvailableCnt = 0
      if (!s:boolIndexingModeOn)
         for l:sKey in keys(s:dParseAll)
            let s:iTotalFilesAvailableCnt = s:iTotalFilesAvailableCnt + len(s:dParseAll[l:sKey].files)

            if ((g:indexer_enableWhenProjectDirFound && <SID>IsFileExistsInList(s:dParseAll[l:sKey].paths, expand('%:p:h'))) || (<SID>IsFileExistsInList(s:dParseAll[l:sKey].files, expand('%:p'))))
               " user just opened file from project l:sKey. We should add it to
               " result lists

               " adding name of this project to g:indexer_indexedProjects
               call add(g:indexer_indexedProjects, l:sKey)

            endif
         endfor
      endif
   endif

   " build final list of files, paths and non-existing files
   let s:dParseGlobal = { 'files':[], 'paths':[], 'not_exist':[], 'pathsForCtags':[], 'pathsRoot':[] }

   for l:sKey in g:indexer_indexedProjects
      let s:dParseGlobal.files = <SID>ConcatLists(s:dParseGlobal.files, s:dParseAll[l:sKey].files)
      let s:dParseGlobal.paths = <SID>ConcatLists(s:dParseGlobal.paths, s:dParseAll[l:sKey].paths)
      let s:dParseGlobal.pathsForCtags = <SID>ConcatLists(s:dParseGlobal.pathsForCtags, s:dParseAll[l:sKey].pathsForCtags)
      let s:dParseGlobal.not_exist = <SID>ConcatLists(s:dParseGlobal.not_exist, s:dParseAll[l:sKey].not_exist)
      let s:dParseGlobal.pathsRoot = <SID>ConcatLists(s:dParseGlobal.pathsRoot, s:dParseAll[l:sKey].pathsRoot)
   endfor

   let s:lPathsForCtags = s:dParseGlobal.pathsForCtags
   let s:lPathsRoot = s:dParseGlobal.pathsRoot

   if (s:boolIndexingModeOn)
      call <SID>ApplyProjectSettings()
   else
      if (len(s:dParseGlobal.files) > 0 || len(s:dParseGlobal.paths) > 0)

         let s:boolIndexingModeOn = 1

         " creating auto-refresh index at project file save
         augroup Indexer_SavPrjFile
            autocmd! Indexer_SavPrjFile BufWritePost
         augroup END

         if (filereadable(g:indexer_indexerListFilename))
            let l:sIdxFile = substitute(g:indexer_indexerListFilename, '^.*[\\/]\([^\\/]\+\)$', '\1', '')
            exec 'autocmd Indexer_SavPrjFile BufWritePost '.l:sIdxFile.' call <SID>ParseProjectSettingsFile()'
         elseif (filereadable(g:indexer_projectsSettingsFilename))
            let l:sPrjFile = substitute(g:indexer_projectsSettingsFilename, '^.*[\\/]\([^\\/]\+\)$', '\1', '')
            exec 'autocmd Indexer_SavPrjFile BufWritePost '.l:sPrjFile.' call <SID>ParseProjectSettingsFile()'
         endif

         call <SID>ApplyProjectSettings()

         let l:iNonExistingCnt = len(s:dParseGlobal.not_exist)
         if (l:iNonExistingCnt > 0)
            if l:iNonExistingCnt < 100
               echo "Indexer Warning: project loaded, but there's ".l:iNonExistingCnt." non-existing files: \n\n".join(s:dParseGlobal.not_exist, "\n")
            else
               echo "Indexer Warning: project loaded, but there's ".l:iNonExistingCnt." non-existing files. Type :IndexerInfo for details."
            endif
         endif
      else
         " there's no project started.
         " we should define autocmd to detect if file from project will be opened later
         augroup Indexer_LoadFile
            autocmd! Indexer_LoadFile BufReadPost
            autocmd Indexer_LoadFile BufReadPost * call <SID>IndexerInit()
         augroup END
      endif
   endif
endfunction

function! s:IndexerInfo()
   if (s:sMode == '')
      echo '* Filelist: not found'
   elseif (s:sMode == 'IndexerFile')
      echo '* Filelist: indexer file: '.g:indexer_indexerListFilename
   elseif (s:sMode == 'ProjectFile')
      echo '* Filelist: project file: '.g:indexer_projectsSettingsFilename
   else
      echo '* Filelist: Unknown'
   endif
   if (s:boolUseDirsInsteadOfFiles)
      echo '* Index-mode: DIRS. (option g:indexer_ctagsDontSpecifyFilesIfPossible is ON)'
   else
      echo '* Index-mode: FILES. (option g:indexer_ctagsDontSpecifyFilesIfPossible is OFF)'
   endif
   echo '* When saving file: '.(g:indexer_ctagsJustAppendTagsAtFileSave ? (g:indexer_useSedWhenAppend ? 'remove tags for saved file by SED, and ' : '').'just append tags' : 'rebuild tags for whole project')
   echo '* Projects indexed: '.join(g:indexer_indexedProjects, ', ')
   if (!s:boolUseDirsInsteadOfFiles)
      echo "* Files indexed: there's ".len(s:dParseGlobal.files).' files. Type :IndexerFiles to list'
      echo "* Files not found: there's ".len(s:dParseGlobal.not_exist).' non-existing files. '.join(s:dParseGlobal.not_exist, ', ')
   endif

   echo "* Root paths: ".join(s:lPathsRoot, ', ')
   echo "* Paths for ctags: ".join(s:lPathsForCtags, ', ')

   echo '* Paths (with all subfolders): '.&path
   echo '* Tags file: '.&tags
   echo '* Project root: '.($INDEXER_PROJECT_ROOT != '' ? $INDEXER_PROJECT_ROOT : 'not found').'  (Project root is a directory which contains "'.g:indexer_dirNameForSearch.'" directory)'
endfunction

function! s:IndexerFilesList()
   echo "* Files indexed: ".join(s:dParseGlobal.files, ', ')
endfunction

function! s:IndexerInit()

   augroup Indexer_LoadFile
      autocmd! Indexer_LoadFile BufReadPost
   augroup END

   " actual tags dirname. If .vimprj directory will be found then this tags
   " dirname will be /path/to/dir/.vimprj/tags
   let s:tagsDirname = g:indexer_tagsDirname
   let g:indexer_indexedProjects = []
   let s:sMode = ''
   let s:lPathsForCtags = []

   let s:boolIndexingModeOn = 0

   if g:indexer_lookForProjectDir
      " need to look for .vimprj directory

      let l:i = 0
      let l:sCurPath = ''
      let $INDEXER_PROJECT_ROOT = ''
      while (l:i < g:indexer_recurseUpCount)
         if (isdirectory(expand('%:p:h').l:sCurPath.'/'.g:indexer_dirNameForSearch))
            let $INDEXER_PROJECT_ROOT = simplify(expand('%:p:h').l:sCurPath)
            exec 'cd '.substitute($INDEXER_PROJECT_ROOT, ' ', '\\ ', 'g')
            break
         endif
         let l:sCurPath = l:sCurPath.'/..'
         let l:i = l:i + 1
      endwhile

      if $INDEXER_PROJECT_ROOT != ''
         " project root was found.
         "
         " set directory for tags in .vimprj dir
         let s:tagsDirname = $INDEXER_PROJECT_ROOT.'/'.g:indexer_dirNameForSearch.'/tags'

         " sourcing all *vim files in .vimprj dir
         let l:lSourceFilesList = split(glob($INDEXER_PROJECT_ROOT.'/'.g:indexer_dirNameForSearch.'/*vim'), '\n')
         let l:sThisFile = expand('%:p')
         for l:sFile in l:lSourceFilesList
            if (l:sFile != l:sThisFile)
               exec 'source '.l:sFile
            endif
         endfor
      endif

   endif

   call s:ParseProjectSettingsFile()

endfunction






" --------- init variables --------
if !exists('g:indexer_lookForProjectDir')
   let g:indexer_lookForProjectDir = 1
endif

if !exists('g:indexer_dirNameForSearch')
   let g:indexer_dirNameForSearch = '.vimprj'
endif

if !exists('g:indexer_recurseUpCount')
   let g:indexer_recurseUpCount = 10
endif

if !exists('g:indexer_indexerListFilename')
   let g:indexer_indexerListFilename = $HOME.'/.indexer_files'
endif

if !exists('g:indexer_projectsSettingsFilename')
   let g:indexer_projectsSettingsFilename = $HOME.'/.vimprojects'
endif

if !exists('g:indexer_projectName')
   let g:indexer_projectName = ''
endif

if !exists('g:indexer_enableWhenProjectDirFound')
   let g:indexer_enableWhenProjectDirFound = '1'
endif

if !exists('g:indexer_tagsDirname')
   let g:indexer_tagsDirname = $HOME.'/.vimtags'
endif

if !exists('g:indexer_ctagsCommandLineOptions')
   let g:indexer_ctagsCommandLineOptions = '--c++-kinds=+p+l --fields=+iaS --extra=+q'
endif

if !exists('g:indexer_ctagsJustAppendTagsAtFileSave')
   let g:indexer_ctagsJustAppendTagsAtFileSave = 1
endif


if !exists('g:indexer_ctagsDontSpecifyFilesIfPossible')
   let g:indexer_ctagsDontSpecifyFilesIfPossible = '0'
endif
let s:boolUseDirsInsteadOfFiles = g:indexer_ctagsDontSpecifyFilesIfPossible

if !exists('g:indexer_maxOSCommandLen')
   if (has('win32') || has('win64'))
      let g:indexer_maxOSCommandLen = 8000
   else
      let g:indexer_maxOSCommandLen = system("echo $(( $(getconf ARG_MAX) - $(env | wc -c) ))") - 200
   endif
endif

if !exists('g:indexer_useSedWhenAppend')
   let g:indexer_useSedWhenAppend = 1
endif


let s:indexer_projectName = g:indexer_projectName


" -------- init commands ---------

if exists(':IndexerInfo') != 2
   command -nargs=? -complete=file IndexerInfo call <SID>IndexerInfo()
endif
if exists(':IndexerFiles') != 2
   command -nargs=? -complete=file IndexerFiles call <SID>IndexerFilesList()
endif
if exists(':IndexerRebuild') != 2
   command -nargs=? -complete=file IndexerRebuild call <SID>UpdateTags(0)
endif






augroup Indexer_LoadFile
   autocmd! Indexer_LoadFile BufReadPost
   autocmd Indexer_LoadFile BufReadPost * call <SID>IndexerInit()
augroup END

call <SID>IndexerInit()

