/* تثبيت تطبيق الويب (PWA) على الشاشة الرئيسية */
(function () {
  var deferredPrompt = null;
  var listeners = [];

  function notify() {
    listeners.forEach(function (cb) {
      try {
        cb();
      } catch (_) {}
    });
  }

  function isStandalone() {
    return (
      window.matchMedia('(display-mode: standalone)').matches ||
      window.matchMedia('(display-mode: fullscreen)').matches ||
      window.matchMedia('(display-mode: minimal-ui)').matches ||
      window.navigator.standalone === true
    );
  }

  function isIos() {
    var ua = window.navigator.userAgent || '';
    return (
      /iPhone|iPad|iPod/i.test(ua) ||
      (window.navigator.platform === 'MacIntel' &&
        window.navigator.maxTouchPoints > 1)
    );
  }

  window.AdhanPwa = {
    isInstalled: function () {
      return isStandalone();
    },
    canInstall: function () {
      return !isStandalone() && deferredPrompt != null;
    },
    isIos: function () {
      return isIos() && !isStandalone();
    },
    promptInstall: function () {
      return new Promise(function (resolve) {
        if (!deferredPrompt) {
          resolve(false);
          return;
        }
        var promptEvent = deferredPrompt;
        deferredPrompt = null;
        notify();
        promptEvent.prompt();
        promptEvent.userChoice
          .then(function (choice) {
            var accepted = choice && choice.outcome === 'accepted';
            notify();
            resolve(!!accepted);
          })
          .catch(function () {
            notify();
            resolve(false);
          });
      });
    },
    onChange: function (cb) {
      if (typeof cb === 'function') listeners.push(cb);
    },
  };

  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    deferredPrompt = e;
    notify();
  });

  window.addEventListener('appinstalled', function () {
    deferredPrompt = null;
    notify();
  });

  try {
    window
      .matchMedia('(display-mode: standalone)')
      .addEventListener('change', notify);
  } catch (_) {}
})();
