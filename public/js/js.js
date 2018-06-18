

/*
    Websocket
________________________________*/
var ws = "";
var wsAddress = "192.168.1.20"
var pageRefresh = false;
var pageType    = $("#pageType").attr("data-type");
var userID      = $("#pageType").attr("data-userid");

$(function() {

  if (pageType == "dashboard" || pageType == "alarmNumpad") {
    if (wsAddress == "192.168.1.20") {
      alert("Please change the Websocket address in js.js");
    }
    ws = new WebSocket("ws://" + wsAddress + ":25437", ["nimha"]);
  }
  
  ws.onopen = function() {
    // Web Socket is connected, send data using send()
    notify(jQuery.parseJSON('{"error": "false", "value": "Websocket connected"}'));

    if (pageType == "dashboard") {
      ws.send('{' + cookieSidJson() + '"element": "main", "data": "connected"}');  
      ws.send('{' + cookieSidJson() + '"element": "owntracks", "action": "locations", "value": "init"}'); 
      ws.send('{' + cookieSidJson() + '"element": "osstats", "value": "refresh"}');
      ws.send('{' + cookieSidJson() + '"element": "webutils", "item": "certexpiry"}');  
      xiaomiRefreshInit()
    }
  };

  ws.onclose = function() { 
    if (pageRefresh != true) {
      console.log("Connection is closed..."); 
      $("#notification .inner").css("background", "rgba(254, 147, 147, 0.87)");
      $("#notification .inner").css("top", $('#navbar').offset().top);
      $("#notification .inner").text("Websocket closed");
      $("#notification").show(400);
      setTimeout(function(){ 
        location.reload();
      }, 5000);
    }
  };
  ws.onerror = function() { 
    if (pageRefresh != true) {
      console.log("Connection is closed..."); 
      $("#notification .inner").css("background", "rgba(254, 147, 147, 0.87)");
      $("#notification .inner").css("top", $('#navbar').offset().top);
      $("#notification .inner").text("Websocket error");
      $("#notification").show(400);
    }
  };
  
  
    
  ws.onmessage = function (response) { 
    console.log(response.data);
    var obj = jQuery.parseJSON(response.data);

    // WHY?
    if (obj.handler == "connection") {
      ws.close();
    }
    
    // When history items are received, loop through all nested elements
    if (obj.handler == "history") {
      $.each(obj.data, function(key, objnest){
        websocketHandler(objnest)
      });
    }
    else {
      websocketHandler(obj)
    }
  };

  window.onbeforeunload = function(event) {
    pageRefresh = true;
    ws.close();
  }

  /*window.setInterval(function(){
    ws.send('{\"element\": \"ping\"}');
  }, 60000);*/
  //}, 5000);
});

function websocketHandler(obj) {
  if (obj.handler == "noaction") {
    //notify(obj)
  }
  
  else if (obj.handler == "response") {
    notify(obj)

  }
  
  else if (obj.handler == "action" && pageType == "dashboard") {

    // Certificates
    if (obj.element == "certexpiry") {
      certRefresh(obj)          
    }

    // OS stats
    else if (obj.element == "osstats") {
      osstatsRefresh(obj)
    }

    // Alarm
    else if (obj.element == "alarm") {
      alarm(obj)          
    }

    // Xiaomi
    else if (obj.element == "xiaomi") {
      /*if (obj.value == "status") {
        xiaomiRefreshStatus(obj, "status");
      }
      else if (obj.value == "voltage") {
        xiaomiRefreshStatus(obj, "voltage");
      }
      else if (obj.value == "lux") {
        xiaomiRefreshStatus(obj, "lux");
      }
      else if (obj.value == "motion") {
        xiaomiRefreshStatus(obj, "motion");
      }
      else if (obj.value == "no_motion") {
        xiaomiRefreshStatus(obj, "no_motion");
      }*/
      if (obj.data['status']) {
        xiaomiRefreshStatus(obj, "status");
      }
      if (obj.data['voltage']) {
        xiaomiRefreshStatus(obj, "voltage");
      }
      if (obj.data['lux']) {
        xiaomiRefreshStatus(obj, "lux");
      }
      if (obj.value == "motion") {
        xiaomiRefreshStatus(obj, "motion");
      }
      else if (obj.value == "no_motion") {
        xiaomiRefreshStatus(obj, "no_motion");
      }
    }

    // Owntracks
    else if (obj.element == "owntracks") {
      console.log("Socket: Element == owntracks")
      if (obj.value == "init") {
        owntracksGmapInit(obj)
      }
      else if (obj.value == "refresh") {
        // Currently not different from init
        owntracksGmapInit(obj)
      }
    }

    // Websocket
    else if (obj.element == "websocket") {
      if (obj.value == "connectedusers") {
        websocketConnectedUsers(obj);
      }
    }

  }
}
function cookieSid() {
  return Cookies.get("sid");
}
function cookieSidJson() {
  return '"key": "' + Cookies.get("sid") + '", "userid": "' + userID + '",';
}


