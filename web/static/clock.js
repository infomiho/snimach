// The demo's menu bar shows the visitor's own clock. The server renders a UTC
// fallback, so a reader without JavaScript still sees a plausible Mac.
(function () {
  var clock = document.querySelector(".demo-clock");
  if (!clock) return;

  function paint() {
    var now = new Date();
    var day = now.toLocaleDateString(undefined, {
      weekday: "short",
      day: "numeric",
      month: "short",
    });
    var time = now.toLocaleTimeString(undefined, {
      hour: "numeric",
      minute: "2-digit",
    });
    clock.textContent = day + " " + time;
  }

  paint();
  // Land on the next whole minute, then keep to the minute, like the real one.
  setTimeout(function () {
    paint();
    setInterval(paint, 60000);
  }, 60000 - (Date.now() % 60000));
})();
