var _relabsoss$elm_gmap$Native_Gmap = function() {

  var
    scheduler = _elm_lang$core$Native_Scheduler,
    gmapInitialized = false,
    maps = {},
    callbacks = [],
    geocoder = undefined,
    defaultGmapOpts = {
      center: {lat: 38, lng: 38},
      scrollwheel: false,
      zoom: 10,
      zoomControl: true
    };

  window.elmGmapInitCallback = function () {
    gmapInitialized = true;
    geocoder = new google.maps.Geocoder();
    var callback = callbacks.pop();
    while(callback) {
      callback();
      callback = callbacks.pop();
    }
  };

  function Map(opts, gmapOpts, done) {
    var self = this;
    opts = opts || {};

    self.id = _elm_lang$core$Native_Utils.guid();
    self.node = document.createElement('div');
    self.gmapInstance = undefined;
    self.bounds = undefined;
    self.circles = [];
    self.onClick = opts.onClick || undefined;
    self.onDblClick = opts.onDblClick || undefined;

    registerCallback(function () {
      initMap(self, gmapOpts, done);
    });

    self.remove = function () {
      self.gmapInstance = undefined;
      self.bounds = undefined;
      self.node.remove();
    };

    return this;
  }

  function initMap(self, gmapOpts, done) {
    self.gmapInstance =
      new google.maps.Map(
        self.node,
        gmapOpts || defaultGmapOpts
      );

    if (self.bounds)
      self.gmapInstance.fitBounds(self.bounds);

    self.gmapInstance.addListener('click', function(e) {
      e.stop();
      if (self.onClick) {
        var latLng = {lat: e.latLng.lat(), lng: e.latLng.lng()};
        _elm_lang$core$Native_Scheduler.rawSpawn(
          A2(self.onClick, self.id, latLng)
        );
      }
    });

    self.gmapInstance.addListener('dblclick', function(e) {
      e.stop();
      if (self.onDblClick) {
        var latLng = {lat: e.latLng.lat(), lng: e.latLng.lng()};
        _elm_lang$core$Native_Scheduler.rawSpawn(
          A2(self.onDblClick, self.id, latLng)
        );
      }
    });

    done(self);
  }

  function registerCallback(callback) {
    if (gmapInitialized) {
      callback();
    } else {
      callbacks.push(callback);
    }
  }

  function init(opts, gmapOpts) {
    return scheduler.nativeBinding(function(callback){
      try {
        var map = new Map(opts, gmapOpts, function (self) {
          callback(scheduler.succeed(self.id));
        });
        maps[map.id] = map;
        return function () {};
      } catch (err) {
        console.error("initialisation fails", err);
        callback(scheduler.fail({ ctor: 'InitializationFail', _0: id }));
      }
    });
  }

  function destroy(id) {
    return scheduler.nativeBinding(function(callback) {
      try {
        var map = maps[id];
        if (map) {
          map.remove();
          delete maps[id];
        }
        callback(scheduler.succeed(id));
      } catch (err) {
        console.error("destruction fails", err);
        callback(scheduler.fail({ ctor: 'DestructionFail', _0: id }));
      }
    });
  }

  function geocode(id, request) {
    return gmapHelper(id, function (map, callback) {
      geocoder.geocode(request, function(results, status) {
        if (status === 'OK') {
          callback(scheduler.succeed(results.map(function (i) {
            return {
              address_components: i.address_components,
              formatted_address: i.formatted_address,
              geometry: {
                location: {
                  lat: i.geometry.location.lat(),
                  lng: i.geometry.location.lng()
                },
                bounds: i.geometry.bounds ? i.geometry.bounds.toJSON() : undefined,
                location_type: i.geometry.location_type
              },
              place_id: i.place_id,
              types: i.types
            };
          })));
        } else {
          console.log('Geocoder failed due to: ' + status);
          callback(scheduler.fail({ ctor: 'GeocodeFail', _0: id }));
        }
      });
      return function () {};
    }, 'GeocodeFail');
  }

  function setBounds(id, bounds) {
    return gmapHelper(id, function (map, callback) {
      map.bounds = bounds;
      map.gmapInstance.fitBounds(map.bounds);
      callback(scheduler.succeed(bounds));
    }, 'SetFail');
  }

  function setCircles(id, circles) {
    return gmapHelper(id, function (map, callback) {
      var previous = map.circles.map(function (i) {
        i.setMap(null);
        return i;
      });

      map.circles = circles.map(function (i) {
        i['map'] = map.gmapInstance;
        return new google.maps.Circle(i);
      });

      callback(scheduler.succeed(circles));
    }, 'SetFail');
  }

  function gmapHelper(id, handler, error) {
    return scheduler.nativeBinding(function(callback) {
      try {
        var map = maps[id];
        if (!map) {
          callback(scheduler.fail({ ctor: 'MapNotDefined', _0: id }));
          return;
        }
        return handler(map, callback);
      } catch (err) {
        console.error(error, err);
        callback(scheduler.fail({ ctor: error, _0: id }));
      }
    });
  }

  function toHtml(model, factList) {

    function render(model) {
      var id = model.id;
      var map = maps[id];
      return map.node;
    }

    function diff() {
      return false;
    }

    var impl = {
      render: render,
      diff: diff
    };

    return _elm_lang$virtual_dom$Native_VirtualDom.custom(
      factList,
      model,
      impl
    );
  }

  return {
    init: F2(init),
    destroy: destroy,
    geocode: F2(geocode),

    setBounds: F2(setBounds),
    setCircles: F2(setCircles),

    toHtml: F2(toHtml)
  };

}();