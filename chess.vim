python3 << EOL
import math
import json
import socket
import time
import textwrap
import vim
from collections import defaultdict
from threading import Thread, Timer

socket.setdefaulttimeout(.2)

# board is h-center aligned and v-top aligned
# NB: vim position starts with 1, while python with 0
class Board:
  _style = 0
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
  Empty = Board.vseg[Board.hlen // 2]
  # X is for you, O is for your opponent (friend or computer)
  empty, black, white = 0, -1, 1
  Black, White = 'X', 'O'
  map = {
    empty: Empty,
    black: Black,
    white: White,
    Empty: empty,
    Black: black,
    White: white,
  }
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
POS = defaultdict(int)

WILLWIN = 100000000

class Pattern:
  W = (
    [ 1, 1, 1, 1, 1],
  )
  U4 = (
    [ 0, 1, 1, 1, 1, 0],
  )
  U3 = (
    [ 0, 1, 1, 1, 0, 0],
    [ 0, 0, 1, 1, 1, 0],
    [ 0, 1, 0, 1, 1, 0],
    [ 0, 1, 1, 0, 1, 0],
  )
  U2 = (
    [ 0, 0, 1, 1, 0, 0],
    [ 0, 1, 0, 1, 0, 0],
    [ 0, 0, 1, 0, 1, 0],
    [ 0, 1, 1, 0, 0, 0],
    [ 0, 0, 0, 1, 1, 0],
    [ 0, 1, 0, 0, 1, 0],
  )
  C4 = (
    [-1, 1, 0, 1, 1, 1],
    [-1, 1, 1, 0, 1, 1],
    [-1, 1, 1, 1, 0, 1],
    [-1, 1, 1, 1, 1, 0],
    [ 0, 1, 1, 1, 1,-1],
    [ 1, 0, 1, 1, 1,-1],
    [ 1, 1, 0, 1, 1,-1],
    [ 1, 1, 1, 0, 1,-1],
  )
  C3 = (
    [-1, 1, 1, 1, 0, 0],
    [-1, 1, 1, 0, 1, 0],
    [-1, 1, 0, 1, 1, 0],
    [ 0, 0, 1, 1, 1,-1],
    [ 0, 1, 0, 1, 1,-1],
    [ 0, 1, 1, 0, 1,-1],
    [-1, 1, 0, 1, 0, 1,-1],
    [-1, 0, 1, 1, 1, 0,-1],
    [-1, 1, 1, 0, 0, 1,-1],
    [-1, 1, 0, 0, 1, 1,-1],
  )
  w = u4 = u3 = u2 = c4 = c3 = 0

def score_ptn(ptn):
  if ptn.w: return WILLWIN * 10
  elif ptn.u4: return WILLWIN
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

def contains(ptns, combo):
  for ptn in ptns:
    neg = [-x for x in ptn]
    for idx in range(len(combo) - len(ptn) + 1):
      if ptn == combo[idx:idx+len(ptn)]: return True
      if neg == combo[idx:idx+len(ptn)]: return True
  return False

def get_value(*combos):
  ptn = Pattern()
  for combo in combos:
    if   contains(ptn.W,  combo): ptn.w  += 1
    elif contains(ptn.C4, combo): ptn.c4 += 1
    elif contains(ptn.C3, combo): ptn.c3 += 1
    elif contains(ptn.U4, combo): ptn.u4 += 1
    elif contains(ptn.U3, combo): ptn.u3 += 1
    elif contains(ptn.U2, combo): ptn.u2 += 1
  return score_ptn(ptn)

def minimax(node, depth, player, pnode):
  if depth == 0: return heuristic(node, pnode)
  alpha = -math.inf
  for child in find_children(node, player):
    alpha = max(alpha, -minimax(child, depth - 1, -player, node))
  return alpha

def find_children(pnode, player):
  ring = 1 # ring size aroung current cell
  children = []
  candidates = set()
  for v, h in list(pnode):
    if not pnode[v,h]: continue
    # upper bound inclusive
    for vv in range(v - ring, v + ring + 1):
      for hh in range(h - ring, h + ring + 1):
        pos = vv, hh
        if pnode[pos]: continue
        if pos in candidates: continue
        candidates.add(pos)
        node = pnode.copy()
        node[pos] = -player
        children.append(node)
  return children

def get_combo(node, dir1, dir2, player):
  combo = [player]
  for pos in dir1[1:]:
    combo.insert(0, node[pos])
    if node[pos] == -player: break
  for pos in dir2[1:]:
    combo.append(node[pos])
    if node[pos] == -player: break
  return combo

def heuristic(node, pnode):
  for pos in node | pnode:
    # check pos on both sides
    if node[pos] == pnode[pos]: continue
    directions = list(get_directions(pos))
    vplayer = get_value(
      get_combo(node, directions[0], directions[1], node[pos]),
      get_combo(node, directions[2], directions[3], node[pos]),
      get_combo(node, directions[4], directions[5], node[pos]),
      get_combo(node, directions[6], directions[7], node[pos]),
    )
    node[pos] *= -1
    vother = get_value(
      get_combo(node, directions[0], directions[1], node[pos]),
      get_combo(node, directions[2], directions[3], node[pos]),
      get_combo(node, directions[4], directions[5], node[pos]),
      get_combo(node, directions[6], directions[7], node[pos]),
    )
    node[pos] *= -1
    return 2 * vplayer + vother
  return 0

def find_move(player):
  max_child = None
  maxv = -math.inf
  children = find_children(POS, player) # put_piece
  for child in children:
    val = minimax(child, 0, -player, POS)
    if maxv >= val: continue
    maxv = val
    max_child = child
  for pos in max_child:
    if max_child[pos] == POS[pos]: continue
    return pos

def physical_pos(vpos, hpos, absolute=False):
  if absolute:
    vpos -= Board.vpos
    hpos -= Board.hpos
  # pysical position is 1-based
  return [
    Board.vstart + vpos * Board.vlen + 1,
    Board.hstart + hpos * Board.hlen + 1,
  ]

#     cartesian coordinates
#
#               ^(0,1)
#   (-1,1) +----+----+(1,1)
#          |    |    |
#  (-1,0)--+----+----+->(1,0)
#          |    |    |
#          +----+----+(1,-1)
#   (-1,-1)     |(0,-1)
#
def get_directions(pos):
  for direction in [
    [-1, 0], [ 1, 0],
    [ 0,-1], [ 0, 1],
    [-1,-1], [ 1, 1],
    [-1, 1], [ 1,-1],
  ]:
    yield [(pos[0]+x*direction[0], pos[1]+x*direction[1]) for x in range(5)]

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
  new = {str(k):Color.map[v] for k, v in POS.items() if v}
  open (fname, 'w').write(json.dumps(new))
  print('Session saved.')

def restore_session(fname):
  new = json.loads(open(fname).read())
  POS.clear()
  for k, v in new.items():
    vim.command('call clearmatches()')
    pos = eval(k)
    POS[pos] = Color.map[v]
    draw_board()
    vim.command('call matchaddpos("WarningMsg", [%s])' % physical_pos(*pos, True))
    print('Press any char to continue...')
    vim.command('redraw')
    char = vim.eval('getcharstr()')
  draw_board()
  print('Reloaded saved session.')

def clear_session():
  message('Are you sure to clear the session? y/N', False)
  print('')
  char = vim.eval('getcharstr()')
  vim.command('redraw')
  if char.lower() != 'y':
    return
  POS.clear()
  draw_board()
  print('Session cleared.')

def game_over():
  draw_board()
  msg = 'Game over!'
  message(msg, False)
  Status.frozen = True
  stop_conn()

def check_win(pos, side):
  msg = ''
  for direction in get_directions(pos):
    if any(POS[x]!=side for x in direction): continue
    msg = 'You win!' if side == Color.black else 'You lose!'
    marks = [physical_pos(vpos, hpos, True) for vpos, hpos in direction]
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

def clear_message():
  Status.message = False
  vim.command('call clearmatches()')
  vim.command('redraw')

def move_cursor(direction):
  vv, hh, vpos, hpos = get_pos()
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

def get_pos():
  _, vv, hh, _ = vim.eval('getpos(".")')
  vv, hh = int(vv), int(hh)
  # pysical position is 1-based
  vpos = (vv - 1 - Board.vstart) // Board.vlen
  hpos = (hh - 1 - Board.hstart) // Board.hlen
  return vv, hh, vpos, hpos

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
    pos = find_move(Color.black)
  POS[pos] = Color.white
  vim.command('call matchaddpos("WarningMsg", [%s])' % physical_pos(*pos, True))
  draw_board()
  vim.command('redraw')
  ret = check_win(pos, Color.white)
  if not ret:
    print('Your move now.')
  Status.waiting = False

def put_piece():
  if Status.frozen:
    return
  if Status.waiting:
    print('Not your turn yet.')
    return
  _, _, vpos, hpos = get_pos()
  pos = vpos + Board.vpos, hpos + Board.hpos
  if POS[pos]:
    print('This position is occupied.')
    return
  POS[pos] = Color.black
  if Conn.name:
    Conn.put = '{},{}'.format(*pos)
  draw_board()
  vim.command('redraw')
  ret = check_win(pos, Color.black)
  if not ret:
    auto_move()

def style(num):
  _style = int(num)
  if _style == 0:
    vseg, hseg = '|   ', '+---'
  elif _style == 1:
    vseg, hseg = ' . ', '   '
  elif _style == 2:
    vseg, hseg = '    ', '    '
  vlen, hlen = 2, len(hseg)
  vstart, hstart = vlen // 2, hlen // 2
  items = locals()
  for key, val in items.items():
    setattr(Board, key, val)
  if isinstance(num, str):
    draw_board()

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
      lines[vv-1][hh-1] = Color.map[POS[pos]] # python index is 0-based
  update_buffer([''.join(x) for x in lines])
  if resize and POS:
    vv, hh = physical_pos(*list(POS)[0])
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
  `:Style [0|1|2]` to change lane style.

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
  command! -nargs=1 Style python3 style(<f-args>)
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
