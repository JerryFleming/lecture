if !has('python3')
  echoerr 'Vim is not compiled with python3.'
  finish
endif
py3 << EOL
import random
import vim

class Shape:
  T = [
    [[0,1,0], [1,1,1]],
    [[1,0], [1,1], [1,0]],
    [[1,1,1], [0,1,0]],
    [[0,1], [1,1], [0,1]],
  ]
  L = [
    [[0,0,1],[1,1,1]],
    [[1,0], [1,0], [1,1]],
    [[1,1,1],[1,0,0]],
    [[1,1], [0,1], [0,1]],
  ]
  J = [
    [[1,0,0], [1,1,1]],
    [[1,1], [1,0], [1,0]],
    [[1,1,1], [0,0,1]],
    [[0,1], [0,1], [1,1]],
  ]
  Z = [
    [[0,1,1], [1,1,0]],
    [[1,0], [1,1], [0,1]],
  ]
  S = [
    [[1,1,0], [0,1,1]],
    [[0,1], [1,1], [1,0]],
  ]
  O = [
    [[1,1], [1,1]],
  ]
  I = [
    [[1,1,1,1]],
    [[1],[1],[1],[1]],
  ]
  shapes = (T0, La, Lb, Na, Nb, Sq, Br)
class Piece:
  data = []
  rotation = 0
  left = 0
  top = 0
class Board:
  width = 0
  height = 0
  ground = []

def genere_piece():
  Piece.data = random.randint(len(Shape.shapes))
  width = len(Piece.data[Piece.totation][0])
  Piece.left = random.randint(Board.width - width)

def detect_ground():
  if any block taken: return True

def remove_bottom():
  if not bottom_filled: return
  move line down
  redraw
  remove_bottom

def game_over():
  if first row is filled: return True

def rotate(clockwise=True):
  if clockwise:
    Piece.rotation += 1
  else:
    Piece.rotation -= 1
  Piece.rotation %= len(Piece.data)
  choose center
  choose new offset
  if off-screen: adjust offset
    if offset.top < 0: offset.top = 0
    if offset.left < 0: offset.left = 0
    if offset.right > screen.width: offset.left -= offset.width
  
EOL

function! Setup()
endfunction

call Setup()
