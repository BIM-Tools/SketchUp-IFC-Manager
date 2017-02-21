/*******************************************************************************
 *
 * class UI.Autolist
 *
 ******************************************************************************/


Autolist.prototype = new Control();
Autolist.prototype.constructor = Autolist;

function Autolist( jquery_element ) {
  Control.call( this, jquery_element );
}

UI.Autolist = Autolist;

Autolist.add = function( properties ) {
  // Build DOM objects.
  // (i) <SELECT> element needs to be wrapped to ensure consistent sizing.
  var $control = $('<div/>');
  $control.addClass('control control-autolist');
  if ( properties.multiline ) {
    var $autolist = $('<textarea/>');
  } else if ( properties.password ) {
    var $autolist = $('<input type="password" />');
  } else {
    var $autolist = $('<input type="text" />');
  }
  $autolist.attr('id', properties.ui_id + '_ui');
  $autolist.addClass('focus-target');
  $autolist.appendTo( $control );
  // Initialize wrapper.
  var control = new Autolist( $control );
  control.update( properties );
  // Set up events.
  UI.add_event( 'change', $control, $autolist );
  UI.add_event( 'keydown', $control, $autolist );
  UI.add_event( 'keypress', $control, $autolist );
  UI.add_event( 'keyup', $control, $autolist );
  UI.add_event( 'focus', $control, $autolist );
  UI.add_event( 'blur', $control, $autolist );
  UI.add_event( 'copy', $control, $autolist );
  UI.add_event( 'cut', $control, $autolist );
  UI.add_event( 'paste', $control, $autolist );
  UI.add_event( 'textchange', $control, $autolist );
  // Attach to document.
  control.attach();
  return control;
}

Autolist.prototype.set_value = function( value ) {
  $autolist = this.control.children('input,textarea');
  $autolist.val( value );
  return value;
};

Autolist.prototype.set_readonly = function( value ) {
  $autolist = this.control.children('input,textarea');
  $autolist.prop( 'readonly', value );
  return value;
};

Autolist.prototype.set_items = function( value ) {
  $autolist = this.control.children('input');
  $autolist.autocomplete( {minLength:0, autoFocus: true, source: value} );
  return value;
};

Autolist.update_items = function( ui_id, value ) {
  $control = $('#' + ui_id);
  $autolist = $control.children('input');
  $( '#' + ui_id + '_ui' ).autocomplete( {minLength:0, autoFocus: true, source: value});
  return value;
};

