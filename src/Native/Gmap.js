var _relabsoss$elm_gmap$Native_Gmap = function() {

  var
    scheduler = _elm_lang$core$Native_Scheduler,
    gmapInitialized = false,
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
      if (self.node)
        self.node.remove();
      self.node = undefined;
      self.onClick = undefined;
      self.onDblClick = undefined;
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
          A2(self.onClick, self, latLng)
        );
      }
    });

    self.gmapInstance.addListener('dblclick', function(e) {
      e.stop();
      if (self.onDblClick) {
        var latLng = {lat: e.latLng.lat(), lng: e.latLng.lng()};
        _elm_lang$core$Native_Scheduler.rawSpawn(
          A2(self.onDblClick, self, latLng)
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
        new Map(opts, gmapOpts, function (self) {
          callback(scheduler.succeed(self));
        });
        return function () {};
      } catch (err) {
        console.error("initialisation fails", err);
        callback(scheduler.fail({ ctor: 'InitializationFail' }));
      }
    });
  }

  function destroy(map) {
    return scheduler.nativeBinding(function(callback) {
      try {
        map.remove();
        callback(scheduler.succeed());
      } catch (err) {
        console.error("destruction fails", err);
        callback(scheduler.fail({ ctor: 'DestructionFail' }));
      }
    });
  }

  function id(map) {
    return map.id;
  }

  function geocode(map, request) {
    return gmapHelper(map, function (map, callback) {
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
          callback(scheduler.fail({ ctor: 'GeocodeFail' }));
        }
      });
      return function () {};
    }, 'GeocodeFail');
  }

  function setBounds(map, bounds) {
    return gmapHelper(map, function (map, callback) {
      map.bounds = bounds;
      map.gmapInstance.fitBounds(map.bounds);
      callback(scheduler.succeed(bounds));
    }, 'SetFail');
  }

  function setCircles(map, circles) {
    return gmapHelper(map, function (map, callback) {
      map.circles.map(function (i) {
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

  function gmapHelper(map, handler, error) {
    return scheduler.nativeBinding(function(callback) {
      try {
        return handler(map, callback);
      } catch (err) {
        console.error(error, err);
        callback(scheduler.fail({ ctor: error }));
      }
    });
  }

  function toHtml(map, factList) {

    function render(map) {
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
      map,
      impl
    );
  }

  return {
    init: F2(init),
    destroy: destroy,
    id: id,
    geocode: F2(geocode),

    setBounds: F2(setBounds),
    setCircles: F2(setCircles),

    toHtml: F2(toHtml)
  };

}();