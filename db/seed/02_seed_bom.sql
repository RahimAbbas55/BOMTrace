DECLARE
  PROCEDURE add_line(
    p_parent IN VARCHAR2,
    p_child  IN VARCHAR2,
    p_qty    IN NUMBER
  ) IS
  BEGIN
    INSERT INTO bom_lines (parent_item_id, child_item_id, quantity)
    SELECT p.item_id, c.item_id, p_qty
    FROM items p
    JOIN items c ON c.item_number = p_child
    WHERE p.item_number = p_parent;

    -- a typo in an item number would insert nothing, so fail loudly
    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20900, 'Seed failed: unknown item in ' || p_parent || ' -> ' || p_child);
    END IF;
  END add_line;
BEGIN
  -- bike: level 1 sub-assemblies
  add_line('EB-1000', 'EB-1100', 1);
  add_line('EB-1000', 'EB-1200', 1);
  add_line('EB-1000', 'EB-1300', 1);
  add_line('EB-1000', 'EB-1400', 1);
  add_line('EB-1000', 'EB-1500', 1);
  add_line('EB-1000', 'EB-1600', 1);

  -- frame
  add_line('EB-1100', 'EB-1110', 1);
  add_line('EB-1100', 'EB-2001', 1);
  add_line('EB-1100', 'EB-2002', 1);
  add_line('EB-1100', 'EB-2003', 1);
  add_line('EB-1100', 'EB-2004', 1);
  add_line('EB-1100', 'EB-2902', 8);

  -- fork
  add_line('EB-1110', 'EB-2011', 1);
  add_line('EB-1110', 'EB-2012', 1);
  add_line('EB-1110', 'EB-2013', 2);

  -- drive unit
  add_line('EB-1200', 'EB-1210', 1);
  add_line('EB-1200', 'EB-2121', 1);
  add_line('EB-1200', 'EB-2122', 1);
  add_line('EB-1200', 'EB-2902', 4);

  -- motor (controller is integrated into the motor)
  add_line('EB-1210', 'EB-1220', 1);
  add_line('EB-1210', 'EB-2101', 1);
  add_line('EB-1210', 'EB-2102', 1);
  add_line('EB-1210', 'EB-2103', 1);
  add_line('EB-1210', 'EB-2104', 3);
  add_line('EB-1210', 'EB-2105', 2);
  add_line('EB-1210', 'EB-2901', 6);

  -- controller board
  add_line('EB-1220', 'EB-2111', 1);
  add_line('EB-1220', 'EB-2112', 6);
  add_line('EB-1220', 'EB-2113', 1);
  add_line('EB-1220', 'EB-2114', 4);

  -- wheel set and wheels
  add_line('EB-1300', 'EB-1310', 1);
  add_line('EB-1300', 'EB-1320', 1);
  add_line('EB-1310', 'EB-2201', 1);
  add_line('EB-1310', 'EB-2202', 36);
  add_line('EB-1310', 'EB-2203', 1);
  add_line('EB-1310', 'EB-2204', 1);
  add_line('EB-1310', 'EB-2205', 1);
  add_line('EB-1320', 'EB-2201', 1);
  add_line('EB-1320', 'EB-2202', 36);
  add_line('EB-1320', 'EB-2203', 1);
  add_line('EB-1320', 'EB-2204', 1);
  add_line('EB-1320', 'EB-2205', 1);
  add_line('EB-1320', 'EB-2206', 1);

  -- battery pack and cell module
  add_line('EB-1400', 'EB-1410', 4);
  add_line('EB-1400', 'EB-2311', 1);
  add_line('EB-1400', 'EB-2312', 1);
  add_line('EB-1400', 'EB-2901', 8);
  add_line('EB-1410', 'EB-2301', 10);
  add_line('EB-1410', 'EB-2302', 1);
  add_line('EB-1410', 'EB-2303', 2);

  -- cockpit and display
  add_line('EB-1500', 'EB-1510', 1);
  add_line('EB-1500', 'EB-2411', 1);
  add_line('EB-1500', 'EB-2412', 2);
  add_line('EB-1500', 'EB-2413', 1);
  add_line('EB-1500', 'EB-2901', 4);
  add_line('EB-1510', 'EB-2401', 1);
  add_line('EB-1510', 'EB-2402', 1);
  add_line('EB-1510', 'EB-2403', 1);
  add_line('EB-1510', 'EB-2901', 4);

  -- brakes
  add_line('EB-1600', 'EB-1610', 2);
  add_line('EB-1600', 'EB-2511', 2);
  add_line('EB-1600', 'EB-2512', 2);
  add_line('EB-1610', 'EB-2501', 1);
  add_line('EB-1610', 'EB-2502', 2);
  add_line('EB-1610', 'EB-2503', 2);
  add_line('EB-1610', 'EB-2901', 2);

  COMMIT;
END;
/