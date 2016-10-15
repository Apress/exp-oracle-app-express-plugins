CREATE OR REPLACE PACKAGE pkg_apress_plugins AS

  FUNCTION f_render_from_to_datepicker (
    p_item                IN apex_plugin.t_page_item,
    p_plugin              IN apex_plugin.t_plugin,
    p_value               IN VARCHAR2,
    p_is_readonly         IN boolean,
    p_is_printer_friendly IN boolean )
    RETURN apex_plugin.t_page_item_render_result;
    
  FUNCTION f_validate_from_to_datepicker (
    p_item   in apex_plugin.t_page_item,
    p_plugin in apex_plugin.t_plugin,
    p_value  IN VARCHAR2 )
    RETURN apex_plugin.t_page_item_validation_result;

  FUNCTION f_render_dialog (
    p_dynamic_action IN apex_plugin.t_dynamic_action,
    p_plugin         IN apex_plugin.t_plugin )
    RETURN apex_plugin.t_dynamic_action_render_result;
 
  FUNCTION f_render_rss_reader(
    p_region              IN apex_plugin.t_region,
    p_plugin              IN apex_plugin.t_plugin,
    p_is_printer_friendly IN boolean )
    RETURN apex_plugin.t_region_render_result;
  
   FUNCTION f_ajax_rss_reader (
    p_region IN apex_plugin.t_region,
    p_plugin IN apex_plugin.t_plugin )
    RETURN apex_plugin.t_region_ajax_result;  
    
  FUNCTION f_execute_txt_msg (
    p_process IN apex_plugin.t_process,
    p_plugin  IN apex_plugin.t_plugin )
    RETURN apex_plugin.t_process_exec_result;
    
END pkg_apress_plugins;
/