/*
    Base elements
________________________________*/
$(function() {
  $( "#sidebarToggle" ).click(function() {
    $('#sidebar').toggleClass('active');
  });
});


/*
    Notification
_______________________________*/
function notify(obj) {
  if (obj.error == "true") {
    $("#notification .inner").css("background", "rgba(254, 147, 147, 0.87)");
  }
  $("#notification .inner").css("top", $('#navbar').offset().top);
  $("#notification .inner").text(obj.value);
  $("#notification").show(400);
  setTimeout(function(){ 
    $("#notification").hide(400);
    if (obj.error == "true") {
      $("#notification .inner").css("background", "rgba(39, 203, 78, 0.87)");
    }
  }, 1700);
}


/*
    Base elements
________________________________*/
// Pushbullet
$(function() {
  $( "#pushbulletTest" ).click(function() {
    ws.send('{' + cookieSidJson() + '"element": "pushbullet", "action": "testmessage", "type": "note", "title": "Push", "body": "Me"}');  
  });

  $( ".pushbulletSend" ).click(function() {
    var pushid = $(this).attr("data-pushid");
    ws.send('{' + cookieSidJson() + '"element": "pushbullet", "action": "message", "pushid": "' + pushid + '"}');  
  });

  $( ".pushbulletApiUpdate" ).click(function() {
    var api       = $(".pushbulletApi .api.key").val();
    location.href = "/pushbullet/do?action=updateapi&api=" + api;
  });

  $( ".pushbulletTemplateAdd" ).click(function() {
    var name      = $(".pushbulletTemplatesEdit .name").val();
    var title     = $(".pushbulletTemplatesEdit .title").val();
    var body      = $(".pushbulletTemplatesEdit .body").val();
    location.href = "/pushbullet/do?action=addpush&name=" + name + "&title=" + title + "&body=" + body;
  });

  $( ".pushbulletTemplateDelete" ).click(function() {
    var pushid    = $(this).attr("data-pushid");
    location.href = "/pushbullet/do?action=deletepush&pushid=" + pushid;
  });
});


// OS stats
$(function() {
  $( "#osstatsRefresh" ).click(function() {
    ws.send('{' + cookieSidJson() + '"element": "osstats", "value": "refresh"}');  
  });
});
function osstatsRefresh(obj) {
  console.log("Updating OS stats")
  $(".osstatsInner .stats span").hide();
  $(".osstatsInner .stats .freemem").text(obj.freemem + "M");
  $(".osstatsInner .stats .usedmem").text(obj.usedmem + "M");
  $(".osstatsInner .stats .freeswap").text(obj.freeswap + "M");
  $(".osstatsInner .stats .usedswap").text(obj.usedswap + "M");
  $(".osstatsInner .stats .connections").text(obj.connections);
  $(".osstatsInner .stats .hostip").text(obj.hostip);
  $(".osstatsInner .stats span").show(200);
}


