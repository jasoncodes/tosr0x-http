parseResponse = function(xhr) {
  if (xhr.getResponseHeader('Content-Type').match(/^application\/json(?:;|$)/)) {
    return JSON.parse(xhr.responseText);
  }
};

formatTemperature = function(temperature) {
  if (temperature) {
    return temperature.toFixed(1) + 'ºC';
  }
}

displayStatus = function(status) {
  if (status) {
    document.querySelector('.temperature').textContent = formatTemperature(status.temperature);
    if (status.states) {
      for (var relay in status.states) {
        var node = document.querySelector('.relays > [data-number='+JSON.stringify(relay)+']');
        var state = status.states[relay];
        node.classList.toggle('state-true', state);
        node.classList.toggle('state-false', !state);
      }
    }
  } else {
    document.querySelector('.temperature').textContent = 'error';
    var nodes = document.querySelectorAll('.relays > [data-number]');
    for (var i = 0; i < nodes.length; ++i) {
      nodes[i].classList.remove('state-true');
      nodes[i].classList.remove('state-false');
    }
  }
}

refreshStatus = function() {
  var xhr = new XMLHttpRequest();
  xhr.open('GET', '/status');
  xhr.addEventListener('load', function() {
    if (xhr.status == 200) {
      displayStatus(parseResponse(xhr));
    } else {
      displayStatus();
    }
  })
  xhr.addEventListener('error', function() {
    displayStatus();
  });
  xhr.send();
};

refreshStatus();
setInterval(refreshStatus, 1000);

document.addEventListener('DOMContentLoaded', function() {
  document.querySelector('.relays').addEventListener('click', function(event) {
    event.preventDefault()
    var relay = event.target.dataset.number;
    if (relay) {
      var currentState = event.target.classList.contains('state-true');
      var newState = !currentState

      event.target.classList.toggle('state-true', newState);
      event.target.classList.toggle('state-false', !newState);

      var newStates = {}
      newStates[relay] = newState;

      var xhr = new XMLHttpRequest()
      xhr.open('POST', '/update')
      xhr.setRequestHeader('Content-Type', 'application/json')
      xhr.addEventListener('load', function() {
        if (xhr.status >= 400) {
          alert('error toggling relay');
        }
        refreshStatus();
      });
      xhr.addEventListener('error', function() {
        alert('error toggling relay');
      });
      xhr.send(JSON.stringify(newStates))
    }
  });
});
