/*
Copyright (c) 2019           European Spallation Source ERIC

  The program is free software: you can redistribute
  it and/or modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation, either version 2 of the
  License, or any newer version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
  more details.

  You should have received a copy of the GNU General Public License along with
  this program. If not, see https://www.gnu.org/licenses/gpl-2.0.txt

  author  : Felipe Torres González
  email   : torresfelipex1@gmail.com
  date    : 20190325
  version : 0.0.6

  Thanks to Anne Marie Muñoz who lent me all the help I needed to make this web.

  Ref: https://github.com/joewalnes/websocketd
*/

var ws = new WebSocket('ws://0.0.0.0:8080/');

ws.onopen = function() {
  // The "send" button is disabled by default. If the connection is OK, it will
  // be enabled.
  $("#SendButton").attr('disabled', false);
};

  ws.onclose = function() {
  $("#SendButton").attr('false', true);
};

ws.onerror = function(evt) {
  alert("Cannot connect to the WebSocketd (ws://0.0.0.0:8080)");
  $("#SendButton").attr('false', true);
};

ws.onmessage = function(event) {
  var message = event.data;
  var ts = new Date();
  if (message[0] == "^")
    parseMessage(message,ts);
  else
    $('#LogOutput').append("<b>Unrecognized messsage:</b>" + event.data + "\n");
};

// Function to print a message for the user
function showMessage(message,ts_raw) {
  var type = message[0].slice(1); // Remove init token
  var port = message[1].slice(1); // Remove at token
  var ts = ts_raw.getHours() + ":" + ts_raw.getMinutes() + ":"
    + ts_raw.getSeconds();
  var str  = message[2].slice(0,message[2].length-2); // Remove end token
  var style, estyle;
  // Once again, don't blame me, I'm not a web developer...
  switch (type) {
    case "inf":
      style = "<font color=\"black\"><b>";
      estyle = "</b></font>";
      break;
    case "dbg":
      style = "<font color=\"grey\">";
      estyle =  "</font>";
      break;
    case "err":
    style = "<font color=\"red\"><b>";
    estyle =  "</b></font>";
      break;
    default:
      style = "";
      estyle = "";
  }

  var out  = "[ " + ts + " ] " + style + str +" @" + port + "<br>" + estyle;

  $('#LogOutput').append(out);
}

// Function to update some of the internals of the interface
function updateProgress(message) {

}

// Function to parse the input messages from the logger
function parseMessage(message,ts) {
  var blocks = message.split("::");
  if (blocks[0] == "stat") {
    // Messages to update any progress bar or internal of the web
    updateProgress(blocks.slice(1));
  } else {
    // Messages for the user
    showMessage(blocks,ts);
  }
}