// Cert expiration
$(function() {
  $( ".certRefresh" ).click(function() {
    var server = $(this).attr("data-server");
    var port = $(this).attr("data-port");
    ws.send('{' + cookieSidJson() + '"element": "webutils", "item": "certexpiry", "server": "' + server + '", "port": "' + port + '"}');  
  });

  $( ".certAddNew" ).click(function() {
    var name = $(".certItemEdit .name").val();
    var url = $(".certItemEdit .url").val();
    var port = $(".certItemEdit .port").val();

    location.href = "/certificates/do?action=addcert&name=" + name + "&url=" + url + "&port=" + port;
  });

  $( ".certDelete" ).click(function() {
    var id = $(this).attr("data-certid");
    location.href = "/certificates/do?action=deletecert&id=" + id
  });
});
function certRefresh(obj) {
  $("." + obj.server).hide();
  $("." + obj.server).text(obj.value + " days");
  $("." + obj.server).show(200);
}


// Mail
$(function() {
  $( ".mailTestmail" ).click(function() {
    var recipient = $(".testmail.recipient").val();
    location.href = "/mail/do?action=testmail&recipient=" + recipient;
  });

  $( ".mailSettingsUpdate" ).click(function() {
    var address   = $(".mailSettingsEdit .address").val();
    var port      = $(".mailSettingsEdit .port").val();
    var from      = $(".mailSettingsEdit .from").val();
    var user      = $(".mailSettingsEdit .user").val();
    var password  = $(".mailSettingsEdit .password").val();

    location.href = "/mail/do?action=updatesettings&address=" + address + "&port=" + port + "&from=" + from + "&user=" + user + "&password=" + password;
  });

  $( ".mailTemplateAdd" ).click(function() {
    var name      = $(".mailTemplatesEdit .name").val();
    var recipient = $(".mailTemplatesEdit .recipient").val();
    var subject   = $(".mailTemplatesEdit .subject").val();
    var body      = $(".mailTemplatesEdit .body").val();
    location.href = "/mail/do?action=addmail&name=" + name + "&recipient=" + recipient + "&subject=" + subject + "&body=" + body;
  });

  $( ".mailTemplateDelete" ).click(function() {
    var mailid    = $(this).attr("data-mail");
    location.href = "/mail/do?action=deletemail&mailid=" + mailid;
  });
});


