" vim: set fdm=marker :

" functions for header navigation and information retrieval.

function! markdown#headers#CheckValidHeader(lnum) "{{{1
    if exists("g:vim_pandoc_syntax_exists")
	if synIDattr(synID(a:lnum, 1, 1), "name") =~? '\(pandocDelimitedCodeBlock\|rustAttribute\|clojure\|comment\|yamlkey\)'
	    return 0
	endif
    endif
    if match(getline(a:lnum), "^#") >= 0 || match(getline(a:lnum+1), "^[-=]") >= 0
	return 1
    endif
    return 0
endfunction

function! markdown#headers#NextHeader(...) "{{{1
    let origin_pos = getpos(".")
    if a:0 > 0
	let search_from = [0, a:1, 1, 0]
    else
	let search_from = getpos(".")
    endif
    call cursor(search_from[1], 2)
    let h_lnum = search('\(^.*\n[-=]\|^#\)','nW')
    if markdown#headers#CheckValidHeader(h_lnum) != 1
	let h_lnum = markdown#headers#NextHeader(h_lnum)
    endif
    if h_lnum == 0 
	if match(getline("."), "^#") >= 0 || match(getline(line(".")+1), "^[-=]") >= 0
	    let h_lnum = line(".")
	endif
    endif
    call cursor(origin_pos[1], origin_pos[2])
    return h_lnum
endfunction

function! markdown#headers#PrevHeader(...) "{{{1
    let origin_pos = getpos(".")
    if a:0 > 0
	let search_from = [0, a:1, 1, 0]
    else
	let search_from = origin_pos
    endif
    call cursor(search_from[1], 1)
    let h_lnum = search('\(^.*\n[-=]\|^#\)', 'bnW')
    if markdown#headers#CheckValidHeader(h_lnum) != 1
	let h_lnum = markdown#headers#PrevHeader(h_lnum)
	" we might go back into the YAML frontmatter, we must recheck if we
	" are fine
	if markdown#headers#CheckValidHeader(h_lnum) != 1
	    let h_lnum = 0
	endif
    endif
    if h_lnum == 0 
	if match(getline("."), "^#") >= 0 || match(getline(line(".")+1), "^[-=]") >= 0
	    let h_lnum = line(".")
	endif
    endif
    call cursor(origin_pos[1], origin_pos[2])
    return h_lnum
endfunction

function! markdown#headers#CurrentHeader(...) "{{{1
    if a:0 > 0
	let search_from = [0, a:1, 1, 0]
    else
	let search_from = getpos(".")
    endif
    " same as PrevHeader(), except don't search if we are already at a header 
    if match(getline(search_from[1]), "^#") < 0 && match(getline(search_from[1]+1), "^[-=]") < 0
	return markdown#headers#PrevHeader(search_from[1])
    else
	return search_from[1]
    endif
endfunction

function! markdown#headers#CurrentHeaderParent(...) "{{{1
    let origin_pos = getpos(".")

    if a:0 > 0
	let search_from = [0, a:1, 1, 0]
    else
	let search_from = origin_pos
    endif

    let ch_lnum = markdown#headers#CurrentHeader(search_from[1])

    call cursor(ch_lnum, 1)
    let l = getline(".")

    if match(l, "^#") > -1
        let parent_level = len(matchstr(l, '#*')) - 1
    elseif match(getline(line(".")+1), '^-') > -1
	let parent_level = 1
    else
	let parent_level = 0
    endif

    " don't go further than level 1 headers
    if parent_level > 0
	if parent_level == 1
	    let setext_regex = "^.*\\n="
	else 
	    let setext_regex = "^.*\\n[-=]"
	endif
	
	let arrival_lnum = search('\('.setext_regex.'\|^#\{1,'.parent_level.'}\s\)', "bnW")
	if markdown#headers#CheckValidHeader(arrival_lnum) != 1
	    let arrival_lnum = search('\('.setext_regex.'\|^#\{1,'.parent_level.'}\s\)', "bnW")
	    if markdown#headers#CheckValidHeader(arrival_lnum) != 1
		let arrival_lnum = 0
	    endif
	endif
    else
	let arrival_lnum = 0
    endif
    call cursor(origin_pos[1], origin_pos[2])
    return arrival_lnum
