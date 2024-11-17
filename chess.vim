python3 << EOL
import json
import vim
import textwrap
import random
import socket

# start position of horizontal/vertical lines
HSTART, VSTART = 0, 1
# repeat times of horizontal and vertical lines,
# which is the number of pieces allowed in a row/column
HREPEAT, VREPEAT = 0, 0
# starting position of viemport for pieces
HPOS, VPOS = 0, 0
# position of pieces, either x or o, index by (v,h) position
# on board (not physical line/column)
# x is the first player or you, o is the second player or computer
POS = {}
HSEG, VSEG = '+---', '|   '
HLEN, VLEN = len(HSEG), 2
WAITING = False
FROZEN = False

def save_session(fname):
  new = {'{}:{}'.format(*k):v for k, v in POS.items()}
  open (fname, 'w').write(json.dumps(new))
  print( 'Session saved')

def restore_session(fname):
  new = json.loads(open(fname).read())
  POS.clear()
  for k, v in new.items():
    POS[tuple(map(int, k.split(':')))] = v
  draw_board()
  print('Reloaded saved session.')

def clear_session():
  message('Are you sure to clear the session? y/N', False)
  char = vim.eval('getcharstr()')
  vim.command( 'redraw')
  if char.lower() != 'y':
    print('')
    return
  POS.clear()
  draw_board()
  print('Session cleared.')

def check_win(pos, side):
  msg = ''
  duration = 9 # number of consecutive pieces to check
  # Patterns on 4 directions: vertical, horizontal, slash, back slash.
  # This inclues pattersn startig from the give place and that ends there.
  for ptn in [
    [POS.get((pos[0]-4+x, pos[1]), '') == side for x in range(duration)], # vertical
    [POS.get((pos[0], pos[1]-4+x), '') == side for x in range(duration)], # horzontal
    [POS.get((pos[0]-4+x, pos[1]-4+x), '') == side for x in range(duration)], # slash
    [POS.get((pos[0]-4+x, pos[1]+4-x), '') == side for x in range(duration)], # back slash
  ]:
    # Foreach direction, only check 5 consecutive pieces, up to the middle
    for start in range(5):
      if all(ptn[start: start+5]) and ptn[start]:
        msg = 'You win!' if side == 'x' else 'You lose!'
        break
  if msg:
    msg += '\nDo you want to play again? y/N'
    message(msg, False)
    vim.command('redraw')
    char = vim.eval('getcharstr()')
    if char.lower() == 'y':
      POS.clear()
      draw_board()
    else:
      draw_board()
      message('Game over!', False)
      print('')
      global put_piece, FROZEN
      put_piece = lambda: None
      FROZEN = True
      return True
  return False

def move_cursor(direction):
  global HPOS, VPOS
  vv, hh, vpos, hpos = getpos()
  pieces = 5 # there are 5 pieces in a row/column to win
  if direction == 'j':
    if vpos > VREPEAT - pieces:
      VPOS += 1
    else:
      vpos += 1
  elif direction == 'k':
    if vpos < pieces:
      VPOS -= 1
    else:
      vpos -= 1
  elif direction == 'h':
    if hpos < pieces:
      HPOS -= 1
    else:
      hpos -= 1
  elif direction == 'l':
    if hpos > HREPEAT - pieces:
      HPOS += 1
    else:
      hpos += 1
  vpos = min(max(vpos, pieces), VREPEAT - pieces)
  hpos = min(max(hpos, pieces), HREPEAT - pieces)
  vv, hh = VSTART + vpos * VLEN + 1, HSTART + hpos * HLEN + 1
  vim.eval('cursor({}, {})'.format(vv, hh))
  print('Position:', vpos, hpos)
  draw_board()

def getpos():
  _, vv, hh, _ = vim.eval('getpos(".")')
  vv, hh = int(vv), int(hh)
  vpos, hpos = (vv - 1 - VSTART) // VLEN, (hh - 1 - HSTART) // HLEN
  return vv, hh, vpos, hpos

def auto_move():
  global WAITING
  WAITING = True
  print('Thinking...')
  while True:
    pos = random.randint(0, VREPEAT), random.randint(0, HREPEAT)
    if pos not in POS:
      break
  POS[pos] = 'o'
  draw_board()
  vim.command('redraw')
  ret = check_win(pos, 'o')
  if not ret:
    print('Your move now.')
  WAITING = False

def put_piece():
  if WAITING:
    print('Not your turn yet.')
    return
  _, _, vpos, hpos = getpos()
  pos = vpos + VPOS, hpos + HPOS
  if pos in POS:
    print('This position is occupied.')
    return
  POS[pos] = 'x'
  draw_board()
  vim.command('redraw')
  ret = check_win(pos, 'x')
  if not ret:
    auto_move()

