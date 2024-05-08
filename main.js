var dest = $('.dest'), src = $('.src'),
  curr = 0, cnt = 0, timeout = 200, intval,
  all = [], range = [];
var typist = $('.typist').get(0), write = $('.write').get(0);

function showChar()
{
  $(dest.children()[curr]).addClass('show');
  curr++;
  write.pause();
  write.currentTime = 0;
  if(curr < dest.children().length) return;
  clearInterval(intval);
  $('.source').addClass('show');
  typist.pause();
  setTimeout(function(){
    $('button.underline').trigger('click');
  }, timeout);
}

$('button.start').click(function(){
  curr = 0;
  $('.source').removeClass('show');
  dest.children().removeClass('show').removeClass('hl');
  intval = setInterval(showChar, timeout);
  write.currentTime = 0;
  typist.play();
  write.play();
});

function hlRange()
{
  var delay = false, node = $(dest.contents()[cnt]);
  if($.inArray(cnt, range) != -1 && node[0].tagName == 'B')
  {
    node.addClass('hl');
    delay = true;
  }
  cnt++;
  if(cnt > dest.children().length)
  {
    write.pause();
    return;
  }
  if(delay) setTimeout(hlRange, timeout);
  else hlRange();
}

$('button.underline').click(function(){
  range = [];
  cnt = 0;
  var started = false;
  data = src.val().split('::').pop().split(/\|/g);
  $.each(data, function(idx, val){
    if(started) $.each(all.slice(cnt, cnt + val.length), function(kk, vv){
      range.push(vv);
    });
    cnt += val.length;
    started = !started;
  });

  write.play();
  dest.children().removeClass('hl');
  cnt = 0;
  hlRange();
});

$('button.copy').click(function(){
  $('.dest').empty();
  all = [];
  var data = src.val().split('::');
  if(data.length > 1) source = data.shift();
  else source = '佛语典故';
  $('.source').text(source).removeClass('show');
  $.each(data.pop().replace(/\|/g, ''), function(idx, val){
    if(val == '。')
      $('<span class="stop"></span>').appendTo('.dest');
    else if(val == '，')
      $('<span class="comma"></span>').appendTo('.dest');
    else
      $('<b>'+val+'</b>').appendTo('.dest');
    all.push(idx);
  });
});

$('button.big').click(function(){
  var fsize = parseInt($('div.quote').css('font-size')) + 1;
  var small = Math.floor(fsize *.66);
  $('div.quote').css('font-size', fsize + 'px')
  $('div.source').css('font-size', small + 'px')
});
$('button.small').click(function(){
  var fsize = parseInt($('div.quote').css('font-size')) - 1;
  var small = Math.floor(fsize *.66);
  $('div.quote').css('font-size', fsize - 1 + 'px')
  $('div.source').css('font-size', small + 'px')
});
$('button.save').click(function(){
});

$(document).ready(function(){
  if($.browser.safari)
    $('div.quote').addClass('safari');
  else if($.browser.chrome)
    $('div.quote').addClass('chrome');
  $('button.copy').click();
});
