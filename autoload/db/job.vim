let s:vim_job = {'output': '', 'exit': 0, 'close': 0, 'exit_status': 0 }

function! s:vim_job.cb(job, data) dict abort
  if type(a:data) ==? type(0)
    let self.exit = 1
    let self.exit_status = a:data
    return self.call_cb_if_finished()
  endif
  let self.output .= a:data
endfunction

function! s:vim_job.close_cb(channel) dict abort
  let self.close = 1
  return self.call_cb_if_finished()
endfunction

function! s:vim_job.call_cb_if_finished() abort
  if self.close && self.exit
    return self.callback(split(self.output, "\n", 1), self.exit_status)
  endif
endfunction

function! s:nvim_job_cb(jobid, data, event) dict abort
  if a:event ==? 'exit'
    return self.callback(self.output, a:data)
  endif
  call extend(self.output, a:data)
endfunction

function! db#job#run(cmd, callback, stdin_file) abort
  if has('nvim')
    let jobid = jobstart(a:cmd, {
          \ 'on_stdout': function('s:nvim_job_cb'),
          \ 'on_stderr': function('s:nvim_job_cb'),
          \ 'on_exit': function('s:nvim_job_cb'),
          \ 'output': [],
          \ 'callback': a:callback,
          \ 'stdout_buffered': 1,
          \ 'stderr_buffered': 1,
          \ })

    if !empty(a:stdin_file)
      call chansend(jobid, readfile(a:stdin_file, 'b'))
      call chanclose(jobid, 'stdin')
    endif

    return jobid
  endif

  if exists('*job_start')
    let fn = copy(s:vim_job)
    let fn.callback = a:callback
    let opts = {
          \ 'out_cb': fn.cb,
          \ 'err_cb': fn.cb,
          \ 'exit_cb': fn.cb,
          \ 'close_cb': fn.close_cb,
          \ 'mode': 'raw'
          \ }

    if has('patch-8.1.350')
      let opts['noblock'] = 1
    endif

    if !empty(a:stdin_file)
      let opts['in_io'] = 'file'
      let opts['in_name'] = a:stdin_file
    endif

    return job_start(a:cmd, opts)
  endif

  throw 'DB: jobs not supported by this vim version.'
endfunction

function! db#job#wait(job, ...)
  let timeout = get(a:, 1, -1)

  if has('nvim')
    return jobwait([a:job], timeout)[0] == -1 ? v:false : v:true
  endif

  let finished = v:true
  if exists('*job_status')
    let ms = 0
    let max = timeout
    while job_status(a:job) ==# 'run'
      if ms == max
        let finished = v:false
        break
      endif
      let ms += 1
      sleep 1m
    endwhile
  endif

  return finished
endfunction

function! db#job#cancel(job)
  if empty(a:job)
    return
  endif

  if has('nvim')
    return jobstop(a:job)
  endif

  if exists('*job_stop')
    return job_stop(a:job)
  endif
endfunction

function! db#job#is_running(job)
  if empty(a:job)
    return v:false
  endif
  return !db#job#wait(a:job, 0)
endfunction
