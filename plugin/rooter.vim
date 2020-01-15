" Vim plugin to change the working directory to the project root.
"
" Copyright 2010-2016 Andrew Stewart, <boss@airbladesoftware.com>
" Released under the MIT licence.

if exists('g:loaded_rooter') || &cp
	finish
endif
let g:loaded_rooter = 1

let s:nomodeline = (v:version > 703 || (v:version == 703 && has('patch442'))) ? '<nomodeline>' : ''

if exists('+autochdir') && &autochdir && (!exists('g:rooter_manual_only') || !g:rooter_manual_only)
	set noautochdir
endif

let g:rooter_patterns      = get(g:, 'rooter_patterns', ['.git', '.git/', '_darcs/', '.hg/', '.bzr/', '.svn/'])
let g:rooter_resolve_links = get(g:, 'rooter_resolve_links', 0)
let g:rooter_silent_chdir  = get(g:, 'rooter_silent_chdir', 0)
let g:rooter_targets       = get(g:, 'rooter_targets', '/,*')
let g:rooter_use_lcd       = get(g:, 'rooter_use_lcd', 0)
let g:rooter_change_directory_for_non_project_files = get(g:, 'rooter_change_directory_for_non_project_files', '')

function! s:IsDirectory(pattern)
	return a:pattern[-1:] == '/'
endfunction

function! s:ChangeDirectory(directory)
	if a:directory !=# getcwd()
		let cmd = g:rooter_use_lcd == 1 ? 'lcd' : 'cd'
		execute ':' . cmd fnameescape(a:directory)
		if !g:rooter_silent_chdir
			echo 'cwd: ' . a:directory
		endif
		if exists('#User#RooterChDir')
			execute 'doautocmd' s:nomodeline 'User RooterChDir'
		endif
	endif
endfunction

function! GetCwd()
	" A directory will always have a trailing path separator.
	let cwd = expand('%:p')

	if empty(cwd)
		let cwd = getcwd()
	endif

	if g:rooter_resolve_links
		let cwd = resolve(cwd)
	endif

	return cwd
endfunction

function! s:FindAncestor(cwd, pattern)
	let cwd = fnameescape(a:cwd)
	if s:IsDirectory(a:pattern)
		let match = finddir(a:pattern, cwd . ';')
	else
		let [_suffixesadd, &suffixesadd] = [&suffixesadd, '']
		let match = findfile(a:pattern, cwd . '.;')
		let &suffixesadd = _suffixesadd
	endif

	if empty(match)
		return ''
	endif

	if s:IsDirectory(a:pattern)
		return fnamemodify(match, ':p:h:h')
	else
		return fnamemodify(match, ':p:h')
	endif
endfunction

function! s:SearchForRootDirectory(cwd)
	let root = ''
	for pattern in g:rooter_patterns
		let result = s:FindAncestor(a:cwd, pattern)
		if len(result) > len(root) && result != '/'
			let root = result
		endif
	endfor
	return root
endfunction

function! s:RootDirectory()
	let root = getbufvar('%', 'rootDir')
	if empty(root)
		let root = s:SearchForRootDirectory(GetCwd())
		if !empty(root)
			call setbufvar('%', 'rootDir', root)
		endif
	endif
	return root
endfunction

function! s:CdToProjectRoot()
	let root = s:RootDirectory()
	if empty(root)
		if g:rooter_change_directory_for_non_project_files ==? 'current'
			if expand('%') != ''
				call s:ChangeDirectory(fnamemodify(s:fd, ':h'))
			endif
		elseif g:rooter_change_directory_for_non_project_files ==? 'home'
			call s:ChangeDirectory($HOME)
		endif
	else
		call s:ChangeDirectory(root)
	endif
endfunction

command! Rooter :call <SID>CdToProjectRoot()

if !exists('g:rooter_manual_only') || !g:rooter_manual_only
	augroup rooter
		autocmd!
		autocmd VimEnter,BufEnter * nested :Rooter
		autocmd BufWritePost      * nested :call setbufvar('%', 'rootDir', '') | :Rooter
	augroup END
endif
