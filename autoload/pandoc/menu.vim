function! pandoc#menu#Init()
    call pandoc#menu#CreateMenu()
endfunction

function! pandoc#menu#CreateMenu()
    if index(g:pandoc#modules#enabled, "command") >= 0
	amenu Pandoc.Compile.&Pdf :Pandoc pdf<CR>
	amenu Pandoc.Compile.&Beamer :Pandoc beamer<CR>
	amenu Pandoc.Compile.&ODT :Pandoc odt<CR>
	amenu Pandoc.Compile.&HTML :Pandoc html -s<CR>
        amenu Pandoc.Compile.-Sep1- :
        for temp in pandoc#command#GetTemplateNames()
            exe "amenu Pandoc.Compile.".temp." :Pandoc #".temp."<CR>"
        endfor
	amenu Pandoc.Compile\ and\ View.Pdf :Pandoc! pdf<CR>
	amenu Pandoc.Compile\ and\ View.Beamer :Pandoc! beamer<CR>
	amenu Pandoc.Compile\ and\ View.ODT :Pandoc! odt<CR>
	amenu Pandoc.Compile\ and\ View.HTML :Pandoc! html -s<CR>
        amenu Pandoc.Compile\ and\ View.-Sep1- :
        for temp in pandoc#command#GetTemplateNames()
            exe "amenu Pandoc.Compile\\ and\\ View.".temp." :Pandoc! #".temp."<CR>"
        endfor
	amenu .699 Pandoc.-Sep1- :
    endif
    amenu .900 Pandoc.Help :help pandoc<CR>
endfunction

