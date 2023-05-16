(function() {
  $(document).ready(function(){
    $("button").click(function(){
      var text = $("#message").val();
      var uid = uuidv4();
      $.ajax({
        url: 'publish',
        contentType : 'application/json',
        dataType: 'json',
        data:  JSON.stringify({ "message": text, "guid": uid}),
        type: 'post',
        success: function(data) { // check if available
            $("#result").text("Result: " + data.message + " " + data.guid);  
        },
        error: function(e) { // error logging
            $("#result").text("Result: " + e.statusText);
        }
      });
    });
  });

function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
  });
};