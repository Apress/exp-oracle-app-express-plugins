-- For Region Plug-ins Chapter
-- Code for AJAX demo

-- Takes value and multiplies it by 2
-- No error handling etc, as this is a demo
DECLARE
  v_num pls_integer;
BEGIN
  v_num := to_number(apex_application.g_x01);
  
  v_num := v_num * 2;
  
  htp.p (v_num);
END;
