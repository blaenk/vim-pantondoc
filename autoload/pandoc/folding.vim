" vim: foldmethod=marker :
"
" Init: {{{1
function! pandoc#folding#Init()
    " set up defaults {{{2
    " How to decide fold levels {{{3
    " 'syntax': Use syntax
    " 'relative': Count how many parents the header has
    if !exists("g:pandoc#folding#mode")
	let g:pandoc#folding#mode = 'syntax'
    endif
    " Fold the YAML frontmatter {{{3
    if !exists("g:pandoc#folding#fold_yaml")
	let g:pandoc#folding#fold_yaml = 0
    endif
    " What <div> classes to fold {{{3
    if !exists("g:pandoc#folding#fold_div_classes")
	let g:pandoc#folding#fold_div_classes = ["notes"]
    endif
    if !exists("b:pandoc_folding_basic")
        let b:pandoc_folding_basic = 0
    endif

    " set up folding {{{2
    setlocal foldmethod=expr
    " might help with slowness while typing due to syntax checks
    augroup EnableFastFolds
	au!
	autocmd InsertEnter <buffer> setlocal foldmethod=manual
	autocmd InsertLeave <buffer> setlocal foldmethod=expr
    augroup end   
    setlocal foldexpr=pandoc#folding#FoldExpr()
    setlocal foldtext=pandoc#folding#FoldText()
    "}}}
endfunction

