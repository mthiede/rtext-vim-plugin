" Vim syntax file
" Language:         RText
" Maintainer:       Martin Thiede 
" Latest Revision:  2012-10-31

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn region rtextBlock start="{" end="}" transparent fold

syn region rtextGeneric start="<" end=">"

syn match rtextComment
      \ display
      \ '^\s*#.*'

syn match rtextAnnotation
      \ display
      \ '^\s*@.*'

syn match rtextValue
      \ display
      \ '\(\w\|\.\)\+'

syn match rtextCommand
      \ display
      \ '^\s*\w\+:\@!\>'

syn match rtextIdentifier
      \ display
      \ '\(\w\+\)\@<= \w\+:\@!\>'

syn match rtextFeature
      \ display
      \ '\<\w\+\>:'

syn match rtextLink
      \ display
      \ '/\+\w\+'

syn match rtextString
     \ display
     \ '"\([^"\\]\|\\.\)*"'

hi def link rtextCommand                           Statement
hi def link rtextIdentifier                        Identifier
hi def link rtextFeature                           Label
hi def link rtextLink                              Constant
hi def link rtextString                            String
hi def link rtextValue                             Constant
hi def link rtextComment                           Comment
hi def link rtextGeneric                           Underlined
hi def link rtextAnnotation                        Special

let b:current_syntax = "rtext"

setlocal foldtext=MyFoldText()
function! MyFoldText()
  let line = getline(v:foldstart)
  let sub = substitute(line, '^\(\s*\)', '\1+ ', '')
  return sub
endfunction

setlocal foldmethod=marker
setlocal foldmarker={,}
setlocal foldlevel=10
setlocal updatetime=1000
" disable column limitation for syntax highlighting
" otherwise if lines are too long, opening curly braces at the line end
" wouldn't be recognized and the folding is messed up
setlocal synmaxcol=0 

function! rtext#Complete(findstart, base)
  if a:findstart
    let g:rtext_start = 0
    ruby RText.find_start
    return g:rtext_start
  else
    let g:rtext_completions = []
    ruby RText.get_completions(VIM::evaluate("a:base"))
    return g:rtext_completions
  endif
endfunction

setlocal errorformat=%D%f:%f%X:%l:%m
setlocal omnifunc=rtext#Complete

map <buffer> <silent> <C-]> :call <SID>JumpReference()<CR>
map <buffer> <silent> <C-LeftMouse> :call <SID>JumpReference()<CR>

au BufWritePost <buffer> call <SID>ShowProblems()
au CursorHold <buffer> call <SID>Timeout() 
au CursorMoved <buffer> call <SID>Trigger() 
au CursorMovedI <buffer> call <SID>Trigger() 

if exists('g:loaded_rtext')
  finish
endif
let g:loaded_rtext = 1

au VimLeave * call <SID>Leave()
command! -nargs=1 RTextFind call <SID>FindElements(<q-args>)

function! s:ShowProblems()
  ruby RText.show_problems
endfunction

function! s:Timeout()
  call feedkeys("f\e")
  ruby RText.tick
endfunction 

function! s:Trigger()
  ruby RText.tick
endfunction 

function! s:JumpReference()
  ruby RText.jump_reference
endfunction

function! s:FindElements(pattern)
  ruby RText.find_elements(VIM::evaluate("a:pattern"))
endfunction

function! s:Leave()
  ruby RText.leave
endfunction
 
function! s:DefRuby()
ruby << RUBYEOF

require 'logger'
require 'rtext/frontend/context'
require 'rtext/frontend/connector_manager'

$man ||= RText::Frontend::ConnectorManager.new(
  :keep_outfile => true,
  :connect_callback => lambda do |c, state|
    VIM::command("redraw")
    if state == :timeout
      VIM::message("RText: connection timeout")
    else
      VIM::message("RText: loading model...")
      RText.show_problems
    end
  end)

