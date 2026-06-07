(function () {
  var params = new URLSearchParams(window.location.search);
  var verse = params.get('verse');
  var from = params.get('source');
  if (from !== 'chapter' || !verse) {
    return;
  }
  var chapterButtons = document.querySelectorAll('.chapter-return-btn');
  chapterButtons.forEach(function (button) {
    var url = new URL(button.getAttribute('href'), window.location.href);
    url.hash = 'verse-' + verse;
    button.setAttribute('href', url.toString());
  });
})();
