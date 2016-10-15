(function($){

$.clarifitRssReader = (function(){
  var that = {};
  
  /**
   * Display the RSS feed's content in a Dialog window
   */
  that.showContentModal = function(pRssId, pObj){
    var scope = '$.clarifitRssReader.showContentModal';
    $.console.groupCollapsed(scope);
    $.console.logParams();
    
    var $elem = $('#' + pObj.divId);
    
    //Ensure default options
    var defaultOptions = {
      dialogWidth: 700,
      dialogHeight: 400,
      modal: true
      };
      
    pObj = $.extend(defaultOptions, pObj);
    
    //Display Loading Message
    $elem.html('<div style="text-align:center;"><img src="' + pObj.imagePrefix + 'ws/ajax-loader.gif" style="display: block;margin-left: auto;margin-right: auto"></div>');
    $elem.dialog({
      title: 'Loading...',
      modal: pObj.modal
    });
    
    //Prep AJAX call to get HTML content
    var ajax = new htmldb_Get(null,$v('pFlowId'), 'PLUGIN=' + pObj.ajaxIdentifier,0);
    ajax.addParam('x01', pObj.rssType);
    ajax.addParam('x02', pRssId);
    var ajaxResult = ajax.get();
  
    var json = $.parseJSON(ajaxResult);
    $.console.log('json: ', json);

    if (json.errorMsg == ''){
      //No Error message, display content
      //Modify content to include some additional information about the rss post
      json.content = '<span class="clarifitRssReader-label">By</span>:<span class="clarifitRssReader-author">' + json.author + '</span><br>' + '<span class="clarifitRssReader-label">Link</span>: ' + '<a href="' + json.link + '" target="blank" class="clarifitRssReader-link">' + json.link + '</a><br><br>' + json.content;
      
      //Display in Modal window
      $elem.dialog('close'); //close Loading messsage
      $elem.html(json.content);
      $elem.dialog({
        title: json.title,
        width:  pObj.dialogWidth,
        height: pObj.dialogHeight,
        modal: pObj.modal
      });
      $.console.groupEnd(scope);
    }
    else {
      //Error occured
      $elem.dialog('close'); //close Loading messsage
      $elem.html('An error occured loading RSS feed');
      $elem.dialog({
        title: 'Error',
        width:  pObj.dialogWidth,
        height: pObj.dialogHeight,
        modal: pObj.modal
      });
    }//error message
    
  };//showContentModal

  return that;
})();//$clarifitRssReader

})(apex.jQuery);