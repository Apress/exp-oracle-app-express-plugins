-- Only required for Oracle 11g and above

-- Run as SYSTEM or SYS
-- Creates a ACL with access to all domains and ports
-- Or leverages one that already exists
DECLARE
  v_acl dba_network_acls.acl%TYPE;
  v_user VARCHAR2(30) := 'APRESS'; -- *** CHANGE TO YOUR USER
  v_cnt pls_integer;
BEGIN
  v_user := upper(v_user);
  
  -- Get current ACL (if it exists)
  SELECT max(acl)
  INTO v_acl
  FROM dba_network_acls
  WHERE host = '*'
    AND lower_port IS NULL
    AND upper_port IS NULL;

  IF v_acl IS NULL THEN
    -- No ACL exists. Create one
    v_acl := 'apress_full_access.xml';

    -- Create ACL with access to your user
    dbms_network_acl_admin.create_acl (
      acl          => v_acl, 
      description  => 'ACL Access for Apress demo',
      principal    => v_user,
      is_grant     => TRUE, 
      privilege    => 'connect',
      start_date   => NULL,
      end_date     => NULL);
    
    -- Grant access to ACL to all ports and ports  
    dbms_network_acl_admin.assign_acl (
      acl         => v_acl,
      host        => '*', -- This is the network that you have access to.
      lower_port  => NULL,
      upper_port  => NULL);
  ELSE
    -- ACL Exists, just need to give access to user (if applicable)
    SELECT count(acl)
    INTO v_cnt
    FROM dba_network_acl_privileges
    WHERE acl = v_acl
      and principal = v_user;
    
    IF v_cnt = 0 THEN
      -- User needs to be granted
      dbms_network_acl_admin.add_privilege(
        acl       => v_acl,
        principal => v_user,
        is_grant  => true,
        PRIVILEGE => 'connect');
    ELSE
      -- User has access to network
      -- Nothing to be done
      NULL;
    END IF;
    
  END IF;
  
  COMMIT;
  
END;
/


-- Useful Queries
-- Must be run as SYSTEM or SYS

-- All ACLs 
SELECT host, lower_port, upper_port, acl 
FROM dba_network_acls; 

-- Privileges for ACLs
-- Lists which users have access to which ACL
SELECT acl, principal, privilege, is_grant, invert, start_date, end_date
FROM dba_network_acl_privileges; 


-- Test that user has network access now
-- Run as APRESS user
-- Determines if current user has access to external connections
-- Makes a simple connection to www.google.com on port 80
-- Result will be in DBMS_OUTPUT
DECLARE
  v_connection  utl_tcp.connection;
BEGIN
  v_connection := utl_tcp.open_connection(remote_host => 'www.google.com', remote_port => 80);
  utl_tcp.close_connection(v_connection);    
  
  dbms_output.put_line('Ok: Have Access');
  
  EXCEPTION
    WHEN others THEN 
      IF sqlcode = -24247 THEN
        -- ORA-24247: network access denied by access control list (ACL)
        dbms_output.put_line('No ACL network access.');
      ELSE
        dbms_output.put_line('Unknown Error: ' || sqlerrm);
      END IF;
END;
/