endfunction

function! markdown#headers#CurrentHeaderAncestral(...) "{{{1
    let origin_pos = getpos(".")
    if a:0 > 0
	let search_from = [0, a:1, 1, 0]
    else
	let search_from = origin_pos
    endif
    let p_lnum = markdown#headers#CurrentHeaderParent(search_from[1])
    " we don't have a parent, so we are an ancestral 
    " or we are not under a header
    if p_lnum == 0
	return markdown#headers#CurrentHeader(search_from[1])
    endif

    while p_lnum != 0
	call cursor(p_lnum, 1)
	let a_lnum = markdown#headers#CurrentHeaderParent()
	if a_lnum != 0
	   let p_lnum = a_lnum
       else
	   call cursor(origin_pos[1], origin_pos[2])
	   return p_lnum
       endif
    endwhile
    call cursor(origin_pos[1], origin_pos[2])
endfunction

function! markdown#headers#CurrentHeaderAncestors(...) "{{{1
    let origin_pos = getpos(".")
    if a:0 > 0
	let search_from = [0, a:1, 1, 0]
    else
	let search_from = origin_pos
    endif
    
    let h_genealogy = []

    let head = markdown#headers#CurrentHeader(search_from[1])
    if head == 0
	return []
    else
	call add(h_genealogy, head)
    endif
    let p_lnum = markdown#headers#CurrentHeaderParent(search_from[1])
    " we don't have a parent, so we are an ancestral
    if p_lnum == 0
	return h_genealogy
    endif

    while p_lnum != 0
	call cursor(p_lnum, 1)
	call add(h_genealogy, p_lnum)
	let a_lnum = markdown#headers#CurrentHeaderParent()
	if a_lnum != 0
	   let p_lnum = a_lnum
       else
	   break
       endif
    endwhile
    call cursor(origin_pos[1], origin_pos[2])
    return h_genealogy
endfunction

function! markdown#headers#SiblingHeader(direction, ...) "{{{1
    let origin_pos = getpos(".")
    if a:0 > 0
	let search_from = [1, a:1, 1, 0]
    else
	let search_from = origin_pos
    endif
   
    call cursor(search_from[1], search_from[2])

    let parent_lnum = markdown#headers#CurrentHeaderParent()

    let ch_lnum = markdown#headers#CurrentHeader()

    if a:direction == 'b'
	call cursor(ch_lnum, 1)
    endif

   let l = getline(ch_lnum)
    if match(l, "^#") > -1
        let header_level = len(matchstr(l, '#*'))
    elseif match(l, '^-') > -1
	let header_level = 2
    else
	let header_level = 1
    endif
    
    if header_level == 1
	let arrival_lnum = search('\(^.*\n=\|^#\s\)', a:direction.'nW')
    elseif header_level == 2
	let arrival_lnum = search('\(^.*\n-\|^##\s\)', a:direction.'nW')
    else
	let arrival_lnum = search('^#\{'.header_level.'}', a:direction.'nW')
    endif

    " we might have overshot, check if the parent is still correct 
    let arrival_parent_lnum = markdown#headers#CurrentHeaderParent(arrival_lnum)
    if arrival_parent_lnum != parent_lnum
	let arrival_lnum = 0
    endif

    call cursor(origin_pos[1], origin_pos[2])
    return arrival_lnum
endfunction

function! markdown#headers#NextSiblingHeader(...) "{{{1
    if a:0 > 0
	let search_from = a:1
    else
	let search_from = line(".")
    endif
    return markdown#headers#SiblingHeader('', search_from)
endfunction


function! markdown#headers#PrevSiblingHeader(...) "{{{1
    if a:0 > 0
	let search_from = a:1
    else
	let search_from = line(".")
    endif
    return markdown#headers#SiblingHeader('b', search_from)