def draw_board(resize=False):
  global HSTART, VSTART, HREPEAT, VREPEAT
  if FROZEN:
    return
  HREPEAT, remain = divmod(vim.current.window.width, HLEN)
  if not remain:
    remain += HLEN # remove last open column
    HREPEAT -= 1
  remain -= 1 # close last open clumn
  remain = remain // 2 * ' '
  HSTART = len(remain) + HLEN//2
  VREPEAT = vim.current.window.height // VLEN
  hline = remain + HSEG * HREPEAT + '+'
  vline = remain + VSEG * HREPEAT + '|'
  lines = [hline, vline] * VREPEAT
  if vim.current.window.height % VLEN:
    lines.append(hline) # add closing bottom line
  else:
    lines = lines[:-1] # remove open bottom line
    VREPEAT -= 1
  lines = [list(x) for x in lines]
  for v in range(VREPEAT):
    for h in range(HREPEAT):
      vv, hh = VSTART + v * VLEN, HSTART + h * HLEN
      pos = v + VPOS, h + HPOS
      if pos not in POS:
        continue
      lines[vv][hh] = POS.get(pos, ' ')
  update_buffer([''.join(x) for x in lines])
  if resize:
    vv, hh = VSTART + VREPEAT // 2 * VLEN + 1, HSTART + HREPEAT // 2 * HLEN + 1, 
    vim.eval('cursor({}, {})'.format(vv, hh))

def play():
  msg = '''
  Gomoku
  You can play with computer directly by using the following commands:
    j/k/h/l to move, x to put a piece, c to clear, z to position cursor
  `:Save fname` to save the current session.
  `:Resotre fname` to restore the saved session.

  Do you want to move first? y/N
  '''
  message(msg, model=True)
  char = vim.eval('getcharstr()')
  print('')
  draw_board() # do this so we have VREPEAT/HREPEAT
  vim.command('redraw')
  if char.lower() != 'y':
    POS[VREPEAT // 2, HREPEAT // 2] = 'o'
    draw_board(resize=True)
    print(f'Your move now.')
  else:
    draw_board(resize=True)

def update_buffer(lines):
  vim.command('set modifiable')
  vim.current.buffer[:] = lines
  vim.command('set nomodifiable')
  vim. command('redraw')

def message(msg, model=True) :
  msg = textwrap.dedent(msg).strip().splitlines()
  width = max(len(x) for x in msg)
  block, remain = divmod(width, HLEN)
  if remain: # ensure covering multiple horizontal blocks
    block += 1
    width = block * HLEN
  gap = '|  {}  |'.format(' ' * width)
  sep = '+--{}--+'.format('-' * width)
  msg = [sep, gap] + ['|  {}  |'.format(x.ljust(width)) for x in msg] + [gap, sep]
  vpad = (vim.current.window.height - len(msg)) // 2
  if model:
    vrest = vim.current.window.height - len(msg) - vpad
    empty = ' ' * vim.current.window.width
    msg = [x.center(vim.current.window.width) for x in msg]
    update_buffer(vpad * [empty] + msg + vrest * [empty])
  else:
    width += 6
    indent = (vim.current.window.width - width) // 2
    lines = vim.current.buffer[:]
    for v in range(0, len(msg)):
      vv = v + vpad
      line = list(lines[vv][:])
      line[indent:indent+width] = msg[v]
      lines[vv] = ''.join(line)
    update_buffer(lines)
EOL

command! Play python3 play()
command! Draw python3 draw_board(True)
command! -complete=file -bang -nargs=1 Save python3 save_session(<f-args>)
command! -complete=file -bang -nargs=1 Restore python3 restore_session(<f-args>)
"cc-u>: this clears out the line range that will be added when you start a command with a number.
"norm! The ! after :norm ensures we don't use remapped commands.
"nnoremap ‹silent> j :<c-u»norm! 2j<cr»
nnoremap <silent> j :python3 move_cursor("j")<cr>
nnoremap <silent> k :python3 move_cursor("k")<cr>
nnoremap <silent> h :python3 move_cursor("h")<cr>
nnoremap <silent> l :python3 move_cursor("l")<cr>
nnoremap <silent> x :python3 put_piece()<cr>
nnoremap <silent> c :python3 clear_session()<cr>
autocmd VimResized * Draw
:set nonumber
:set ch=1
:set nofoldenable
:set nomodifiable
:set mouse=
" shopt -s checkwinsize