$(document).ready(function() {
// Logic to manage webui buttons +++++++++++++++++++++++++++++++++++++++++++

// General select: This button enables or disables all the column.

// Left column -- check button
$(".SelectAllL").click(function() {
  if ($(this).prop("checked") == true) {
    $(".SelectL").prop("checked", true);
  } else {
    $(".SelectL").prop("checked", false);
    $(".RadioAllL").prop("checked", false);
    $(".RadioL").prop("checked", false);
  }
});

$(".SelectL").click(function() {
  $(".SelectAllL").prop("checked", false);
});

// Left column -- radio button
$(".RadioAllL").click(function() {
  if ($(this).prop("checked") == true) {
    if($(this).attr("value") == "3U") {
      $(".RadioL[value=3U]").prop("checked", true);
    }
    else {
      $(".RadioL[value=9U]").prop("checked", true);
    }
  }
});

 // Right column -- check button
$(".SelectAllR").click(function() {
  if ($(this).prop("checked") == true) {
    $(".SelectR").prop("checked", true);
  } else {
    $(".SelectR").prop("checked", false);
    $(".RadioAllR").prop("checked", false);
    $(".RadioR").prop("checked", false);
  }
});

$(".SelectR").click(function() {
  $(".SelectAllR").prop("checked", false);
});

 // Right column -- radio button
$(".RadioAllR").click(function() {
  if ($(this).prop("checked") == true) {
    if($(this).attr("value") == "3U") {
      $(".RadioR[value=3U]").prop("checked", true);
    }
    else {
      $(".RadioR[value=9U]").prop("checked", true);
    }
  }
});

$("#AdvButton").on('click', function() {
  $("#AdvLabel").prop('hidden', !this.checked);
  $("#AdvLabel").css('visibility', 'visible');
  $(".hiddenRow").prop('hidden', !this.checked);
  $(".hiddenRow").css('visibility', 'visible');
})

 // Logic to run the Bash script in the server +++++++++++++++++++++++++++++

$("#SendButton").on('click', function() {
  if (ws) {
    // This variables will keep indexes of the selected ports in which run the
    // configuration.
    var listSelected = [];
    // NA is used to configure devices without clock configuration.
    listSelected["NA"] = "";
    listSelected["3U"] = "";
    listSelected["9U"] = "";

    // Collect data from the buttons in order to call the Bash script

    // This 2 loops will generate a list of port numbers which are selected by
    // the user.
    var it = 1;
    var bias = parseInt($("#biasLabel").val());
    $(".SelectL").each(function() {
      if($(this).prop("checked")) {
        var formFactor =
          $(".RadioL[name=clockSelectL-r"+it+"]:checked").attr("value");
        listSelected[formFactor] += it + bias + ","
      }
      it++;
    });

    // Change this to the first value of the second column of indexes
    it = 9;
    var k = 1;
    $(".SelectR").each(function() {
      if($(this).prop("checked")) {
        var formFactor =
          $(".RadioR[name=clockSelectR-r"+k+"]:checked").attr("value");
        listSelected[formFactor] += it + bias + ","
      }
      it++;
      k++;
    });

    /*
     * Let's make the commands to run in the server
     * For example: mch_config 10.0.5.55 1,2,3, 3U -s 1,2,3,4,5
     *
     * We need to see in every selected port, which clock configuration has
     * been selected.
     */
    var config3U = "";
    var config9U = "";
    var configNA = "";
    var params   = "-w -p /usr/local/share/mch_config";
    var steps = "-s "
    var customSteps = false;

    if ($("#checkDHCP").prop("checked")) {
      steps += "1,"
    }
    if ($("#AdvButton").prop("checked")) {
      if ($("#stepsLabel").val() != "") {
        steps += $("#stepsLabel").val();
        customSteps = true;
      }
    }
    else {
      steps += "2,3";
      customSteps = false;
    }

    var customCmd = $("#customCmd").prop("checked");

    if (!customCmd) {
      $("#sending3u").html(listSelected["3U"]);
      $("#sending9u").html(listSelected["9U"]);
      $("#sendingnau").html(listSelected["NA"]);

      if(listSelected["3U"] != "") {
        if (!customSteps) steps += ",4,6";
        config3U = "mch_config " + $("#ipaddr").val() + " " +
          listSelected["3U"] + " 3U " + steps + " " + params
      }

      if(listSelected["9U"] != "") {
        if (!customSteps) steps += ",4,6";
        config3U = "mch_config " + $("#ipaddr").val() + " " +
          listSelected["9U"] + " 9U " + steps + " " + params
      }

      // If step 5 is not specified, the form factor is not really taken into
      // account in the Bash script
      if(listSelected["NA"] != "") {
        config3U = "mch_config " + $("#ipaddr").val() + " " +
          listSelected["NA"] + " NA " + steps + " " + params
      }

      /*
       * We need to call the Bash script by the clock configuration file. That
       * means that we need to run one script per selected clock configuration.
       */
      try {
        if(config3U != "") {
          ws.send(config3U);
        }
        if(config9U != "") {
          ws.send(config9U);
        }
        if(configNA != "") {
        }
        } catch (ex) {
          alert("Cannot send: " + ex);
        }
      }
    else {
      try {
        ws.send($("#AdvLabel").val());
      } catch (ex) {
        alert("Cannot send: " + ex);
      }
    }
  }
});

});
