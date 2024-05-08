function find_content(cat, idx) {
  $(`.bible.${cat} td`).each(function(){
    if(!$(this).hasClass('prepend')) return;
    $(this).text(BIBLE[idx][this.className.replace('prepend ', '')]);
  });
  $.each(BIBLE[idx].table, function(idx, ele){
    $(`.bible.${cat} .row.${idx}.num`).text(ele[0]);
    $(`.bible.${cat} .row.${idx}.title`).text(ele[1]);
    $(`.bible.${cat} .row.${idx}.xiang`).text(ele[2]);
  });
}

function find_gram(cat, pos, up, down, sum) {
  var wuxing;
  if(cat == 'self') {
    wuxing = MAP[pos[0]][2];
    $('.wuxing').text(wuxing);
    $('.wuxing').removeClass('up').removeClass('down').addClass(MAP[pos[0]].slice(-1) < 4 ? 'up': 'down')
    let self = pos[1];
    if(self > 5) self -= 4;
    else if(self) self = 6 - self;
    let other = (self + 3) % 6;
    $('.mark').removeClass('on').text('　');
    $('.mark').eq(self).addClass('on').text('世');
    $('.mark').eq(other).addClass('on').text('应');
  } else {
    wuxing = $('.wuxing').text();
  }
  wuxing = WUXING.indexOf(wuxing);
  let data = MAP[up].slice(3, 6).concat(MAP[down].slice(6, 9));
  $.each(data, function(idx, item){
    if(sum !== undefined) {
      var bit = 2**(5-idx);
      $(`.${cat}.gram`).eq(idx).removeClass('up').removeClass('down')
        .addClass((sum& bit)==bit ? 'down' : 'up');
    }
    let attr = WUXING.indexOf(DIZHI[item.substr(1)]);
    if(attr == wuxing) prefix = '兄弟';
    else if(attr == (wuxing + 1) % 5) prefix = '子孙';
    else if(attr == (wuxing + 5 - 1) % 5) prefix = '父母';
    else if(attr == (wuxing + 2) % 5) prefix = '妻财';
    else if(attr == (wuxing + 5 - 2) % 5) prefix = '官鬼';
    $(`.${cat}.gram`).eq(idx).html(`<span>${prefix}</span><span>　</span><span>${item}</span>`);
    var self = $('.self.gram').eq(idx), other = $('.other.gram').eq(idx);
    if(self.hasClass('up') && other.hasClass('up') || self.hasClass('down') && other.hasClass('down'))
      other.addClass('opaque');
    else
      other.removeClass('opaque');
  });
}

var FOUND = {
  self: 0,
  other: 0,
};
function find_group(ord) {
  var arr = [1, 2, 4, 8, 16, 8, 7];
  for(var i=0; i<7; i++) {
    if(ord % 8 == Math.floor(ord/8)) break;
    ord ^= arr[i];
  }
  return [ord % 8, i];
}
function find_names(cat, clazz, current) {
  let sum = 0, names = $('.names.' + cat);
  if(cat == 'origin') {
    sum = find_group(clazz);
    names.find('.name').text(MAP[sum[0]][0]);
    names.find('.prefix').text(CHANGE[sum[1]]);
    find_gram(cat, sum, sum[0], sum[0]);
  } else if(!isNaN(clazz)) {
    names.find('.name').text(ORDER[clazz]);
    sum = clazz;
    let down = sum % 8, up = Math.floor(sum / 8);
    if(up == down) names.find('.prefix').text('');
    else names.find('.prefix').text(`${MAP[up][1]}${MAP[down][1]}`);
    find_gram(cat, find_group(sum), up, down, sum);
    find_content(cat, sum);
    FOUND[cat] = sum;
    return sum;
  } else {
    $(`td.gram.${cat}`).each(function(idx, ele){
      var bit = $(ele).hasClass('up') ? 0 : 1;
      var weight = 6 - (idx % 6) - 1;
      sum += 2**weight * bit;
      if(ele == current && cat == 'self')
        $('td.gram.other').eq(idx)
          .removeClass('up').removeClass('down').addClass(clazz);
    });
    names.find('.name').text(ORDER[sum]);
    let down = sum % 8, up = Math.floor(sum / 8);
    if(up == down) names.find('.prefix').text('');
    else names.find('.prefix').text(`${MAP[up][1]}${MAP[down][1]}`);
    find_gram(cat, find_group(sum), up, down);
    find_content(cat, sum);
    FOUND[cat] = sum;
    return sum;
  }
}
function warn(msg) {
  $('.date span:last-child').text(msg).show();
  setTimeout(function(){
    $('.date span:last-child').fadeOut(2000);
  }, 1000);
};

var lunar = calendar.solar2lunar();
$('.date span:first-child').text(`${lunar.lYear}年${lunar.IMonthCn+lunar.IDayCn}， ${lunar.gzYear}年${lunar.gzMonth}月${lunar.gzDay}日(${lunar.gzXun}空)`);

$('.gram:not(.origin)').click(function(){
  let clazz = 'up';
  if($(this).hasClass('up')) clazz = 'down';
  $(this).removeClass('up').removeClass('down').addClass(clazz);
  let cat = $(this).hasClass('self') ? 'self' : 'other';
  let found = find_names(cat, clazz, this);
  find_names(cat == 'self' ? 'other' : 'self', clazz, this);
  if(cat == 'self')
    find_names('origin', found, this);
});

$('.hide.other').click(function(){
  $(this).toggleClass('on');
  $('.sep.other').toggle();
  $('.bible.other').toggle();
  $('td.other').css('visibility', $('td.other').css('visibility') == 'visible' ? 'hidden' : 'visible');
  $('.change').css('visibility', $('.change').css('visibility') == 'visible' ? 'hidden' : 'visible');
});
$('.hide.origin').click(function(){
  $(this).toggleClass('on');
  $('td.self').toggle();
  $('td.origin').toggle();
});
$('.hexagram tr').click(function(){
  $(this).addClass('on');
});
$('.hide.link').click(function(){
  var url = location.href.split('?')[0] + `?${ORDER[FOUND.self]},${ORDER[FOUND.other]}`;
  url = encodeURI(url);
  if (navigator.clipboard && window.isSecureContext) {
    navigator.clipboard.writeText(url);
  } else {
    const textArea = document.createElement("textarea");
    textArea.value = url;
    textArea.style.position = "absolute";
    textArea.style.left = "-999999px";
    document.body.prepend(textArea);
    textArea.select();
    try {
      document.execCommand('copy');
    } catch (error) {
      console.error(error);
    } finally {
      textArea.remove();
    }
  }
  warn('链接已复制');
});
$(function(){
  if(location.search) {
    $('.hide.link').addClass('on');
    var found = decodeURI(location.search.substr(1)).split(',');
    var self = ORDER.indexOf(found[0]), other = ORDER.indexOf(found[1]);
    if(self == -1) {
      warn(`原卦名有误:${found[0]}，使用默认名`);
      self = 0;
    }
    if(other == -1) {
      warn(`变卦名有误:${found[1]}，使用默认名`);
      other = 0;
    }
    var ret = find_names('self', self);
    find_names('other', other);
    find_names('origin', ret);
  } else {
    find_names('self', 'up');
    find_names('other', 'up');
    find_names('origin', 0);
  }
});
