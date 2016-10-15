$.widget('ui.toggleFontSize', {
  // default options
  options: {
    toggleFontSize: '40px' // Default the toggle font to bold if one not provided
  },

  /**
   * Set private widget varables 
   */
  _setWidgetVars: function(){
    var uiw = this;
    
    uiw._scope = 'ui.toggleFontSize'; //For debugging
    
    uiw._values = {
      baseFontSize: '', // This is the font size that the text started with.
    };
    
    uiw._elements = {
      $element : $(uiw.element)//Enter elements here for quick reference
    };
  }, //_setWidgetVars
  
  /**
   * Create function: Called the first time widget is assiocated to the object
   * Will implicitly call the _init function after
   */
  _create: function(){
    var uiw = this;

    uiw._setWidgetVars(); // Set variables
    
    var consoleGroupName = uiw._scope + '_create';
    $.console.groupCollapsed(consoleGroupName);
    $.console.log('this:', uiw);
    
    uiw._values.baseFontSize = uiw._elements.$element.css('fontSize');
    
    $.console.groupEnd(consoleGroupName);
  },//_create
  
  /**
   * Init function. This function will be called each time the widget is referenced with no parameters
   */
  _init: function(){
    var uiw = this;
    
    $.console.log(uiw._scope, '_init', uiw);
    
    //Toggle Font Size
    if (uiw._elements.$element.css('fontSize') == uiw._values.baseFontSize){
      uiw._elements.$element.css('fontSize', uiw.options.toggleFontSize);
    }
    else{
      uiw._elements.$element.css('fontSize', uiw._values.baseFontSize);
    }
  }, //_init
  
  /**
   * Returns the base font size that the  object started with
   * Need to write a specific function since it's a private variable
   */
  getBaseFontSize: function(){
    var uiw = this;
    
    $.console.log(uiw._scope, 'getBaseFontSize', uiw);    
    return uiw._values.baseFontSize;
  },//getBaseFontSize
 
  /**
   * Removes all functionality associcated with widget
   * In most cases in APEX this won't be necessary
   */
  destroy: function() {
    var uiw = this;
    $.console.log(uiw._scope, 'destroy', uiw);   
    
    //restore the font size back to its original size
    uiw._elements.$element.css('fontSize', uiw._values.baseFontSize);
    
    $.Widget.prototype.destroy.apply(uiw, arguments); // default destroy
  }//destroy
  
}); //ui.toggleFontSize