function updateBadgeCount() {
  var link = document.querySelector("link[rel*='icon']");
  var match = link.href.match(/unreadcountfavicon\/\d+\/(\d+)_/);

  if (match != null) {
    var unreadCount = parseInt(match[1]);
    window.webkit.messageHandlers.badge.postMessage({"count": unreadCount});
  }
}

setInterval(updateBadgeCount, 60000);

// https://stackoverflow.com/questions/2497200/how-to-listen-for-changes-to-the-title-element
var target = document.querySelector('title');

var observer = new MutationObserver(function(mutations) {
  setTimeout(updateBadgeCount, 1000);
});

var config = { childList: true };
observer.observe(target, config);

var header = document.getElementsByTagName('header')[0];

header.ondragstart = function() {
  return false;
};

header.onmousedown = function(event) {
  console.log("mouse down");

  function onMouseUp(event) {
    document.removeEventListener('mouseup', onMouseUp);
    console.log("mouse up");
  }

  window.addEventListener('mouseup', onMouseUp);
};
