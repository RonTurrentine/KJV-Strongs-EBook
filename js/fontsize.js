(function () {
  var SIZES = ['font-normal', 'font-large', 'font-xlarge', 'font-small'];
  var KEY   = 'kjv-fontsize';
  function applySize(size) {
    var i;
    for (i = 0; i < SIZES.length; i++) {
      if (document.body.className.indexOf(SIZES[i]) !== -1) {
        document.body.className = document.body.className.replace(SIZES[i], '');
      }
    }
    document.body.className = (document.body.className + ' ' + size).replace(/\s+/g, ' ').replace(/^\s|\s$/, '');
  }
  var saved = '';
  try { saved = localStorage.getItem(KEY) || ''; } catch(e) {}
  if (saved) { applySize(saved); }
  window.cycleFontSize = function () {
    var current = '';
    var i;
    for (i = 0; i < SIZES.length; i++) {
      if (document.body.className.indexOf(SIZES[i]) !== -1) { current = SIZES[i]; break; }
    }
    var nextIdx  = (SIZES.indexOf(current) + 1) % SIZES.length;
    var nextSize = SIZES[nextIdx];
    applySize(nextSize);
    try { localStorage.setItem(KEY, nextSize); } catch(e) {}
  };
}());
