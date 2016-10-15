// Demo code for AJAX calls
var ajax = new htmldb_Get(null,$v('pFlowId'), 'APPLICATION_PROCESS=AJAX_DEMO',0);

// Value to send to PL/SQL code 
// Note: this does not "submit" P30_X (That can be done but in another way)
ajax.addParam('x01', $v('P30_X'));

// Trigger AJAX call (will send POST to APEX)
var ajaxResult = ajax.get();

// Display the result in an alert window
window.alert(ajaxResult);