endfunction

function! markdown#headers#FirstChild(...) "{{{1
    if a:0 > 0
	let search_from = [1, a:1, 1, 0]
    else
	let search_from = getpos(".")
    endif

    let ch_lnum = markdown#headers#CurrentHeader(search_from[1])
    let l = getline(ch_lnum)

    if match(l, "^#") > -1
        let children_level = len(matchstr(l, '#*')) + 1
    elseif match(getline(line(".")+1), '^-') > -1
	let children_level = 3
    else
	let children_level = 2
    endif

    call cursor(search_from[1], search_from[2])
    let next_lnum = markdown#headers#NextHeader()

    if children_level == 2
	let arrival_lnum = search('\(^.*\n-\|^##\s\)', 'nW')
    else
	let arrival_lnum = search('^#\{'.children_level.'}', 'nW')
    endif

    if arrival_lnum != next_lnum
	let arrival_lnum = 0
    endif
    return arrival_lnum
endfunction

function! markdown#headers#LastChild(...) "{{{1
    let origin_pos = getpos(".")
    if a:0 > 0
	let search_from = [1, a:1, 1, 0]
    else
	let search_from = origin_pos
    endif

    call cursor(search_from[1], search_from[2])
    let fc_lnum = markdown#headers#FirstChild()
    if fc_lnum != 0
	call cursor(fc_lnum, 1)

	let n_lnum = markdown#headers#NextSiblingHeader()
	if n_lnum != 0
	    
	    while n_lnum 
		call cursor(n_lnum, 1)
		let a_lnum = markdown#headers#NextSiblingHeader()
		if a_lnum != 0
		    let n_lnum = a_lnum
		else
		    break
		endif
	    endwhile
	else
	    let n_lnum = fc_lnum
	endif
    else
	let n_lnum = 0
    endif

    call cursor(origin_pos[1], origin_pos[2])
    return n_lnum
endfunction

function! markdown#headers#NthChild(count, ...) "{{{1
    let origin_pos = getpos(".")
    if a:0 > 0
	let search_from = [1, a:1, 1, 0]
    else
	let search_from = origin_pos
    endif

    let fc_lnum = markdown#headers#FirstChild(search_from[1])
    call cursor(fc_lnum, 1)
    if a:count > 1
	for child in range(a:count-1)
	    let arrival_lnum = markdown#headers#NextSiblingHeader()
	    if arrival_lnum == 0
		break
	    endif
	    call cursor(arrival_lnum, 1)
	endfor
    else
	let arrival_lnum = fc_lnum
    endif
    call cursor(origin_pos[1], origin_pos[2])
    return arrival_lnum
endfunction

function! markdown#headers#ID(...) "{{{1
    let origin_pos = getpos(".")
    if a:0 > 0
	let search_from = [1, a:1, 1, 0]
    else
	let search_from = origin_pos
    endif

    let cheader_lnum = markdown#headers#CurrentHeader(search_from[1])
    let cheader = getline(cheader_lnum)
    let header_metadata = matchstr(cheader, "{.*}")
    if header_metadata != ""
	let header_id = matchstr(header_metadata, '#[[:alnum:]-]*')[1:]
    endif
    if !exists("header_id") || header_id == ""
	let text = substitute(cheader, '\[\(.\{-}\)\]\[.*\]', '\=submatch(1)', '') " remove links
	let text = substitute(text, '\s{.*}', '', '') " remove attributes
	let text = substitute(text, '[[:punct:]]', '', 'g') " remove formatting and punctuation
	let text = substitute(text, '.\{-}[[:alpha:]]\@=', '', '') " remove everything before the first letter
	let text = substitute(text, '\s', '-', 'g') " replace spaces with dashes
	let text = tolower(text) " turn lowercase
	if !exists("header_id") || header_id == ""
	   if match(text, "[[:alpha:]]") > -1
		let header_id = text
	    else
		let header_id = "section"
	    endif
        endif
    endif
    call cursor(origin_pos[1], origin_pos[2])
    return header_id
endfunction
