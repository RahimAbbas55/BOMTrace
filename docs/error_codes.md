# PLM_PKG error codes

PL/SQL raises `ORA-200xx` errors. The API reads the number from the Oracle error (`errorNum` in node-oracledb) and returns the matching HTTP status with the message.

| Code | Exception | Meaning | HTTP |
|---|---|---|---|
| -20001 | `e_item_not_found` | Item does not exist | 404 |
| -20002 | `e_bom_cycle` | Adding the line would create a loop in the BOM | 409 |
| -20003 | `e_bom_line_exists` | That parent already contains that child | 409 |
| -20004 | `e_item_obsolete` | An obsolete item cannot be changed | 409 |
| -20005 | `e_co_not_found` | Change order does not exist | 404 |
| -20006 | `e_invalid_transition` | Status change not allowed from the current status | 409 |
| -20007 | `e_co_empty` | Change order has no lines | 422 |
| -20008 | `e_user_not_found` | User does not exist | 404 |
| -20009 | `e_approver_required` | Only an approver can do this | 403 |
| -20010 | `e_self_approval` | The creator cannot approve their own change order | 403 |
| -20011 | `e_comment_required` | A rejection needs a comment | 400 |
| -20012 | `e_invalid_co_line` | The change line does not make sense for the BOM | 422 |
| -20013 | `e_bom_line_not_found` | BOM line does not exist | 404 |
| -20014 | `e_invalid_quantity` | Quantity must be greater than zero | 400 |