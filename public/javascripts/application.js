// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults


(function() {

  jQuery(function() {
    if ($('#user_file_data_type').val() === 'other') {
      $("#other_data_type_div").show();
    } else {
      $("#other_data_type_div").hide();
    }

    $("#user_file_data_type").change(function() {
      if ($("#user_file_data_type").val() === 'other') {
        return $("#other_data_type_div").show();
      } else {
        return $("#other_data_type_div").hide();
      }
    });
  });

}).call(this);