// Alarm status
$(function() {
  if (pageType == "alarmNumpad") {
    $('#alarmModel').modal('show');
  }

  $( "div.alarm .activate" ).click(function() {
    var status = $(this).attr("data-status");
    $('#alarmModel div#alarmNumpad').attr("data-status", status);
    $('#alarmModel h5.modal-title').text("Alarm (" + status + ")");
    $('#alarmModel').modal('toggle'); 
  });

  // Alarm numpad
  $( "#alarmNumpad .alarmpad" ).click(function() {
    var num = $(this).attr("data-num");
    var padd = $("#alarmNumpad .password").val();
    $("#alarmNumpad .password").val(padd + num);
  });

  // Cancel alarm submit
  $( "#alarmModel .alarmSubmitCancel" ).click(function() {
    $("#alarmNumpad .password").val("");
  });

  // Send alarmstatus + password
  $( "#alarmModel .alarmSubmit" ).click(function() {
    var status   = $('#alarmModel div#alarmNumpad').attr("data-status");
    var password = $("#alarmNumpad .password").val();

    var onlyCode = "false"
    if ($("div#alarmNumpad").attr("data-onlycode") == "true") {
      onlyCode = "true";
    }

    if (onlyCode == "true") {
      status = $("div#alarmNumpad .onlyCode option:selected").val();
    }
     
    ws.send('{' + cookieSidJson() + '"element": "alarm", "action": "activate", "status": "' + status + '", "password": "' + password + '"}'); 
    
    $('#alarmModel').modal('toggle');
    $("#alarmNumpad .password").val("");

    if (onlyCode == "false") {
      $('#alarmModel').modal('toggle');
    }
  });

  $( "div#alarm .alarmActions .alarmActionAdd" ).click(function() {
    var alarmstate = $(".alarmItemAdd .alarmstate").val();
    var alarmid = $(".alarmItemAdd .alarmaction").val();
    var alarmelement = $(".alarmItemAdd .alarmaction option:selected").attr("data-element");

    location.href = "/alarm/do?action=addaction&alarmstate=" + alarmstate + "&alarmid=" + alarmid + "&alarmelement=" + alarmelement;
  });

  $( "div#alarm .alarmActions .alarmDeleteAction" ).click(function() {
    var actionid = $(this).attr("data-actionid");

    location.href = "/alarm/do?action=deleteaction&actionid=" + actionid;
  });

  $( "div#alarm .alarmPasswords .alarmDeletePassword" ).click(function() {
    var userid = $(this).attr("data-userid");

    location.href = "/alarm/do?action=deleteuser&userid=" + userid;
  });

  $( "div#alarm .alarmDetails .alarmArmtimeUpdate" ).click(function() {
    var armtime = $(".alarmDetails .alarmArmtime").val();

    location.href = "/alarm/do?action=updatecarmtime&armtime=" + armtime;
  });

  $( "div#alarm .alarmDetails .alarmCountdownUpdate" ).click(function() {
    var countdown = $(".alarmDetails .alarmCountdown").val();

    location.href = "/alarm/do?action=updatecountdown&countdown=" + countdown;
  });
});
function alarm(obj) {
  if (obj.action == "setstatus") {
    alarmSetStatus(obj)
  }
}
function alarmSetStatus(obj) {
  if (obj.value == "ringing") {
    $("body").css("background", "red");
  } else {
    $("body").css("background", "whitesmoke");
  }

  $(".alarm span.status").removeClass("badge-success");
  $(".alarm span.status").removeClass("badge-danger");
  $(".alarm span.status").addClass("badge-secondary");
  $(".alarm span.status").text("False");
  $(".alarm ." + obj.value + " span.status").removeClass("badge-secondary");
  if (obj.value == "disarmed") {
    $(".alarm ." + obj.value + " span.status").addClass("badge-success");
  } else {
    $(".alarm ." + obj.value + " span.status").addClass("badge-danger");
  }
  $(".alarm ." + obj.value + " span.status").text("True");

  $(".alarm span.activate").show(200);
  $(".alarm ." + obj.value + " span.activate").hide(200);
}



// Xiaomi read & discover
$(function() {
  $( ".xiaomiRefresh" ).click(function() {
    var sid = $(this).attr("data-sid");
    var action = $(this).attr("data-action");
    var value = $(this).attr("data-value");
    ws.send('{' + cookieSidJson() + '"element": "xiaomi", "action": "' + action + '", "sid": "' + sid + '", "value": "' + value + '"}');  
  });

  // Xiaomi settings page. Discover available devices
  $( ".xiaomiDiscoverDevices" ).click(function() {
    ws.send('{' + cookieSidJson() + '"element": "xiaomi", "action": "discover"}');  
    location.reload();
  });
});
function xiaomiRefreshInit() {
  var sids = new Array();

  var time = 200;

  $(".xiaomiInner>.device").each(function(){
    var sid = $(this).find(".xiaomiRefresh").attr("data-sid");

    if(jQuery.inArray(sid, sids) == -1) {
      sids.push(sid);
      var action = $(this).find(".xiaomiRefresh").attr("data-action");
      var value = $(this).find(".xiaomiRefresh").attr("data-value");
      //ws.send('{' + cookieSidJson() + '"element": "xiaomi", "action": "' + action + '", "sid": "' + sid + '", "value": "' + value + '"}');

      setTimeout( function(){ 
        ws.send('{' + cookieSidJson() + '"element": "xiaomi", "action": "' + action + '", "sid": "' + sid + '", "value": "' + value + '"}')
      }, time);
      time += 200;
    }
  });
}
function xiaomiRefreshStatus(obj, value) {
  
  // Hide object
  $("." + obj.sid + ".device." + obj.value + " div.value").hide();
  
  // Assign new value
  if (value == "status") {
    console.log("Xiaomi - Sid: " + obj.sid + " - Value: " + obj.data.status);
    $("." + obj.sid + ".device.status .value").text(obj.data.status);
  }
  else if (value == "voltage") {
    console.log("Xiaomi - Sid: " + obj.sid + " - Value: " + obj.data.voltage);
    $("." + obj.sid + ".device.voltage .value").text(obj.data.voltage + " volt");
  }
  else if (value == "lux") {
    console.log("Xiaomi - Sid: " + obj.sid + " - Value: " + obj.data.lux);
    $("." + obj.sid + ".device.lux .value").text(obj.data.lux + " lux");
  }
  else if (value == "motion") {
    console.log("Xiaomi - Sid: " + obj.sid + " - Value: " + obj.data.status);
    $("." + obj.sid + ".device.motion .value").text(obj.data.status);
  }
  else if (value == "no_motion") {
    console.log("Xiaomi - Sid: " + obj.sid + " - Value: " + obj.data.no_motion);
    $("." + obj.sid + ".device.motion .value").text(obj.data.no_motion + " sec");
  }

  // Show object
  $("." + obj.sid + ".device." + obj.value + " div.value").show(200);
}

