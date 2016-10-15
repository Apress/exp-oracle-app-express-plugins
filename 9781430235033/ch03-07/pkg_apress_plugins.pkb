CREATE OR REPLACE PACKAGE BODY pkg_apress_plugins as

  FUNCTION f_render_from_to_datepicker (
    p_item                IN apex_plugin.t_page_item,
    p_plugin              IN apex_plugin.t_plugin,
    p_value               IN VARCHAR2,
    p_is_readonly         IN BOOLEAN,
    p_is_printer_friendly IN BOOLEAN )
    RETURN apex_plugin.t_page_item_render_result 
    
  AS  
    -- APEX information
    v_app_id apex_applications.application_id%TYPE := v('APP_ID');
    v_page_id apex_application_pages.page_id%TYPE := v('APP_PAGE_ID');
    
    -- Main plug-in variables
    v_result apex_plugin.t_page_item_render_result; -- Result object to be returned
    v_page_item_name VARCHAR2(100);  -- Item name (different than ID)
    v_html VARCHAR2(4000); -- Used for temp HTML 
    
    -- Application Plugin Attributes
    v_button_img apex_appl_plugins.attribute_01%type := p_plugin.attribute_01; 
    
    -- Item Plugin Attributes
    v_show_on apex_application_page_items.attribute_01%type := lower(p_item.attribute_01); -- When to show date picker. Options: focus, button, both
    v_date_picker_type apex_application_page_items.attribute_01%type := lower(p_item.attribute_02); -- from or to
    v_other_item apex_application_page_items.attribute_01%type := upper(p_item.attribute_03); -- Name of other date picker item
    
    -- Other variables
    -- Oracle date formats differen from JS date formats
    v_orcl_date_format_mask p_item.format_mask%type; -- Oracle date format: http://www.techonthenet.com/oracle/functions/to_date.php
    v_js_date_format_mask p_item.format_mask%type; -- JS date format: http://docs.jquery.com/UI/Datepicker/formatDate
    v_other_js_date_format_mask apex_application_page_items.format_mask%type; -- This is the other datepicker's JS date format. Required since it may not contain the same format mask as this date picker
    
  BEGIN
    -- Debug information (if app is being run in debug mode)
    IF apex_application.g_debug THEN
      apex_plugin_util.debug_page_item (p_plugin                => p_plugin,
                                        p_page_item             => p_item,
                                        p_value                 => p_value,
                                        p_is_readonly           => p_is_readonly,
                                        p_is_printer_friendly   => p_is_printer_friendly);
    END IF;
    
    -- handle read only and printer friendly
    IF p_is_readonly OR p_is_printer_friendly THEN
      -- omit hidden field if necessary
      apex_plugin_util.print_hidden_if_readonly (p_item_name             => p_item.name,
                                                 p_value                 => p_value,
                                                 p_is_readonly           => p_is_readonly,
                                                 p_is_printer_friendly   => p_is_printer_friendly);
      -- omit display span with the value
      apex_plugin_util.print_display_only (p_item_name          => p_item.NAME,
                                           p_display_value      => p_value,
                                           p_show_line_breaks   => FALSE,
                                           p_escape             => TRUE, -- this is recommended to help prevent XSS
                                           p_attributes         => p_item.element_attributes);
    ELSE
      -- Not read only
      -- Get name. Used in the "name" form element attribute which is different than the "id" attribute 
      v_page_item_name := apex_plugin.get_input_name_for_page_item (p_is_multi_value => FALSE);
      
      -- SET VALUES

      -- If no format mask is defined use the system level date format
      v_orcl_date_format_mask := nvl(p_item.format_mask, sys_context('userenv','nls_date_format'));

      -- Convert the Oracle date format to JS format mask
      v_js_date_format_mask := wwv_flow_utilities.get_javascript_date_format(p_format => v_orcl_date_format_mask);

      -- Get the corresponding date picker's format mask
      select wwv_flow_utilities.get_javascript_date_format(p_format => nvl(max(format_mask), sys_context('userenv','nls_date_format')))
      into v_other_js_date_format_mask
      from apex_application_page_items
      where application_id = v_app_id
        and page_id = v_page_id
        and item_name = upper(v_other_item);
      
      -- OUTPUT

      -- Print input element
      v_html := '<input type="text" id="%ID%" name="%NAME%" value="%VALUE%" autocomplete="off">';
      v_html := REPLACE(v_html, '%ID%', p_item.name);
      v_html := REPLACE(v_html, '%NAME%', v_page_item_name);
      v_html := REPLACE(v_html, '%VALUE%', p_value);
      
      sys.htp.p(v_html);

      -- JAVASCRIPT

      -- Load javascript Libraries
      apex_javascript.add_library (p_name => '$console_wrapper', p_directory => p_plugin.file_prefix, p_version=> '_1.0.3'); -- Load Console Wrapper for debugging
      apex_javascript.add_library (p_name => 'jquery.ui.clarifitFromToDatePicker', p_directory => p_plugin.file_prefix, p_version=> '_1.0.0'); -- Version for the date picker (in file name)
      
      -- Initialize the fromToDatePicker
      v_html := 
      '$("#%NAME%").clarifitFromToDatePicker({
        correspondingDatePicker: {
          %OTHER_DATE_FORMAT%
          %ID%
          %VALUE_END_ELEMENT%
        },
        datePickerAttrs: {
          %BUTTON_IMAGE%
          %DATE_FORMAT%
          %SHOW_ON_END_ELEMENT%
        },
        %DATE_PICKER_TYPE_END_ELEMENT%
      });';
      v_html := replace(v_html, '%NAME%', p_item.name);
      v_html := REPLACE(v_html, '%OTHER_DATE_FORMAT%', apex_javascript.add_attribute('dateFormat',  sys.htf.escape_sc(v_other_js_date_format_mask)));
      v_html := REPLACE(v_html, '%DATE_FORMAT%', apex_javascript.add_attribute('dateFormat',  sys.htf.escape_sc(v_js_date_format_mask)));
      v_html := replace(v_html, '%ID%', apex_javascript.add_attribute('id', v_other_item));
      v_html := replace(v_html, '%VALUE_END_ELEMENT%', apex_javascript.add_attribute('value',  sys.htf.escape_sc(v(v_other_item)), false, false));
      v_html := replace(v_html, '%BUTTON_IMAGE%', apex_javascript.add_attribute('buttonImage',  sys.htf.escape_sc(v_button_img)) );
      v_html := replace(v_html, '%SHOW_ON_END_ELEMENT%', apex_javascript.add_attribute('showOn',  sys.htf.escape_sc(v_show_on), false, false));
      v_html := replace(v_html, '%DATE_PICKER_TYPE_END_ELEMENT%', apex_javascript.add_attribute('datePickerType',  sys.htf.escape_sc(v_date_picker_type), false, false));
      
      apex_javascript.add_onload_code (p_code => v_html);
      
      -- Tell apex that this field is navigable
      v_result.is_navigable := FALSE;

    END IF; -- f_render_from_to_datepicker
    
    RETURN v_result;
  END f_render_from_to_datepicker;
  
  FUNCTION f_validate_from_to_datepicker (
    p_item   IN apex_plugin.t_page_item,
    p_plugin IN apex_plugin.t_plugin,
    p_value  IN VARCHAR2 )
    RETURN apex_plugin.t_page_item_validation_result
  AS
    -- Variables
    v_orcl_date_format apex_application_page_items.format_mask%type; -- oracle date format
    v_date date;
    
    -- Other attributes
    v_other_orcl_date_format apex_application_page_items.format_mask%type;
    v_other_date date;
    v_other_label apex_application_page_items.label%type;
    v_other_item_val varchar2(255);

   -- APEX information
    v_app_id apex_applications.application_id%type := v('APP_ID');
    v_page_id apex_application_pages.page_id%type := v('APP_PAGE_ID');

    -- Item Plugin Attributes
    v_date_picker_type apex_application_page_items.attribute_01%type := lower(p_item.attribute_02); -- from/to
    v_other_item apex_application_page_items.attribute_01%type := upper(p_item.attribute_03); -- item name of other date picker
    
    -- Return 
    v_result apex_plugin.t_page_item_validation_result;

  BEGIN
  
    -- Debug information (if app is being run in debug mode)
    IF apex_application.g_debug THEN
      apex_plugin_util.debug_page_item (p_plugin                => p_plugin,
                                        p_page_item             => p_item,
                                        p_value                 => p_value,
                                        p_is_readonly           => FALSE,
                                        p_is_printer_friendly   => FALSE);
    END IF;
    
    -- If no value then nothing to validate
    IF p_value IS NULL THEN
      RETURN v_result;
    END IF;
    
    -- Check that it's a valid date
    SELECT nvl(MAX(format_mask), sys_context('userenv','nls_date_format'))
      INTO v_orcl_date_format
      FROM apex_application_page_items
      WHERE item_id = p_item.ID;
    
    IF NOT wwv_flow_utilities.is_date (p_date => p_value, p_format => v_orcl_date_format) THEN
      v_result.message := '#LABEL# Invalid date';
      RETURN v_result;
    ELSE
      v_date := to_date(p_value, v_orcl_date_format);
    END IF;

    -- Check that from/to date have valid date range
    -- Only do this for From dates
    
    -- At this point the date exists and is valid. 
    -- Only check for "from" dates so error message appears once
    IF v_date_picker_type = 'from' THEN
    
      IF LENGTH(v(v_other_item)) > 0 THEN
        SELECT nvl(MAX(format_mask), sys_context('userenv','nls_date_format')), MAX(label)
          INTO v_other_orcl_date_format, v_other_label
          FROM apex_application_page_items
         WHERE application_id = v_app_id
           AND page_id = v_page_id
           AND item_name = upper(v_other_item);
        
        v_other_item_val := v(v_other_item);
        
        IF wwv_flow_utilities.is_date (p_date => v_other_item_val, p_format => v_other_orcl_date_format) THEN
          v_other_date := to_date(v_other_item_val, v_other_orcl_date_format);
        END IF;
        
      END IF;
      
      -- If other date is not valid or does not exist then no stop validation.
      IF v_other_date IS NULL THEN
        RETURN v_result;
      END IF;
        
      -- Can now compare min/max range. 
      -- Remember "this" date is the from date. "other" date is the to date
      IF v_date > v_other_date THEN
        v_result.message := '#LABEL# must be less than or equal to ' || v_other_label;
        v_result.display_location := apex_plugin.c_inline_in_notifiction; -- Force to display inline only
        RETURN v_result;
      END IF;

    END IF; -- v_date_picker_type = from

    -- No errors
    RETURN v_result;
    
  END f_validate_from_to_datepicker;
  
  FUNCTION f_render_dialog (
    p_dynamic_action IN apex_plugin.t_dynamic_action,
    p_plugin         IN apex_plugin.t_plugin )
    RETURN apex_plugin.t_dynamic_action_render_result
  AS
    -- Application Plugin Attributes
    v_background_color apex_appl_plugins.attribute_01%TYPE := p_plugin.attribute_01; 
    v_background_opacitiy apex_appl_plugins.attribute_01%TYPE := p_plugin.attribute_02; 
 
    -- DA Plugin Attributes
    v_modal apex_application_page_items.attribute_01%TYPE := p_dynamic_action.attribute_01; -- y/n
    v_close_on_esc apex_application_page_items.attribute_01%TYPE := p_dynamic_action.attribute_02; -- y/n
    v_title apex_application_page_items.attribute_01%TYPE := p_dynamic_action.attribute_03; -- text
    v_hide_on_load apex_application_page_items.attribute_01%TYPE := upper(p_dynamic_action.attribute_04); -- y/n
    v_on_close_visible_state apex_application_page_items.attribute_01%type := lower(p_dynamic_action.attribute_05); -- prev, show, hide
        
    -- Return 
    v_result apex_plugin.t_dynamic_action_render_result;
    
    -- Other variables
    v_html varchar2(4000);
    v_affected_elements apex_application_page_da_acts.affected_elements%type;
    v_affected_elements_type apex_application_page_da_acts.affected_elements_type%type;
    v_affected_region_id apex_application_page_da_acts.affected_region_id%type;
    v_affected_region_static_id apex_application_page_regions.static_id%type;
    
    -- Convert Y/N to True/False (text)
    -- Default to true
    FUNCTION f_yn_to_true_false_str(p_val IN VARCHAR2)
    RETURN VARCHAR2
    AS
    BEGIN
      RETURN
        CASE 
          WHEN p_val IS NULL OR lower(p_val) != 'n' THEN 'true'
          ELSE 'false'
        END;
    END f_yn_to_true_false_str;

  BEGIN
    -- Debug information (if app is being run in debug mode)
    IF apex_application.g_debug THEN
      apex_plugin_util.debug_dynamic_action (
        p_plugin => p_plugin,
        p_dynamic_action => p_dynamic_action);
    END IF;
    
    -- Cleaup values
    v_modal := f_yn_to_true_false_str(p_val => v_modal);
    v_close_on_esc := f_yn_to_true_false_str(p_val => v_close_on_esc);

    -- If Background color is not null set the CSS
    -- This will only be done once per page
    IF v_background_color IS NOT NULL THEN
      v_html := q'!
        .ui-widget-overlay{
          background-image: none ;
          background-color: %BG_COLOR%;
          opacity: %OPACITY%;
        }!';
      
      v_html := REPLACE(v_html, '%BG_COLOR%', v_background_color);
      v_html := REPLACE(v_html, '%OPACITY%', v_background_opacitiy);

      apex_css.ADD (
        p_css => v_html,
        p_key => 'ui.clarifitdialog.background');
    END IF;
    
    -- JAVASCRIPT

    -- Load javascript Libraries
    apex_javascript.add_library (p_name => '$console_wrapper', p_directory => p_plugin.file_prefix, p_version=> '_1.0.3'); -- Load Console Wrapper for debugging
    apex_javascript.add_library (p_name => 'jquery.ui.clarifitDialog', p_directory => p_plugin.file_prefix, p_version=> '_1.0.0'); 
    
    -- Hide Affected Elements on Load
    IF v_hide_on_load = 'Y' THEN
    
      v_html := '';
      
      SELECT affected_elements, lower(affected_elements_type), affected_region_id, aapr.static_id
      INTO v_affected_elements, v_affected_elements_type, v_affected_region_id, v_affected_region_static_id
      FROM apex_application_page_da_acts aapda, apex_application_page_regions aapr
      WHERE aapda.action_id = p_dynamic_action.ID
        AND aapda.affected_region_id = aapr.region_id(+);
      
      IF v_affected_elements_type = 'jquery selector' THEN
        v_html := 'apex.jQuery("' || v_affected_elements || '").hide();';
      ELSIF v_affected_elements_type = 'dom object' THEN      
        v_html := 'apex.jQuery("#' || v_affected_elements || '").hide();';
      ELSIF v_affected_elements_type = 'region' THEN      
        v_html := 'apex.jQuery("#' || nvl(v_affected_region_static_id, 'R' || v_affected_region_id) || '").hide();';
      ELSE
        -- unknown/unhandled (nothing to hide)
        raise_application_error(-20001, 'Unknown Affected Element Type');
      END IF; -- v_affected_elements_type
     
      apex_javascript.add_onload_code (
        p_code => v_html,
        p_key  => NULL); -- Leave null so always run
    END IF; -- v_hide_on_load
    
    -- RETURN
    v_result.javascript_function := '$.ui.clarifitDialog.daDialog';
    v_result.attribute_01 := v_modal;
    v_result.attribute_02 := v_close_on_esc;
    v_result.attribute_03 := v_title;
    v_result.attribute_04 := v_on_close_visible_state;
    
    RETURN v_result;

  END f_render_dialog;
  
  
  FUNCTION f_render_rss_reader(
    p_region              IN apex_plugin.t_region,
    p_plugin              IN apex_plugin.t_plugin,
    p_is_printer_friendly IN boolean )
    RETURN apex_plugin.t_region_render_result
  AS
    -- Region Plugin Attributes
    v_rss_type apex_application_page_regions.attribute_01%type := p_region.attribute_01; -- blogger (can add more types)
    v_rss_url apex_application_page_regions.attribute_01%type := p_region.attribute_02;
    v_max_row_nums pls_integer := to_number(p_region.attribute_03); 
    v_dialog_width apex_application_page_regions.attribute_01%type := p_region.attribute_04;
    v_dialog_height apex_application_page_regions.attribute_01%type := p_region.attribute_05; 
    
    -- Other
    v_html VARCHAR2(4000); -- Used for temp HTML 
    v_div_id VARCHAR2(255) := 'clarifitRSSReader_' || p_region.id; -- Used for dialog window placeholder
    v_rss_xml_namespace VARCHAR2(255);
    
    -- Return
    v_return apex_plugin.t_region_render_result;
    
    -- Procedures
    PROCEDURE sp_display_rss_title(
      p_rss_id IN VARCHAR2,
      p_rss_title IN VARCHAR2,
      p_rn IN pls_integer, -- Current row number
      p_row_cnt IN pls_integer -- Total number of rows in the query
      )
    AS
    BEGIN
      -- Handle first row items
      IF p_rn = 1 THEN
        sys.htp.p('<table>');
      END IF; -- First row
      
      v_html := ('<tr><td><a href="javascript:$.clarifitRssReader.showContentModal(''%RSS_ID%'', clarifitRssReaderVals.R%REGION_ID%);">%TITLE%</a></td></tr>');
      v_html := REPLACE(v_html, '%TITLE%', p_rss_title);
      v_html := replace(v_html, '%RSS_ID%', p_rss_id);
      v_html := REPLACE(v_html, '%REGION_ID%', p_region.id);
       
      sys.htp.p(v_html);
      
      -- If Last row close table
      IF p_rn = p_row_cnt THEN
        sys.htp.p('</table>');
      END IF;
      
    END sp_display_rss_title;
          
  BEGIN

    -- Debug information (if app is being run in debug mode)
    IF apex_application.g_debug THEN
      apex_plugin_util.debug_region (
        p_plugin => p_plugin,
        p_region => p_region,
        p_is_printer_friendly => p_is_printer_friendly);
    END IF;
    
    IF NOT p_is_printer_friendly THEN
      -- Load JavaSript Files
      apex_javascript.add_library (p_name => '$console_wrapper', p_directory => p_plugin.file_prefix, p_version=> '_1.0.3'); -- Load Console Wrapper for debugging
      apex_javascript.add_library (p_name => 'clarifitRSSReader', p_directory => p_plugin.file_prefix, p_version=> '_1.0.0'); -- Load Console Wrapper for debugging
      
      -- CSS Properties
      apex_css.add (
        p_css => '
          .clarifitRssReader-label {font-weight: bold}
          .clarifitRssReader-author {font-style: italic}
          .clarifitRssReader-link {font-style: italic}
          ',
        p_key => 'clarifitRssReader');
    
      -- Initial JS. Only run if not in printer friendly mode
      sys.htp.p('<div id="' || v_div_id || '"></div>'); -- Used for dialog placeholder
  
      -- Set JavaScript global variables that will be used to handle display options
      sys.htp.p('<script type="text/javascript">(function($){');     
      -- Only ryn this code once so as not to overwrite the global variable
      apex_javascript.add_inline_code (
        p_code => 'var clarifitRssReaderVals = {}',
        p_key => 'clarifitRssReaderVals');
      
      -- Extend feature allows you to append variables to JSON object  
      v_html := ' 
        $.extend(clarifitRssReaderVals, 
          {"R%REGION_ID%" : {
            %AJAX_IDENTIFIER%
            %RSS_TYPE%
            %IMAGE_PREFIX%
            %DIALOG_WIDTH%
            %DIALOG_HEIGHT%
            %DIV_ID_END_ELEMENT%
          }});';

      v_html := REPLACE(v_html, '%REGION_ID%', p_region.id);
      v_html := REPLACE (v_html, '%AJAX_IDENTIFIER%', apex_javascript.add_attribute('ajaxIdentifier', apex_plugin.get_ajax_identifier));
      v_html := REPLACE (v_html, '%RSS_TYPE%', apex_javascript.add_attribute('rssType', v_rss_type)); 
      v_html := REPLACE (v_html, '%IMAGE_PREFIX%', apex_javascript.add_attribute('imagePrefix', apex_application.g_image_prefix)); 
      v_html := REPLACE (v_html, '%DIALOG_WIDTH%', apex_javascript.add_attribute('dialogWidth', sys.htf.escape_sc(v_dialog_width)));
      v_html := REPLACE (v_html, '%DIALOG_HEIGHT%', apex_javascript.add_attribute('dialogHeight', sys.htf.escape_sc(v_dialog_height)));
      v_html := REPLACE (v_html, '%DIV_ID_END_ELEMENT%', apex_javascript.add_attribute('divId', v_div_id, FALSE, FALSE));
      
      apex_javascript.add_inline_code (p_code => v_html);
      
      sys.htp.p('})(apex.jQuery);</script>');
    END IF; -- printer friendly
  
    -- For each type
    IF v_rss_type = 'blogger' THEN
      v_rss_xml_namespace := 'http://www.w3.org/2005/Atom';
      
      FOR x IN (
        SELECT id, title, rownum rn, count(1) over() row_cnt
        FROM xmltable(
            XMLNAMESPACES(DEFAULT 'http://www.w3.org/2005/Atom'),
            '*' passing httpuritype (v_rss_url).getxml().EXTRACT('//feed/entry','xmlns="http://www.w3.org/2005/Atom"')
            COLUMNS id VARCHAR2(4000)   PATH 'id',
                    title VARCHAR2(48)   PATH 'title',
                    author   VARCHAR2(1000) path 'author/name'
                    )
        WHERE ROWNUM <= v_max_row_nums
      ) loop
      
        sp_display_rss_title(
          p_rss_id => x.ID,
          p_rss_title => x.title,
          p_rn => x.rn,
          p_row_cnt => x.row_cnt);
      END loop;
    
    -- Add additional support for RSS feeds here.
    ELSE
      -- Unknown RSS type
      sys.htp.p('Error: unknown RSS type');
    END IF;

    -- Return
    RETURN v_return;
        
  END f_render_rss_reader;
 
 
  FUNCTION f_ajax_rss_reader (
    p_region IN apex_plugin.t_region,
    p_plugin IN apex_plugin.t_plugin )
    RETURN apex_plugin.t_region_ajax_result
  AS
    -- APEX Application Variables (x01..x10)
    v_rss_type VARCHAR2(255) := LOWER(apex_application.g_x01);
    v_rss_id VARCHAR2(255) := apex_application.g_x02;
    
    -- Region Plugin Attributes
    v_rss_url apex_application_page_regions.attribute_01%TYPE := p_region.attribute_02;

    -- Other Variables
    v_author VARCHAR2(255);
    v_title VARCHAR2(255);
    v_link VARCHAR2(1000); 
    v_content CLOB;
    v_cnt pls_integer;

    -- Return
    v_return apex_plugin.t_region_ajax_result;
    
    -- Functions
    
    -- Prints HTML JSON object for page to process
    PROCEDURE sp_print_json(
      p_author IN VARCHAR2,
      p_title IN VARCHAR,
      p_content IN CLOB,
      p_link IN VARCHAR2,
      p_error_msg IN VARCHAR2 DEFAULT NULL)
      
    AS
      v_html CLOB;
      v_content clob;
    BEGIN
      v_content := p_content;
      
      -- Escape HTML if required
      IF p_region.escape_output THEN
        v_content := sys.htf.escape_sc(v_content);
      END IF;
    
      v_html := '{
        %AUTHOR%
        %TITLE%
        %CONTENT%
        %LINK%
        %ERROR_MSG_END_ELEMENT%
      }';
      
      v_html := REPLACE(v_html, '%AUTHOR%', apex_javascript.add_attribute('author', sys.htf.escape_sc(p_author), FALSE));
      v_html := REPLACE(v_html, '%TITLE%', apex_javascript.add_attribute('title', sys.htf.escape_sc(p_title), FALSE));
      v_html := REPLACE(v_html, '%CONTENT%', apex_javascript.add_attribute('content', v_content, FALSE));
      v_html := REPLACE(v_html, '%LINK%', apex_javascript.add_attribute('link', sys.htf.escape_sc(p_link), FALSE));
      v_html := REPLACE(v_html, '%ERROR_MSG_END_ELEMENT%', apex_javascript.add_attribute('errorMsg', sys.htf.escape_sc(p_error_msg), FALSE, FALSE));
  
      sys.htp.p(v_html);
    END sp_print_json;
    
    -- Wrapper for error message
    PROCEDURE sp_print_error_msg(
      p_error_msg IN VARCHAR2)
    AS
    BEGIN
      sp_print_json(
        p_author => NULL,
        p_title => NULL, 
        p_content => NULL,
        p_link => null,
        p_error_msg => p_error_msg);
    END sp_print_error_msg;
    
  BEGIN
  
    IF v_rss_type = 'blogger' THEN
      -- Get blog details
      DECLARE
        http_request_failed EXCEPTION;
        PRAGMA EXCEPTION_INIT(http_request_failed, -29273);
      BEGIN
        SELECT author, title, CONTENT, LINK
        INTO v_author, v_title, v_content, v_link
        FROM xmltable(
            XMLNAMESPACES(DEFAULT 'http://www.w3.org/2005/Atom'),
            '*' passing httpuritype (v_rss_url).getxml().EXTRACT('//feed/entry','xmlns="http://www.w3.org/2005/Atom"')
            COLUMNS ID VARCHAR2(4000) path 'id',
                    title VARCHAR2(48) path 'title',
                    link VARCHAR2(1000) path 'link[@rel="alternate"]/@href',
                    author VARCHAR2(1000) path 'author/name',
                    content CLOB PATH 'content')
        WHERE ID = v_rss_id;
        
        sp_print_json(
          p_author => v_author,
          p_title => v_title, 
          p_content => v_content,
          p_link => v_link);
            
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
           sp_print_error_msg(p_error_msg => 'Invalid RSS ID');
        WHEN TOO_MANY_ROWS THEN
          sp_print_error_msg(p_error_msg => 'RSS ID returned multiple matches');
        WHEN http_request_failed THEN
          sp_print_error_msg(p_error_msg => 'HTTP Connection Error');
        WHEN OTHERS THEN
          sp_print_error_msg(p_error_msg => 'Unknown Error');
      END; -- Select     
      
    -- Add more RSS type support here 
    ELSE
      -- Return error message
      sp_print_error_msg(p_error_msg => 'Unknown RSS Type');
    END IF; -- v_rss_type
    
    RETURN v_return;
  
  EXCEPTION 
    WHEN OTHERS THEN
      sp_print_error_msg(p_error_msg => 'Unknown Error');
  END f_ajax_rss_reader;
  
  
  
  FUNCTION f_execute_txt_msg (
    p_process IN apex_plugin.t_process,
    p_plugin  IN apex_plugin.t_plugin )
    RETURN apex_plugin.t_process_exec_result
  AS
 
    -- Types
    TYPE typ_carrier_info IS record (
      email_addr VARCHAR2(255),
      num_digits NUMBER(2,0) --If null then any list of numbers will work
    );
      
    TYPE tt_carrier_info IS TABLE OF typ_carrier_info  INDEX BY varchar2(10); -- index by carrier code
    

    -- Application Plugin Attributes
    v_force_push_queue_flag apex_application_page_items.attribute_01%TYPE := upper(p_plugin.attribute_01); -- force pushing the APEX mail queue
    
    -- Item Plugin Attributes
    v_phone_number apex_application_page_items.attribute_01%TYPE := p_process.attribute_01; 
    v_carrier_code apex_application_page_items.attribute_01%TYPE := upper(p_process.attribute_02); -- Cell phone carrier code
    v_txt_msg apex_application_page_items.attribute_01%TYPE := p_process.attribute_03; -- Text message to send
    
    -- Other variables
    v_return apex_plugin.t_process_exec_result;
    v_all_carrier_info tt_carrier_info;
    
    v_carrier_info typ_carrier_info; -- Current carrier info
    
    -- Functions
    FUNCTION f_ret_carrier_info_rec(
      p_email_addr VARCHAR2,
      p_num_digits NUMBER)
      RETURN typ_carrier_info
    AS
      v_carrier_info typ_carrier_info;
    BEGIN
      v_carrier_info.email_addr := p_email_addr;
      v_carrier_info.num_digits := p_num_digits;
      RETURN v_carrier_info;
    END;
    
  BEGIN
    -- Debug
    IF apex_application.g_debug THEN
      apex_plugin_util.debug_process (
        p_plugin => p_plugin,
        p_process => p_process);
    END IF;
  
    -- Remove non numeric values from phone number
    -- This allows phone numbers to be in any format
    v_phone_number := regexp_replace(v_phone_number, '[^[:digit:]]', '');
  
    -- Load Carrier info
    -- Email address obtained from: http://www.emailtextmessages.com/
    v_all_carrier_info('TELUS') := f_ret_carrier_info_rec(p_email_addr => '@NUM@@msg.telus.com', p_num_digits => 10);
    v_all_carrier_info('ROGERS') := f_ret_carrier_info_rec(p_email_addr => '@NUM@@pcs.rogers.com', p_num_digits => 10);
    v_all_carrier_info('ATT') := f_ret_carrier_info_rec(p_email_addr => '@NUM@@txt.att.net', p_num_digits => 10);
    -- Can add more carrier code information here

    -- Set current carrier
    BEGIN
      v_carrier_info := v_all_carrier_info(v_carrier_code);
      v_carrier_info.email_addr := REPLACE(v_carrier_info.email_addr, '@NUM@', v_phone_number); -- Replace mnemonic
    exception 
      WHEN NO_DATA_FOUND THEN
        raise_application_error(-20001, 'Invalid carrier code');
    END;
        
    -- VALIDATIONS
    IF v_phone_number IS NULL THEN
      raise_application_error(-20001, 'Missing phone number');
    elsif v_carrier_info.num_digits IS NOT NULL AND v_carrier_info.num_digits != LENGTH(v_phone_number) THEN
      raise_application_error(-20001, 'Number of digits is incorrect. Have: ' || v_phone_number || '. Expected: ' || v_carrier_info.num_digits);
    END IF;
    
    -- Send meail to text message
    apex_mail.send(
      p_to => v_carrier_info.email_addr,
      p_from => NULL,
      p_body => v_txt_msg);
  
    -- Push mail queue only if necessary
    IF v_force_push_queue_flag = 'Y' THEN
      -- Send text message right away
      apex_mail.push_queue();
    END IF;
    
    -- Return
    v_return.success_message := p_process.success_message;
    RETURN v_return;

  END f_execute_txt_msg;
  
END pkg_apress_plugins;
/