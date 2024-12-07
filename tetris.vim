if !has('python3')
  echoerr 'Vim is not compiled with python3.'
  finish
endif
py3 << EOL
import random
import time
import vim
from threading import Thread, active_count

SHAPE = {
  'T': [[0,1,0], [1,1,1]],
  'L': [[0,0,1], [1,1,1]],
  'J': [[1,0,0], [1,1,1]],
  'Z': [[0,1,1], [1,1,0]],
  'S': [[1,1,0], [0,1,1]],
  'O': [[1,1], [1,1]],
  'I': [[1,1,1,1]],
}
ROTATION = {
  'T': [[2,2], [2,1], [1,2], [2,2]],
  'L': [[2,2], [2,1], [1,2], [2,2]],
  'J': [[2,2], [2,1], [1,2], [2,2]],
  'Z': [[2,2], [2,1], [1,2], [2,2]],
  'S': [[2,2], [2,1], [1,2], [2,2]],
  'O': [[1,1]],
  'I': [[1,2], [2,1]],
}
class Piece:
  data = []
  shape = ''
  rotation = 0
  top = left = width = height = 0
class Board:
  width = height = 0
  ground = []
class Status:
  quit = False

def new_piece():
  rotation = random.randint(0, 4)
  Piece.rotation = rotation
  keys = list(SHAPE.keys())
  Piece.shape = random.choice(keys)
  data = SHAPE[Piece.shape]
  while rotation:
    data = list(zip(*data[::-1]))
    rotation -= 1
  Piece.data = data
  Piece.height, Piece.width = len(Piece.data), len(Piece.data[0])
  Piece.top = 0
  Piece.left = random.randint(0, Board.width - Piece.width)

def change_ground():
  for v in reversed(range(Piece.height)):
    idx = v + Piece.top - Board.height
    if idx + len(Board.ground) < 0:
      Board.ground.insert(0, [0] * Board.width)
    line = Board.ground[idx]
    row = Piece.data[v]
    for k,v in enumerate(row):
      if not v: continue
      line[Piece.left+k] = 1
    Board.ground[idx] = line
  # remove all filled lines
  Board.ground = [x for x in Board.ground if not all(x)]
  if len(Board.ground) >= Board.height:
    return game_over()
  new_piece()
  draw_board()

def detect_ground():
  if Piece.top + Piece.height == Board.height:
    return change_ground()
  top = Piece.top + 1
  for v in reversed(range(Piece.height)):
    idx = v + top - Board.height
    if v + top < Board.height - len(Board.ground):
      return False
    line = Board.ground[idx]
    row = Piece.data[v]
    hit = [line[Piece.left+k]==v==1 for k,v in enumerate(row)]
    if any(hit):
      return change_ground()

def game_over():
  pass

def move(direction):
  if direction == 'l':
    Piece.left = max(0, Piece.left - 1)
  elif direction == 'r':
    Piece.left = min(Board.width - Piece.width, Piece.left + 1)
  elif direction == 'u':
    Piece.top = max(0, Piece.top - 1)
  elif direction == 'd':
    Piece.top = min(Board.height - Piece.height, Piece.top + 1)
    detect_ground()
  draw_board()

def detect_hit(data, top, left, height):
  for v in reversed(range(height)):
    idx = v + top - Board.height
    if v + top < Board.height - len(Board.ground):
      return False
    line = Board.ground[idx]
    row = data[v]
    hit = [line[left+k]==v==1 for k,v in enumerate(row)]
    if any(hit):
      return True

def rotate(clockwise=True):
  rdata = ROTATION[Piece.shape]
  prev = rdata[Piece.rotation % len(rdata)]
  rotation = Piece.rotation
  if clockwise:
    data = list(zip(*Piece.data[::-1]))
    rotation += 1
  else:
    data = list(zip(*Piece.data))[::-1]
    rotation -= 1
  cur = rdata[rotation % len(rdata)]
  height, width = len(data), len(data[0])
  top =  min(max(0, Piece.top -  cur[0] + prev[0]), Board.height - height)
  left = min(max(0, Piece.left - cur[1] + prev[1]), Board.width  - width)
  if detect_hit(data, top, left, height):
    return
  Piece.data = data
  Piece.rotation = rotation
  Piece.top, Piece.left = top, left
  Piece.width, Piece.height = width, height
  draw_board()

def update_buffer(lines, width):
  vim.command('set modifiable')
  for idx, line in enumerate(lines):
    vim.current.buffer[idx] = line + vim.current.buffer[idx][width:]
  vim.command('set nomodifiable')
  vim.command('redraw')
  vim.command('set nomodified')

def draw_board():
  lines = []
  for v in range(Board.height):
    line = list(' ' * Board.width)
    if Piece.data:
      if v-Piece.top in range(Piece.height):
        line[Piece.left:Piece.left+Piece.width] = ['0' if x else ' ' for x in Piece.data[v-Piece.top]]
    idx = v - Board.height + len(Board.ground)
    if idx >= 0:
      for k,v in enumerate(Board.ground[idx]):
        if not v: continue
        line[k] = 'x'
    line.append('|')
    lines.append(''.join(line))
  lines.append('-' * Board.width + '+')
  update_buffer(lines, Board.width + 1)

def play():
  Board.width = min(20, vim.current.window.width)
  Board.height = min(20, vim.current.window.height)
  Board.ground = [[0] * Board.width]
  vim.command('set modifiable')
  while len(vim.current.buffer) < Board.height + 1:
    vim.current.buffer.append('')
  vim.command('set nomodifiable')
  new_piece()
  if active_count() == 1:
    Thread(target=loop, args=[]).start()

def loop():
  while True:
    if Status.quit: break
    move('d')
    time.sleep(0.3)

def quit(force=False):
  Status.quit = not Status.quit
  if not force and active_count() == 1:
    Thread(target=loop, args=[]).start()
EOL

function! Setup()
  set ft=text
  1
  redraw
  nnoremap <silent> z :py3 rotate(False)<cr>
  nnoremap <silent> / :py3 rotate(True)<cr>
  nnoremap <silent> g :py3 new_piece()<cr>
  nnoremap <silent> h :py3 move('l')<cr>
  nnoremap <silent> l :py3 move('r')<cr>
  nnoremap <silent> j :py3 move('d')<cr>
  nnoremap <silent> <Space> :py3 move('d')<cr>
  nnoremap <silent> k :py3 move('u')<cr>
  nnoremap <silent> q :py3 quit()<cr>
  autocmd QuitPre * py3 quit(True)

  set nonumber
  set ch=10
  set nofoldenable
  set nomodifiable
  message clear
endfunction

call Setup()
py3 play()
