python3 << EOL
import json
import random
import socket
import time
import textwrap
import vim
from threading import Thread

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
#HSEG, VSEG = '    ', '    '
HLEN, VLEN = len(HSEG), 2
WAITING = False
FROZEN = False

socket.setdefaulttimeout(.2)
class Conn:
  name = None
  put = ''
  got = ''

def server_loop(action):
  global FROZEN
  while True:
    server = Conn.name
    if not server: break
    if action == 'receive':
      try:
        client, address = server.accept()
        server.close()
        POS.clear()
        draw_board()
        Conn.got = ''
        FROZEN = False
        Conn.name = client
        print(f'Accepted connection from {address}.')
      except socket.timeout:
        continue
      except Exception as err:
        break
    elif action == 'send':
      Conn.put = ''
      client = Conn.name
    if not client: continue
    msg = 'Connection to client closed.' if action == 'receive' else ''
    client_loop(action, msg)

def client_loop(action, msg):
  while True:
    client = Conn.name
    if not client: break
    if action == 'send':
      if not Conn.put:
        time.sleep(.1)
        continue
      try:
        sent = client.send(Conn.put.encode())
      except socket.timeout:
        continue
      except Exception:
        break
      if sent == 0: break
      Conn.put = ''
    else: # action == 'receive'
      try:
        ret = client.recv(20).decode()
      except socket.timeout:
        continue
      except Exception:
        break
      if not ret: break
      Conn.got = ret
      if ret == 'close':
        Conn.put = ret
        break
  try:
    client.close()
  except Exception as err:
    pass
  Conn.name = None
  if msg:
    print(msg)

def stop_conn():
  try:
    Conn.name.send('close'.encode())
  except Exception:
    pass
  Conn.name = None

def start_server(port):
  port = int(port)
  if Conn.name:
    print(f'Already started')
    return
  try:
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    host = socket.gethostname()
    server.bind((host, port))
    server.listen(0)
    print(f'Listening on {host}:{port}')
  except Exception as err:
    print(f'Failed to start server on {host}:{port} with error: {err}')
    return
  Conn.name = server
  Thread(target=server_loop, args=['send']).start()
  Thread(target=server_loop, args=['receive']).start()
  # should not auto_move() here as connection is not established yet

def start_client(addr):
  if Conn.name:
    print('Already started.')
    return
  if ':' in addr:
    host, port = addr.split(':')
  else:
    host = socket.gethostname()
    port = addr
  port = int(port)
  client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  try:
    client.connect((host, port))
    print(f'Connected to {host}:{port}')
    POS.clear()
    draw_board()
  except Exception as err:
    print(f'Failed to connect to {host}:{port} with error: {err}')
    return
  Conn.name = client
  Thread(target=client_loop, args=['send', 'Connection closed.']).start()
  Thread(target=client_loop, args=['receive', '']).start()
  auto_move()

def save_session(fname):
  new = {'{}:{}'.format(*k):v for k, v in POS.items()}
  open (fname, 'w').write(json.dumps(new))
  print('Session saved')

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
      game_over()
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

def game_over():
  global put_piece, FROZEN
  draw_board()
  message('Game over!', False)
  print('')
  put_piece = lambda: None
  FROZEN = 'over'
  stop_conn()

def auto_move():
  global WAITING
  WAITING = True
  print('Thinking...')
  pos = None
  if Conn.name:
    while not Conn.got:
      if not Conn.name: break
      time.sleep(.1)
    if ',' in Conn.got:
      vv, hh = Conn.got.split(',')
      Conn.got = ''
      pos = int(vv), int(hh)
  if Conn.name and Conn.got == 'close':
    vim.command('redraw')
    game_over()
    return True
  # for each existing piece, find max number of consecutive ones to the right, down, and down right
  if not pos:
    while True:
      pos = random.randint(0, VREPEAT), random.randint(0, HREPEAT)
      if pos not in POS: break
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
  if Conn.name:
    Conn.put = '{},{}'.format(*pos)
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
      if pos not in POS: continue
      lines[vv][hh] = POS.get(pos, ' ')
  update_buffer([''.join(x) for x in lines])
  if resize:
    vv, hh = VSTART + VREPEAT // 2 * VLEN + 1, HSTART + HREPEAT // 2 * HLEN + 1
    vim.eval('cursor({}, {})'.format(vv, hh))

def play():
  global FROZEN
  msg = '''
  Gomoku
  You can play with computer directly by using the following commands:
    j/k/h/l to move, x to put a piece, c to clear, z to position cursor
  `:Save fname` to save the current session.
  `:Resotre fname` to restore the saved session.
  `:Server port` to start server and move first after connection.
  `:Client [host:]port` to start client.
  `:Play` to start game.
  `:Stop` to stop game and do normal editing.

  Do you want to move first? y/N
  '''
  if FROZEN == 'stopped':
    vim.command('call Setup()')
    FROZEN = False
    draw_board(resize=True)
    return
  else:
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
  vim.command('redraw')

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

def stop_game():
  global FROZEN
  FROZEN = 'stopped'
  stop_conn()
  vim.command('nmapclear')
  vim.command('set modifiable')
  vim.current.buffer[:] = []
  vim.command('redraw')
  vim.command('source ~/.vimrc')
EOL

function! Setup()
  command! Play python3 play()
  command! Stop python3 stop_game()
  command! Disconnect python3 stop_conn()
  command! -nargs=1 Server python3 start_server(<f-args>)
  command! -nargs=1 Client python3 start_client(<f-args>)
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
  autocmd VimResized * python3 draw_board(True)
  autocmd QuitPre * Disconnect
  set nonumber
  set ch=1
  set nofoldenable
  set nomodifiable
  set mouse=
endfunction

call Setup()
Play
" shopt -s checkwinsize
