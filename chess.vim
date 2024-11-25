python3 << EOL
import json
import random
import socket
import time
import textwrap
import vim
from threading import Thread, Timer

socket.setdefaulttimeout(.2)

# board is h-center aligned and v-top aligned
# NB: vim position starts with 1, while python with 0
class Board:
  _style = 2
  if _style == 0:
    # lane separators, ensure first char is corner sep
    vseg, hseg = '|   ', '+---'
  elif _style == 1:
    vseg, hseg = ' . ', '   '
  elif _style == 2:
    # if you don't want lane marks
    vseg, hseg = '    ', '    '
  # repeat times of horizontal and vertical lanes,
  # which is the number of pieces allowed in a row/column
  vrepeat, hrepeat = 0, 0
  # starting position of viemport for pieces
  vpos, hpos = 0, 0
  # each vlane is 2 physical lines (hbar and vbar)
  vlen, hlen = 2, len(hseg)
  # horizontal/vertical center position of top left cell
  # hstart is updated later, vstart is fixed
  vstart, hstart = vlen // 2, hlen // 2
class Color:
  # middle of vseg
  empty = Board.vseg[Board.hlen // 2]
  # X is you, O is for your opponent or computer
  black, white = 'X', 'O'
class Conn:
  name = None # connection handler
  put = '' # msg to send
  got = '' # msg received
class Status:
  waiting = False # waiting for computer/friend
  frozen = False # game over etc
  message = False # a msg is displayed (no clear until timeout)
# position of pieces, index by (v,h) lane number on board
# (not physical line/column)
POS = {}
# score of each position, updated when new piece is filled
SCORE = {}
WILLWIN = 100000000

class Pattern:
  U4 = (
    { 0, 1, 1, 1, 1, 0},
  )
  U3 = (
    { 0, 1, 1, 1, 0, 0},
    { 0, 0, 1, 1, 1, 0},
    { 0, 1, 0, 1, 1, 0},
    { 0, 1, 1, 0, 1, 0},
  )
  U2 = (
    { 0, 0, 1, 1, 0, 0},
    { 0, 1, 0, 1, 0, 0},
    { 0, 0, 1, 0, 1, 0},
    { 0, 1, 1, 0, 0, 0},
    { 0, 0, 0, 1, 1, 0},
    { 0, 1, 0, 0, 1, 0},
  )
  C4 = (
    {-1, 1, 0, 1, 1, 1},
    {-1, 1, 1, 0, 1, 1},
    {-1, 1, 1, 1, 0, 1},
    {-1, 1, 1, 1, 1, 0},
    { 0, 1, 1, 1, 1,-1},
    { 1, 0, 1, 1, 1,-1},
    { 1, 1, 0, 1, 1,-1},
    { 1, 1, 1, 0, 1,-1},
  )
  C3 = (
    {-1, 1, 1, 1, 0, 0},
    {-1, 1, 1, 0, 1, 0},
    {-1, 1, 0, 1, 1, 0},
    { 0, 0, 1, 1, 1,-1},
    { 0, 1, 0, 1, 1,-1},
    { 0, 1, 1, 0, 1,-1},
    {-1, 1, 0, 1, 0, 1,-1},
    {-1, 0, 1, 1, 1, 0,-1},
    {-1, 1, 1, 0, 0, 1,-1},
    {-1, 1, 0, 0, 1, 1,-1},
  )
  u4 = 0
  u3 = 0
  u2 = 0
  c4 = 0
  c3 = 0

def score_ptn(ptn):
  if ptn.u4: return WILLWIN
  elif ptn.c4 > 1: return WILLWIN / 10
  elif ptn.u3 > 0 and ptn.c4: return WILLWIN / 100
  elif ptn.u3 > 1: return WILLWIN / 1000
  elif ptn.u3 == 1:
    if ptn.u2 == 3: return 40000
    elif ptn.u2 == 2: return 38000
    elif ptn.u2 == 1: return 35000
    else: return 3450
  elif ptn.c4 == 1:
    if ptn.u2 == 3: return 4500
    elif ptn.u2 == 2: return 4200
    elif ptn.u2 == 1: return 4100
    else: return 4050
  elif ptn.c3 == 3:
    if ptn.u2 == 1: return 2800
  elif ptn.c3 == 2:
    if ptn.u2 == 2: return 3000
    elif ptn.u2 == 1: return 2900
  if ptn.c3 == 1:
    if ptn.u2 == 3: return 3400
    elif ptn.u2 == 2: return 3300
    elif ptn.u2 == 1: return 3100
  elif ptn.u2 == 4: return 2700
  elif ptn.u2 == 3: return 2500
  elif ptn.u2 == 2: return 2000
  elif ptn.u2 == 1: return 1000
  return 0

def contains(ptns, arr):
  # number sign is reversed later, so chosen randomly here
  mapping = {
    0: Color.empty,
    1: Color.white,
    -1: Color.black,
  }
  for ptn in ptns:
    pos = [mapping(x) for x in ptn]
    neg = [mapping(-x) for x in ptn]
    for idx in range(len(arr) - len(ptn)):
      if ptn == arr[idx:idx+len(ptn)]: return True
      if neg == arr[idx:idx+len(ptn)]: return True
      continue
  return False

def find_score(pos, reverse=False):
  if Conn.name:
    # not playing with computer
    return
  other = Color.black if POS.get(pos) == Color.white else Color.white
  if reverse:
    other = POS.get(pos)
  ptn = Pattern()
  for direction in get_directions(pos):
    ret = []
    for start in range(4, -1, -1):
      cur = POS.get(direction[start])
      ret.insert(0, cur)
      if cur == other: break
    for start in range(5, 10):
      cur = POS.get(direction[start])
      ret.push(cur)
      if cur == other: break
    if contains(Pattern.U4, ret): ptn.u4 += 1
    if contains(Pattern.U3, ret): ptn.u3 += 1
    if contains(Pattern.C4, ret): ptn.c4 += 1
    if contains(Pattern.C3, ret): ptn.c3 += 1
    if contains(Pattern.U2, ret): ptn.u2 += 1
  return score_ptn(ptn)

def update_score(pos):
  for rnd, direction in enumerate(get_directions(pos)):
    for idx, item in enumerate(direction):
      # for central point, should do it only once
      if rnd and idx == 4: continue
      score1 = find_score(item, True)
      score2 = find_score(item, False)
      SCORE[item] = score1 * 2 + score2

def server_loop(action):
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
        Conn.name = client
        print(f'Accepted connection from {address}. Your move now.')
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
    message(msg, False)

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
  print('')
  char = vim.eval('getcharstr()')
  vim.command( 'redraw')
  if char.lower() != 'y':
    return
  POS.clear()
  draw_board()
  print('Session cleared.')

def check_win(pos, side):
  msg = ''
  for direction in get_directions(pos):
    # Foreach direction, only check 5 consecutive pieces, up to the middle
    for start in range(5):
      if POS.get(direction[start], '') != side: continue
      if any([POS.get(x, '')!=side for x in direction[start:start+5]]): continue
      msg = 'You win!' if side == Color.black else 'You lose!'
      marks = [physical_pos(vpos, hpos) for vpos, hpos in direction[start:start+5]]
      vim.command('call matchaddpos("WarningMsg", %s)' % marks)
      break
  if msg:
    msg += '\nDo you want to play again? y/N'
    message(msg, False)
    vim.command('redraw')
    print('')
    char = vim.eval('getcharstr()')
    if char.lower() == 'y':
      POS.clear()
      draw_board()
    else:
      game_over()
      return True
  return False

def move_cursor(direction):
  vv, hh, vpos, hpos = getpos()
  pieces = 5 # there are 5 pieces in a row/column to win
  if direction == 'j':
    if vpos >= Board.vrepeat - pieces:
      Board.vpos += 1
    else:
      vpos += 1
  elif direction == 'k':
    if vpos <= pieces:
      Board.vpos -= 1
    else:
      vpos -= 1
  elif direction == 'h':
    if hpos <= pieces:
      Board.hpos -= 1
    else:
      hpos -= 1
  elif direction == 'l':
    if hpos >= Board.hrepeat - pieces:
      Board.hpos += 1
    else:
      hpos += 1
  vpos = min(max(vpos, pieces), Board.vrepeat - pieces)
  hpos = min(max(hpos, pieces), Board.hrepeat - pieces)
  vv, hh = physical_pos(vpos, hpos)
  vim.eval('cursor({}, {})'.format(vv, hh))
  print('Position:', vpos + Board.vpos, hpos + Board.hpos)
  clear_message()
  draw_board()

def getpos():
  _, vv, hh, _ = vim.eval('getpos(".")')
  vv, hh = int(vv), int(hh)
  # pysical position is 1-based
  vpos = (vv - 1 - Board.vstart) // Board.vlen
  hpos = (hh - 1 - Board.hstart) // Board.hlen
  return vv, hh, vpos, hpos

def game_over():
  draw_board()
  msg = 'Game over!'
  message(msg, False)
  Status.frozen = True
  stop_conn()

def auto_move():
  Status.waiting = True
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
  if not POS:
    pos = Board.vrepeat // 2, Board.hrepeat // 2
  else:
    for item in SCORE:
      if SCORE[item] != max(SCORE.values()): continue
      pos = item
      break
  if not pos:
    while True:
      pos = random.randint(0, Board.vrepeat), random.randint(0, Board.hrepeat)
      if pos not in POS: break
  POS[pos] = Color.white
  vim.command('call matchaddpos("WarningMsg", [%s])' % physical_pos(*pos))
  #update_score(pos)
  draw_board()
  vim.command('redraw')
  ret = check_win(pos, Color.white)
  if not ret:
    print('Your move now.')
  Status.waiting = False

def get_directions(pos):
  duration = 9 # number of consecutive pieces to look ahead
  # Patterns on 4 directions: vertical, horizontal, slash, back slash.
  # This inclues pattersn startig from the give place and that ends there.
  return [
    [(pos[0]-4+x, pos[1]) for x in range(duration)], # vertical
    [(pos[0], pos[1]-4+x) for x in range(duration)], # horzontal
    [(pos[0]-4+x, pos[1]-4+x) for x in range(duration)], # slash
    [(pos[0]-4+x, pos[1]+4-x) for x in range(duration)], # back slash
  ]

def put_piece():
  if Status.frozen:
    return
  if Status.waiting:
    print('Not your turn yet.')
    return
  _, _, vpos, hpos = getpos()
  pos = vpos + Board.vpos, hpos + Board.hpos
  if pos in POS:
    print('This position is occupied.')
    return
  POS[pos] = Color.black
  #update_score(pos)
  if Conn.name:
    Conn.put = '{},{}'.format(*pos)
  draw_board()
  vim.command('redraw')
  ret = check_win(pos, Color.black)
  if not ret:
    auto_move()

def physical_pos(vpos, hpos):
  # pysical position is 1-based
  return [
    Board.vstart + vpos * Board.vlen + 1,
    Board.hstart + hpos * Board.hlen + 1,
  ]

def draw_board(resize=False):
  if Status.message: return
  Board.hrepeat, remain = divmod(vim.current.window.width, Board.hlen)
  if not remain:
    remain += Board.hlen # remove last open column
    Board.hrepeat -= 1
  remain -= 1 # close last open clumn
  remain = remain // 2 * ' '
  Board.hstart = len(remain) + Board.hlen // 2
  Board.vrepeat = vim.current.window.height // Board.vlen
  vline = remain + Board.vseg * Board.hrepeat + Board.vseg[0]
  hline = remain + Board.hseg * Board.hrepeat + Board.hseg[0]
  lines = [hline, vline] * Board.vrepeat
  if vim.current.window.height % Board.vlen:
    lines.append(hline) # add closing bottom line
  else:
    lines = lines[:-1] # remove open bottom line
    Board.vrepeat -= 1
  lines = [list(x) for x in lines]
  for v in range(Board.vrepeat):
    for h in range(Board.hrepeat):
      pos = v + Board.vpos, h + Board.hpos
      if pos not in POS: continue
      vv, hh = physical_pos(v, h)
      lines[vv-1][hh-1] = POS.get(pos) # python index is 0-based
  update_buffer([''.join(x) for x in lines])
  if resize:
    vv, hh = physical_pos(Board.vrepeat // 2, Board.hrepeat // 2)
    vim.eval('cursor({}, {})'.format(vv, hh))

def play():
  msg = '''
  Gomoku
  You can play with computer directly or with your friend by using the following commands:
    j/k/h/l to move, x to put a piece, c to clear, z to position cursor
  `:Save fname` to save the current session.
  `:Resotre fname` to restore the saved session.
  `:Server port` to start server and move first after connection.
  `:Client [host:]port` to start client.
  `:Play` to start game.
  `:Stop` to stop game and do normal editing.

  Do you want to move first? y/N
  '''
  if Status.frozen:
    vim.command('call Setup()')
    Status.frozen = False
    draw_board(resize=True)
    POS.clear()
    draw_board()
    return
  else:
    message(msg, model=True)
  print('')
  char = vim.eval('getcharstr()')
  draw_board() # do this so we have vrepeat/hrepeat
  vim.command('redraw')
  if char.lower() != 'y':
    POS[Board.vrepeat // 2, Board.hrepeat // 2] = Color.white
    draw_board(resize=True)
    print(f'Your move now.')
  else:
    draw_board(resize=True)

def update_buffer(lines):
  vim.command('set modifiable')
  vim.current.buffer[:] = lines
  vim.command('set nomodifiable')
  vim.command('redraw')

def clear_message():
  Status.message = False
  vim.command('call clearmatches()')
  vim.command('redraw')

def message(msg, model=True) :
  if not model:
    Status.message = True
  msg = textwrap.dedent(msg).strip().splitlines()
  width = max(len(x) for x in msg)
  block, remain = divmod(width, Board.hlen)
  if remain: # ensure covering multiple horizontal blocks
    block += 1
    width = block * Board.hlen
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
  Status.frozen = True
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