// Xiaomi devices
$(function() {
  // Add sensor
  $( ".xiaomiAddSensor" ).click(function() {
    var sid = $(".xiaomiNewSensor .xiaomiActionSid option:selected").val();
    var valuename = $(".xiaomiNewSensor .valuename").val();
    var valuedata = $(".xiaomiNewSensor .valuedata").val();
    var handling = $(".xiaomiNewSensor .handling").val();
    var triggeralarm = $(".xiaomiNewSensor .triggeralarm").val();

    location.href = "/xiaomi/devices/do?action=addsensor&sid=" + sid + "&valuename=" + valuename + "&valuedata=" + valuedata + "&handling=" + handling + "&triggeralarm=" + triggeralarm;
  });

  // Delete sensor
  $( ".xiaomiDeleteSensor" ).click(function() {
    var id = $(this).attr("data-xdid");
    location.href = "/xiaomi/devices/do?action=deletesensor&id=" + id
  });

  // Add action
  $( ".xiaomiAddAction" ).click(function() {
    var sid = $(".xiaomiNewAction .xiaomiActionSid option:selected").val();
    var valuename = $(".xiaomiNewAction .valuename").val();
    var valuedata = $(".xiaomiNewAction .valuedata").val();
    var name = $(".xiaomiNewAction .name").val();

    location.href = "/xiaomi/devices/do?action=addaction&sid=" + sid + "&name=" + name + "&valuename=" + valuename + "&valuedata=" + valuedata;
  });

  // Delete action
  $( ".xiaomiDeleteAction" ).click(function() {
    var id = $(this).attr("data-xdid");
    location.href = "/xiaomi/devices/do?action=deleteaction&id=" + id
  });

  // Update device name
  $( ".xiaomiUpdateDevice" ).click(function() {
    var sid = $(".xiaomiDeviceEdit .xiaomiDeviceSid option:selected").val();
    var name = $(".xiaomiDeviceEdit input.name").val();
    location.href = "/xiaomi/devices/do?action=updatedevice&sid=" + sid + "&name=" + name;
  });

  // Update gateway key
  $( ".xiaomiUpdateKey" ).click(function() {
    var sid = $(this).attr("data-sid");
    var key = $(this).parent("div").children("input").val();
    location.href = "/xiaomi/devices/do?action=updatekey&key=" + key + "&sid=" + sid;
  });
});



