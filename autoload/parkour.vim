if !exists('g:parkour_custom_prefixes')
    let g:parkour_custom_prefixes = {}
endif
if !exists('g:parkour_custom_substitutions')
    let g:parkour_custom_substitutions = {}
endif

if !exists('g:parkour_custom_paths')
    let g:parkour_custom_paths = []
endif

function! s:FindProjectRoot(filename)
    let dirs = split(a:filename, '/')

    let i = len(dirs) - 1

    while i > 0
        if dirs[i] ==# 'app' || dirs[i] ==# 'spec'
            return '/'.join(dirs[0:i-1], '/')
        endif
        let i -= 1
    endwhile

    echom 'Parkour - Cannot find project root'
    return ''
endfunction!

function! s:ToCustomFilePart(filename, from_key, to_key)
    for obj in g:parkour_custom_paths
        if has_key(obj, a:from_key) && obj[a:from_key] == a:filename && has_key(obj, a:to_key)
            return obj[a:to_key]
        endif
    endfor
    return ''
endfunction!

function! s:FileInfo(full_path, root_path)
    let app_path = a:root_path.'/app/'
    let spec_path = a:root_path.'/spec/'

    let is_spec = 0

    if s:BeginsWith(a:full_path, app_path)
        let filename = strpart(a:full_path, strlen(app_path))
    elseif s:BeginsWith(a:full_path, spec_path)
        let is_spec = 1
        let filename = strpart(a:full_path, strlen(spec_path))
    else
        echom 'Does not begin with app path:'.a:full_path.' and '.app_path
        return
    endif

    let i = match(filename, '/')

    let type_part = strpart(filename, 0, i)
    let file_part = strpart(filename, i + 1)

    " Get rid of 's' in type
    let type_part = s:Unpluralize(type_part)

    if is_spec
        let type_part = type_part.'_spec'
    endif

    " Remove .rb
    if s:EndsWith(file_part, '.rb')
        let file_part = strpart(file_part, 0, len(file_part) - 3)
    endif

    " Remove _<type>
    let suffix = '_'.type_part

    if s:EndsWith(file_part, suffix)
        let file_part = strpart(file_part, 0, len(file_part) - len(suffix))
    endif

    if type_part ==# 'controller' || type_part ==# 'controller_spec'
        let file_part = s:Unpluralize(file_part)
    endif

    " If filename in custom paths, set file_part
    let custom_file_part = s:ToCustomFilePart(file_part, type_part, 'file_part')
    if custom_file_part != ''
        let file_part = custom_file_part
    endif

    return {
        \'type_part': type_part,
        \'file_part': file_part,
        \'original': a:full_path
    \}
endfunction!

function! s:EndsWith(str, part)
    return matchend(a:str, '.*'.a:part) == len(a:str)
endfunction!

function! s:BeginsWith(str, part)
    return match(a:str, a:part) == 0
endfunction!

function! s:Pluralize(str)
    " Replace y with ies, excluding ay, ey, oy, uy
    if match(a:str, '[^aeou]y$') != -1
        return strpart(a:str, 0, len(a:str) - 1).'ies'
    else
        return a:str.'s'
    endif
endfunction!

function! s:Unpluralize(str)
    if s:EndsWith(a:str, 'ies')
        return strpart(a:str, 0, len(a:str) - 3).'y'
    elseif s:EndsWith(a:str, 's')
        return strpart(a:str, 0, len(a:str) - 1)
    else
        return a:str
    endif
endfunction!

function! s:TryOpen(file_part, prefix, suffix, pluralize)
    if a:pluralize
        let file_part = s:Pluralize(a:file_part)
    else
        let file_part = a:file_part
    endif

    let filename =  a:prefix.file_part.a:suffix

    if filereadable(filename)
        :exe 'edit' filename
        return
    endif

    " Try alternate names
    for [w1, w2] in items(g:parkour_custom_substitutions)
        if match(filename, w1) != -1
            let filename = substitute(filename, w1, w2, 'g')
        elseif match(filename, w2) != -1
            let filename = substitute(filename, w2, w1, 'g')
        endif
    endfor
    if filereadable(filename)
        :exe 'edit' filename
        return
    endif

    echo 'Parkour - Cannot find: '.filename
endfunction!

function! parkour#RailsOpen(to_type)
    let full_path = expand('%:p')
    let root_path = s:FindProjectRoot(full_path)
    if root_path ==# ''
        return
    endif

    let app_path = root_path.'/app/'
    let spec_path = root_path.'/spec/'

    let fileinfo = s:FileInfo(full_path, root_path)
    let from_type = fileinfo.type_part
    let to_type = a:to_type

    if to_type ==# 'alternate'
        " Remove/Add '_spec'
        if s:EndsWith(from_type, '_spec')
            let to_type = strpart(from_type, 0, len(from_type) - 5)
        else
            let to_type = fileinfo.type_part.'_spec'
        endif
    endif

    let pluralize = 0

    " TODO: Change to non-hardcoded approach
    if to_type ==# 'controller'
        let prefix = app_path.'controllers/'
        let suffix = '_controller.rb'
        let pluralize = 1

    elseif to_type ==# 'decorator'
        let prefix = app_path.'decorators/'
        let suffix = '_decorator.rb'

    elseif to_type ==# 'model'
        let prefix = app_path.'models/'
        let suffix = '.rb'

    elseif to_type ==# 'decorator_spec'
        let prefix = spec_path.'decorators/'
        let suffix = '_decorator_spec.rb'

    elseif to_type ==# 'controller_spec'
        let prefix = spec_path.'controllers/'
        let suffix = '_controller_spec.rb'
        let pluralize = 1

    elseif to_type ==# 'model_spec'
        let prefix = spec_path.'models/'
        let suffix = '_model_spec.rb'

    else
        echom 'Parkour - type not recognized: '.to_type
        return
    endif

    let from_prefix = s:SecondaryPrefix(from_type)
    let to_prefix = s:SecondaryPrefix(to_type)

    let filename = fileinfo.file_part

    if from_prefix != to_prefix
        " Remove from_prefix
        if s:BeginsWith(filename, from_prefix)
            let filename = strpart(filename, len(from_prefix))
        endif

        " Test for custom change in file_part
        let custom_file_part = s:ToCustomFilePart(filename, 'file_part', to_type)
        if custom_file_part != ''
            let filename = custom_file_part
        endif

        " Add to_prefix
        let filename = to_prefix.filename
    endif

    call s:TryOpen(filename, prefix, suffix, pluralize)
endfunction!

function! s:SecondaryPrefix(type)
    if has_key(g:parkour_custom_prefixes, a:type)
        return g:parkour_custom_prefixes[a:type]
    else
        return ''
    endif
endfunction!
