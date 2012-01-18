" Vim syntax file

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
   syntax clear
elseif exists("b:current_syntax")
   finish
endif

" turn case on
syn case match

syn match  indexer_files_label         "^.\{-}="
syn region indexer_files_header        start="^\[" end="\]" contains=indexer_files_string,indexer_files_identifier
syn match  indexer_files_comment       "\v^\s*\#.*$"
syn match  indexer_files_string        "\v\"[^\"]*\""
syn match  indexer_files_identifier    "PROJECTS_PARENT"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_indexer_files_syntax_inits")
   if version < 508
      let did_indexer_files_syntax_inits = 1
      command -nargs=+ HiLink hi link <args>
   else
      command -nargs=+ HiLink hi def link <args>
   endif

   HiLink indexer_files_header      Special
   HiLink indexer_files_string      String
   HiLink indexer_files_comment     Comment
   HiLink indexer_files_label       Type
   HiLink indexer_files_identifier  Identifier

   delcommand HiLink
endif

let b:current_syntax = "indexer_files"

" vim:ts=3:sw=3