// Websocket
function websocketConnectedUsers(obj) {
  console.log("Updating websocket users")
  
  var clo = "";
  var newClo = "";
  $(".wsusersInner").empty();
  $.each(obj.users, function(key, user){
    console.log("<b>Host:</b> " + user.hostname + " - " + "<b>Last:</b> " + user.lastMessage);
    var clo = "";
    var newClo = "";
    clo = $(".wsusers .clone").clone();
    clo.removeClass("clone");
    newClo = clo;

    newClo.html("<label><span>Host:</span> " + user.hostname + "</label><label>" + "<span>Last:</span> " + user.lastMessage + "</label>");

    newClo.show(200).appendTo(".wsusersInner");
  });

}


/*
    Google map
________________________________*/
$(function() {
  $( ".owntracksRefresh" ).click(function() {
    ws.send('{' + cookieSidJson() + '"element": "owntracks", "action": "refreshlocations", "value": "refresh"}');  
  }); 

  $( ".owntracksDeleteDevice" ).click(function() {
    var username = $(this).attr("data-username");
    location.href = "/owntracks/do?action=deletedevice&username=" + username;
  });

  $( ".owntracksDeleteWaypoint" ).click(function() {
    var waypointid = $(this).attr("data-waypointid");
    location.href = "/owntracks/do?action=deletewaypoint&waypointid=" + waypointid;
  });
});
var map;

function owntracksGmapInit(obj) {

  // Create array with locations
  var locations = new Array();
  $.each(obj.devices, function(key, device){
    var theResults = new Array();
    theResults[0] = device.device;
    theResults[1] = device.lat;
    theResults[2] = device.lon;
    theResults[3] = device.date;
    locations.push(theResults);
  });

  // Create array with waypoints
  var waypoints = new Array();
  $.each(obj.waypoints, function(key, waypoint){
    var theResults = new Array();
    theResults[0] = waypoint.desc;
    theResults[1] = waypoint.lat;
    theResults[2] = waypoint.lon;
    theResults[3] = waypoint.rad;
    theResults[4] = waypoint.date;
    waypoints.push(theResults);
  });

  console.log(locations);
  console.log(waypoints);

  // Check home location
  var homeLat = obj.home.lat;
  var homeLon = obj.home.lon;
  var zoom = 10;
  if (homeLat == "" || homeLon == "") {
    homeLat = "55.629562"
    homeLon = "12.6331927"
    zoom = zoom;
  }

  // Init map
  map = new google.maps.Map(document.getElementById('map'), {
    zoom: zoom,
    center: new google.maps.LatLng(homeLat, homeLon),
    mapTypeId: google.maps.MapTypeId.ROADMAP
  });

  // Vars
  var infowindow = new google.maps.InfoWindow();
  var marker, i;

  // Add markers for waypoints
  for (i = 0; i < waypoints.length; i++) {
    marker = new google.maps.Marker({
      position: new google.maps.LatLng(waypoints[i][1], waypoints[i][2]),
      label: waypoints[i][0],
      map: map,
      icon: 'http://maps.google.com/mapfiles/ms/icons/green-dot.png'
    });

    // Create waypoint
    var circle = new google.maps.Circle({
      map: map,
      radius: parseFloat(waypoints[i][3]),    //16093m 10 miles in metres
      fillColor: '#1c79ddfa'
    });
    circle.bindTo('center', marker, 'position');
    
    // Add event listener. Click on cirle to get waypoint name.
    google.maps.event.addListener(marker, 'click', (function(marker, i) {
      return function() {
        infowindow.setContent(waypoints[i][0] + " (" + waypoints[i][3] + ")");
        infowindow.open(map, marker);
      }
    })(marker, i));
  }

  // Add markers for locations
  for (i = 0; i < locations.length; i++) {
    marker = new google.maps.Marker({
      position: new google.maps.LatLng(locations[i][1], locations[i][2]),
      label: locations[i][0],
      map: map,
      zIndex: google.maps.Marker.MAX_ZINDEX + 1
    });

    // Add event listener. Click on marker to get last date.
    google.maps.event.addListener(marker, 'click', (function(marker, i) {
      return function() {
        infowindow.setContent("Last: " + locations[i][3]);
        infowindow.open(map, marker);
      }
    })(marker, i));
  }
}