module RText

  def self.find_start
    lp = line_prefix
    start_pos = lp.sub(/[\w\/]+$/,'').size
    VIM::command("let g:rtext_start = %d" % start_pos)
  end

  def self.get_completions(base)
    lp = line_prefix
    con = $man.connector_for_file(VIM::evaluate('expand("%:p")'))
    if con
      response = con.execute_command(
        {"command" => "content_complete", 
         "column" => lp.size+1,
         "context" =>  RText::Frontend::Context.extract(buf_prefix)})
      options = []
      if error_message(response)
      elsif response["type"] == "response"
        options = response["options"]
        vim_options = options.select{|o| o["display"].index(base) == 0 || o["display"].split(/\W/).any?{|w| w.index(base) == 0}}.collect{|o|
          "{'word': '#{o["insert"]}', 'abbr': '#{o["display"]}'}"
        }.join(",")
      end
      VIM::command("call extend(g:rtext_completions, [%s])" % vim_options)
    else
      VIM::message("RText: no config") 
    end
  end

  def self.show_problems
    con = $man.connector_for_file(VIM::evaluate('expand("%:p")'))
    if con
      con.execute_command({"command" => "load_model"}, :response_callback => lambda do |r|
        if r["type"] == "response"
          update_problems(r)
        elsif r["type"] == "progress"
          VIM::message("RText: loading model...(#{r["percentage"]}%)")
        end
      end)
    end
  end

  def self.jump_reference
    lp = line_prefix
    con = $man.connector_for_file(VIM::evaluate('expand("%:p")'))
    if con
      response = con.execute_command({
        "command" => "link_targets", 
        "column" => lp.size + 1,
        "context" => RText::Frontend::Context.extract(buf_prefix)})
      if error_message(response)
      elsif response["type"] == "response"
        targets = response["targets"] || []
        if targets.size == 1
          VIM::command("e +#{targets.first["line"]} #{targets.first["file"]}")
        elsif targets.size > 1
          index = 0
          vim_targets = targets.collect do |t|
            index += 1
            "'#{index}. #{t["display"]}'"
          end
          selected = VIM::evaluate("inputlist(['Select target:', #{vim_targets.join(",")}])")
          if selected > 0
            target = targets[selected-1]
            VIM::command("e +#{target["line"]} #{target["file"]}")
          end
        else
          VIM::message("RText: no targets")
        end
      end
    else
      VIM::message("RText: no config")
    end
  end

  def self.find_elements(pattern)
    con = $man.connector_for_file(VIM::evaluate('expand("%:p")'))
    if con
      response = con.execute_command({
        "command" => "find_elements",
        "search_pattern" => pattern })
      if error_message(response)
      elsif response["type"] == "response"
        update_search_results(response)
      end
    else
      VIM::message("RText: no config")
    end
  end

  def self.leave
    $man.all_connectors.each do |c|
      c.stop
    end
  end

  def self.error_message(obj)
    case obj
    when :backend_busy
      VIM::message("RText: backend busy...")
      true
    when :request_pending
      VIM::message("RText: request pending...")
      true
    when :connecting
      VIM::message("RText: connecting...")
      true
    when :timeout
      VIM::message("RText: timeout")
      true
    else
      false
    end
  end

  def self.tick
    con = $man.connector_for_file(VIM::evaluate('expand("%:p")'))
    con.resume if con
  end

  def self.update_search_results(obj)
    elements = []
    wd = VIM::evaluate("getcwd()").gsub("\\", "/")
    (obj["elements"] || []).each do |e|
      file = e["file"].gsub("\\", "/").sub(wd, "").sub(/^\//, "")
      elements << "#{file}:#{e["line"]}:#{e["display"]}"
    end
    VIM::command("cexpr [#{elements.collect{|e| "\"#{e}\""}.join(",")}]")
    VIM::message("RText: found #{elements.size} elements")
  end

  def self.update_problems(obj)
    problems = []
    wd = VIM::evaluate("getcwd()").gsub("\\", "/")
    (obj["problems"] || []).each do |fp|
      file = fp["file"].gsub("\\", "/").sub(wd, "").sub(/^\//, "")
      (fp["problems"] || []).each do |p|
        problems << "#{file}:#{p["line"]}:#{p["message"]}"
      end
    end
    VIM::command("cexpr [#{problems.collect{|p| "\"#{p}\""}.join(",")}]")
    VIM::message("RText: model loaded, #{problems.size} problems")
  end

  def self.line_prefix
    line = VIM::Buffer.current.line
    cpos = VIM::Window.current.cursor[1]
    if cpos > 0
      line[0..cpos-1]
    else
      ""
    end
  end

  def self.buf_prefix
    VIM::evaluate("getline(1, line('.'))")
  end
end

RUBYEOF
endfunction

call s:DefRuby()

let &cpo = s:cpo_save
unlet s:cpo_save

