var findArray = function(arr, inArr) {
  var fCount = arr.length;
  var sCount = inArr.length;
  var k;
  for (var i = 0; i <= fCount - sCount; i++) {
    k = 0;
    for (var j = 0; j < sCount; j++) {
      if (arr[i + j] == inArr[j]) k++;
      else break;
    }
    if (k == sCount) return true;
  }
  return false;
};

var isAnyInArrays = function(combos, arr) {
  for (var i = 0; i < combos.length; i++) {
    if (findArray(arr, combos[i])) return true;
  }
  return false;
};

var combinations = {};
combinations.winValue = 1000000000;
combinations.valuePosition = function(arr1, arr2, arr3, arr4) { // 4 directions
  var w = 0,
    u2 = 0,
    u3 = 0,
    u4 = 0,
    c3 = 0,
    c4 = 0;
  var allArr = [arr1, arr2, arr3, arr4];
  for (var i = 0; i < allArr.length; i++) {
    if (isAnyInArrays(win, allArr[i])) {
      w++;
      continue;
    }
    if (isAnyInArrays(covered4, allArr[i])) {
      c4++;
      continue;
    }
    if (isAnyInArrays(covered3, allArr[i])) {
      c3++;
      continue;
    }
    if (isAnyInArrays(unCovered4, allArr[i])) {
      u4++;
      continue;
    }
    if (isAnyInArrays(unCovered3, allArr[i])) {
      u3++;
      continue;
    }
    if (isAnyInArrays(unCovered2, allArr[i])) {
      u2++;
    }
  }
  return valueCombo(w, u2, u3, u4, c3, c4);
};
Array.matrix = function(m, n, initial) {
var a, i, j, mat = [];
for (i = 0; i < m; i++) {
  a = [];
  for (j = 0; j < n; j++) {
    a[j] = initial;
  }
  mat[i] = a;
}
return mat;
};

var initCombinations = require('./combinations');

var gameSize = 5; // 5 in line
var ring = 1; // ring size around current cells
var win = false;
var cellsCount = 15;
var curState = Array.matrix(15, 15, 0);
var complexity = 1;
var combinations = initCombinations();


var minimax = function minimax(node, depth, player, pnode) {
  if (depth == 0) return heuristic(node, pnode);
  var alpha = Number.MIN_VALUE;
  var childs = find_children(node, player);
  for (var i = 0; i < childs.length; i++) {
    alpha = Math.max(alpha, -minimax(childs[i], depth - 1, -player, node));
  }
  return alpha;
};

var isAllSatisfy = function(candidates, pointX, pointY) {
  var counter = 0;
  for (var i = 0; i < candidates.length; i++) {
    if (pointX != candidates[i][0] || pointY != candidates[i][1]) counter++;
  }
  return counter == candidates.length;
};

def find_children(pnode, player):
  children = []
  candidates = []
  for (var i = 0; i < cellsCount; i++) {
    for (var j = 0; j < cellsCount; j++) {
      if (pnode[i][j] != 0) {
        for (var k = i - ring; k <= i + ring; k++) {
          for (var l = j - ring; l <= j + ring; l++) {
            if (k >= 0 && l >= 0 && k < cellsCount && l < cellsCount) {
              if (pnode[k][l] == 0) {
                var curPoint = [k, l];
                var flag = isAllSatisfy(candidates, curPoint[0], curPoint[1]);
                if (flag) candidates.push(curPoint);
  for (var f = 0; f < candidates.length; f++) {
    var tmp = Array.matrix(cellsCount, cellsCount, 0);
    for (var m = 0; m < cellsCount; m++) {
      for (var n = 0; n < cellsCount; n++) {
        tmp[m][n] = pnode[m][n];
    tmp[candidates[f][0]][candidates[f][1]] = -player;
    children.push(tmp);
  return children

var getCombo = function(node, curPlayer, i, j, dx, dy) {
  var combo = [curPlayer];
  for (var m = 1; m < gameSize; m++) {
    var nextX1 = i - dx * m;
    var nextY1 = j - dy * m;
    if (nextX1 >= cellsCount || nextY1 >= cellsCount || nextX1 < 0 || nextY1 < 0) break;
    var next1 = node[nextX1][nextY1];
    if (node[nextX1][nextY1] == -curPlayer) {
      combo.unshift(next1);
      break;
    }
    combo.unshift(next1);
  }
  for (var k = 1; k < gameSize; k++) {
    var nextX = i + dx * k;
    var nextY = j + dy * k;
    if (nextX >= cellsCount || nextY >= cellsCount || nextX < 0 || nextY < 0) break;
    var next = node[nextX][nextY];
    if (next == -curPlayer) {
      combo.push(next);
      break;
    }
    combo.push(next);
  }
  return combo;
};

def heuristic(nnode, onode) {
  for (var i = 0; i < cellsCount; i++) {
    for (var j = 0; j < cellsCount; j++) {
      if (nnode[i][j] != onode[i][j]) {
        var curCell = nnode[i][j];
        var playerVal = combinations.valuePosition(
          getCombo(nnode, curCell, i, j, 1, 0),
          getCombo(nnode, curCell, i, j, 0, 1),
          getCombo(nnode, curCell, i, j, 1, 1),
          getCombo(nnode, curCell, i, j, 1, -1)
        );
        nnode[i][j] = -curCell;
        var oppositeVal = combinations.valuePosition(
          getCombo(nnode, -curCell, i, j, 1, 0),
          getCombo(nnode, -curCell, i, j, 0, 1),
          getCombo(nnode, -curCell, i, j, 1, 1),
          getCombo(nnode, -curCell, i, j, 1, -1)
        );
        nnode[i][j] = -curCell;
        return 2 * playerVal + oppositeVal;
  return 0;

getLogic.makeAnswer = function(x, y) {
  max_child = None
  maxv = -math.inf
  children = find_children(curState, player): # put_piece
  for child in children:
    val = minimax(child, 0, -player, curState);
    if maxv >= value: continue
    maxv = val
    max_child = child
  for (var i = 0; i < cellsCount; i++) {
    for (var j = 0; j < cellsCount; j++) {
      if (max_child[i][j] != curState[i][j]) {
        answ[0] = i
        answ[1] = j
        curState[answ[0]][answ[1]] = -player
        checkWin()
        return answ
  return answ
