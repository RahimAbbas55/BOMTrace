-- demo logins (also listed in the README):
--   engineer@bomtrace.dev  /  BomTrace-Eng-2026
--   approver@bomtrace.dev  /  BomTrace-App-2026
INSERT INTO users (email, password_hash, role) VALUES
  ('engineer@bomtrace.dev', '$2b$10$/e18UaE8.i2DXVgoQngBtuqjp6ymfy2oVXoxnEq2Zxqy.SMbd8mru', 'ENGINEER');
INSERT INTO users (email, password_hash, role) VALUES
  ('approver@bomtrace.dev', '$2b$10$Zrg94yA.d4DVwuy3PZSFouaSFhTrutDyAeH16VG4VK5j14aRg6uoC', 'APPROVER');

DECLARE
  v_creator users.user_id%TYPE;

  PROCEDURE add_item(
    p_number IN VARCHAR2,
    p_name   IN VARCHAR2,
    p_desc   IN VARCHAR2,
    p_type   IN VARCHAR2,
    p_status IN VARCHAR2 DEFAULT 'ACTIVE'
  ) IS
  BEGIN
    INSERT INTO items (item_number, name, description, item_type, lifecycle_status, created_by)
    VALUES (p_number, p_name, p_desc, p_type, p_status, v_creator);
  END add_item;