" Main foldexpr function, includes support for common stuff. {{{1 
" Delegates to filetype specific functions.
function! pandoc#folding#FoldExpr()

    let vline = getline(v:lnum)
    " fold YAML headers
    if g:pandoc#folding#fold_yaml == 1
	if vline =~ '\(^---$\|^...$\)' && synIDattr(synID(v:lnum , 1, 1), "name") == "Delimiter"
	    if vline =~ '^---$' && v:lnum == 1
		return ">1"
	    elseif synIDattr(synID(v:lnum - 1, 1, 1), "name") == "yamlkey" 
		return "<1"
	    elseif synIDattr(synID(v:lnum - 1, 1, 1), "name") == "pandocYAMLHeader" 
		return "<1"
	    else 
		return "="
	    endif
	endif
    endif

    " fold divs for special classes
    let div_classes_regex = "\\(".join(g:pandoc#folding#fold_div_classes, "\\|")."\\)"
    if vline =~ "<div class=.".div_classes_regex
	return "a1"
    " the `endfold` attribute must be set, otherwise we can remove folds
    " incorrectly (see issue #32)
    " pandoc ignores this attribute, so this is safe.
    elseif vline =~ '</div endfold>'
	return "s1"
    endif

    " Delegate to filetype specific functions
    if &ft == "markdown" || &ft == "pandoc"
	" vim-pandoc-syntax sets this variable, so we can check if we can use
	" syntax assistance in our foldexpr function
	if exists("g:vim_pandoc_syntax_exists") && b:pandoc_folding_basic != 1
	    return pandoc#folding#MarkdownLevelSA()
	" otherwise, we use a simple, but less featureful foldexpr
	else
	    return pandoc#folding#MarkdownLevelBasic()
	endif
    elseif &ft == "textile"
	return pandoc#folding#TextileLevel()
    endif

endfunction

" Main foldtext function. Like ...FoldExpr() {{{1
function! pandoc#folding#FoldText()
    " first line of the fold
    let f_line = getline(v:foldstart)
    " second line of the fold
    let n_line = getline(v:foldstart + 1)
    " count of lines in the fold
    let line_count = v:foldend - v:foldstart + 1
    let line_count_text = " / " . line_count . " lines / "

    if n_line =~ 'title\s*:'
	return v:folddashes . " [yaml] " . matchstr(n_line, '\(title\s*:\s*\)\@<=\S.*') . line_count_text
    endif
    if f_line =~ "fold-begin"
	return v:folddashes . " [custom] " . matchstr(f_line, '\(<!-- \)\@<=.*\( fold-begin -->\)\@=') . line_count_text
    endif
    if f_line =~ "<div class="
	return v:folddashes . " [". matchstr(f_line, "\\(class=[\"']\\)\\@<=.*[\"']\\@="). "] " . n_line[:30] . "..." . line_count_text
    endif
    if &ft == "markdown" || &ft == "pandoc"
	return pandoc#folding#MarkdownFoldText() . line_count_text
    elseif &ft == "textile"
	return pandoc#folding#TextileFoldText() . line_count_text
    endif
endfunction

" Markdown: {{{1
"
" Originally taken from http://stackoverflow.com/questions/3828606
"
" Syntax assisted (SA) foldexpr {{{2
function! pandoc#folding#MarkdownLevelSA()
    let vline = getline(v:lnum)
    let vline1 = getline(v:lnum + 1)
    if vline =~ '^#\{1,6}'
        if synIDattr(synID(v:lnum, 1, 1), "name") !~? '\(pandocDelimitedCodeBlock\|rustAttribute\|clojure\|comment\)'
	    if g:pandoc#folding#mode == 'relative'
		return ">". len(markdown#headers#CurrentHeaderAncestors(v:lnum))
	    else
                return ">". len(matchstr(vline, '^#\{1,6}'))
	    endif
        endif
    elseif vline =~ '^[^-=].\+$' && vline1 =~ '^=\+$'
        if synIDattr(synID(v:lnum, 1, 1), "name") !~? '\(pandocDelimitedCodeBlock\|comment\)'  &&
                    \ synIDattr(synID(v:lnum + 1, 1, 1), "name") == "pandocSetexHeader"
            return ">1"
        endif
    elseif vline =~ '^[^-=].\+$' && vline1 =~ '^-\+$'
        if synIDattr(synID(v:lnum, 1, 1), "name") !~? '\(pandocDelimitedCodeBlock\|comment\)'  &&
                    \ synIDattr(synID(v:lnum + 1, 1, 1), "name") == "pandocSetexHeader"
            if g:pandoc#folding#mode == 'relative'
		return  ">". len(markdown#headers#CurrentHeaderAncestors(v:lnum))
	    else
		return ">2"
	    endif
        endif
    elseif vline =~ '^<!--.*fold-begin -->'
	return "a1"
    elseif vline =~ '^<!--.*fold-end -->'
	return "s1"
    endif
    return "="
endfunction

" Basic foldexpr {{{2
function! pandoc#folding#MarkdownLevelBasic()
    if getline(v:lnum) =~ '^#\{1,6}'
	return ">". len(matchstr(getline(v:lnum), '^#\{1,6}'))
    elseif getline(v:lnum) =~ '^[^-=].\+$' && getline(v:lnum+1) =~ '^=\+$'
	return ">1"
    elseif getline(v:lnum) =~ '^[^-=].\+$' && getline(v:lnum+1) =~ '^-\+$'
	return ">2"
    elseif getline(v:lnum) =~ '^<!--.*fold-begin -->'
	return "a1"
    elseif getline(v:lnum) =~ '^<!--.*fold-end -->'
	return "s1"
    endif
    return "="
endfunction

" Markdown foldtext {{{2
function! pandoc#folding#MarkdownFoldText()
    let c_line = getline(v:foldstart)
    let atx_title = match(c_line, '#') > -1
    if atx_title
        return "- ". c_line 
    else
	if match(getline(v:foldstart+1), '=') != -1
	    let level_mark = '#'
	else
	    let level_mark = '##'
	endif
	return "- ". level_mark. ' '.c_line
    endif
endfunction

" Textile: {{{1
"
function! pandoc#folding#TextileLevel()
    let vline = getline(v:lnum)
    if vline =~ '^h[1-6]\.'
	return ">" . matchstr(getline(v:lnum), 'h\@1<=[1-6]\.\=')
    elseif vline =~ '^.. .*fold-begin'
	return "a1"
    elseif vline =~ '^.. .*fold end'
	return "s1"
    endif
    return "="
endfunction

function! pandoc#folding#TextileFoldText()
    return "- ". substitute(v:folddashes, "-", "#", "g"). " " . matchstr(getline(v:foldstart), '\(h[1-6]\. \)\@4<=.*')
endfunction

