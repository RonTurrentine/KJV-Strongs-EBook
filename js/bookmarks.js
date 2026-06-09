// bookmarks.js -- ES3-compatible reading position bookmark
// Auto-saves position on chapter pages; shows resume link on index.html
(function () {
  var KEY = 'kjv-bookmark';

  // Save position when leaving a chapter page
  if (document.body.className.indexOf('bible-text') !== -1) {
    var h1 = document.getElementsByTagName('h1')[0];
    var pageTitle = h1 ? h1.innerText || h1.textContent : document.title;

    window.onbeforeunload = function () {
      var bookmark = {
        url:   window.location.href,
        scroll: window.pageYOffset || document.documentElement.scrollTop || 0,
        title:  pageTitle,
        saved:  new Date().toISOString()
      };
      try { localStorage.setItem(KEY, JSON.stringify(bookmark)); } catch(e) {}
    };
  }

  // Show resume link on index.html
  var resumeDiv = document.getElementById('bookmark-resume');
  if (resumeDiv) {
    var saved = '';
    try { saved = localStorage.getItem(KEY) || ''; } catch(e) {}
    if (saved) {
      var bm = null;
      try { bm = JSON.parse(saved); } catch(e) {}
      if (bm && bm.url && bm.title) {
        resumeDiv.innerHTML = '<p class="bookmark-resume"><a href="' + bm.url +
          '" class="btn">Resume: ' + bm.title + '</a></p>';
      }
    }
  }
}());