BEGIN
  SELECT user_id INTO v_creator FROM users WHERE email = 'engineer@bomtrace.dev';

  -- level 1: finished product
  add_item('EB-1000', 'Electric Bike Model E1', 'Complete 250W commuter e-bike', 'ASSEMBLY');

  -- level 2: sub-assemblies
  add_item('EB-1100', 'Frame Assembly', 'Welded aluminium frame with fork', 'ASSEMBLY');
  add_item('EB-1200', 'Drive Unit Assembly', 'Mid-drive motor, controller and crank', 'ASSEMBLY');
  add_item('EB-1300', 'Wheel Set Assembly', 'Front and rear wheels', 'ASSEMBLY');
  add_item('EB-1400', 'Battery Pack Assembly', '36V 10Ah lithium-ion pack', 'ASSEMBLY');
  add_item('EB-1500', 'Cockpit Assembly', 'Handlebar, stem, grips and display', 'ASSEMBLY');
  add_item('EB-1600', 'Brake System', 'Front and rear disc brakes', 'ASSEMBLY');

  -- level 3: sub-sub-assemblies
  add_item('EB-1110', 'Fork Assembly', 'Rigid steel fork', 'ASSEMBLY');
  add_item('EB-1210', 'Motor Assembly', '250W brushless motor', 'ASSEMBLY');
  add_item('EB-1220', 'Controller Board Assembly', 'Motor controller electronics', 'ASSEMBLY');
  add_item('EB-1310', 'Front Wheel Assembly', '700c front wheel with tire', 'ASSEMBLY');
  add_item('EB-1320', 'Rear Wheel Assembly', '700c rear wheel with cassette', 'ASSEMBLY');
  add_item('EB-1410', 'Cell Module', 'Series module of 18650 cells', 'ASSEMBLY');
  add_item('EB-1510', 'Display Unit', 'LCD display with housing', 'ASSEMBLY', 'PROTOTYPE');
  add_item('EB-1610', 'Brake Caliper Assembly', 'Hydraulic disc caliper', 'ASSEMBLY');

  -- frame and fork parts
  add_item('EB-2001', 'Main Frame Tube', 'Hydroformed aluminium tube', 'MAKE');
  add_item('EB-2002', 'Seat Tube', 'Aluminium seat tube', 'MAKE');
  add_item('EB-2003', 'Head Tube', 'Tapered head tube', 'MAKE');
  add_item('EB-2004', 'Rear Dropout Set', 'Machined rear dropouts', 'MAKE');
  add_item('EB-2011', 'Fork Steerer Tube', 'Steel steerer tube', 'MAKE');
  add_item('EB-2012', 'Fork Crown', 'Forged fork crown', 'MAKE');
  add_item('EB-2013', 'Headset Bearing', 'Sealed cartridge bearing', 'BUY');

  -- drive unit parts
  add_item('EB-2101', 'Motor Stator', 'Wound stator', 'MAKE');
  add_item('EB-2102', 'Motor Rotor', 'Magnet rotor', 'MAKE');
  add_item('EB-2103', 'Motor Housing', 'Cast aluminium housing', 'MAKE');
  add_item('EB-2104', 'Hall Sensor', 'Rotor position sensor', 'BUY');
  add_item('EB-2105', 'Motor Bearing 6902', 'Sealed deep groove bearing', 'BUY');
  add_item('EB-2111', 'Controller PCB Blank', 'Four layer controller board', 'BUY');
  add_item('EB-2112', 'Power MOSFET', 'Motor driver MOSFET', 'BUY');
  add_item('EB-2113', 'Microcontroller', '32-bit control MCU', 'BUY');
  add_item('EB-2114', 'Electrolytic Capacitor', 'Bus capacitor', 'BUY');
  add_item('EB-2121', 'Crank Arm Set', 'Forged crank arms', 'MAKE');
  add_item('EB-2122', 'Bottom Bracket', 'Sealed bottom bracket', 'BUY');

  -- wheel parts
  add_item('EB-2201', 'Rim 700c', 'Double wall aluminium rim', 'BUY');
  add_item('EB-2202', 'Spoke', 'Stainless steel spoke', 'BUY');
  add_item('EB-2203', 'Hub', 'Sealed bearing hub', 'BUY');
  add_item('EB-2204', 'Tire 700x38', 'Puncture resistant tire', 'BUY');
  add_item('EB-2205', 'Inner Tube', 'Butyl inner tube', 'BUY');
  add_item('EB-2206', 'Cassette 8-speed', 'Rear cassette', 'BUY');

  -- battery parts
  add_item('EB-2301', 'Li-ion Cell 18650', '3.6V 2500mAh cell', 'BUY');
  add_item('EB-2302', 'Cell Holder', 'Injection moulded holder', 'MAKE');
  add_item('EB-2303', 'Nickel Busbar', 'Cell interconnect strip', 'MAKE');
  add_item('EB-2311', 'Battery Casing', 'Aluminium battery casing', 'MAKE');
  add_item('EB-2312', 'BMS Board', 'Battery management board', 'BUY');

  -- cockpit parts
  add_item('EB-2401', 'LCD Screen', 'Segment LCD panel', 'BUY');
  add_item('EB-2402', 'Display Housing', 'Sealed plastic housing', 'MAKE');
  add_item('EB-2403', 'Display PCB', 'Display driver board', 'BUY', 'PROTOTYPE');
  add_item('EB-2411', 'Handlebar', 'Flat aluminium handlebar', 'MAKE');
  add_item('EB-2412', 'Grip', 'Ergonomic grip', 'BUY');
  add_item('EB-2413', 'Handlebar Stem', 'Forged stem', 'MAKE');

  -- brake parts
  add_item('EB-2501', 'Caliper Body', 'Cast caliper body', 'MAKE');
  add_item('EB-2502', 'Brake Pad', 'Sintered brake pad', 'BUY');
  add_item('EB-2503', 'Piston Seal', 'Hydraulic piston seal', 'BUY');
  add_item('EB-2511', 'Brake Lever', 'Hydraulic brake lever', 'BUY');
  add_item('EB-2512', 'Brake Cable', 'Hydraulic brake hose', 'BUY');

  -- shared fasteners (used in several assemblies)
  add_item('EB-2901', 'M6 Bolt', 'Stainless M6 bolt', 'BUY');
  add_item('EB-2902', 'M8 Bolt', 'Stainless M8 bolt', 'BUY');

  -- superseded part, kept for the change order demo
  add_item('EB-2999', 'Legacy Controller PCB', 'Replaced by EB-2111', 'BUY', 'OBSOLETE');

  COMMIT;
END;
/