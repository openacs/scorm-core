# These attributes clash with a reserved word in one or another database supported by ilias,
# and therefore are prepended by "c_" when used as a database column.  Code that references
# the various ilias-derived tables should therefore prepend "c_" to any ilias-derived attribute
# that appears in this list.  The approved way to do this is to call scorm_core::db_name.

# This information is required by both the importer and player, therefore is defined here.

nsv_set scorm_core rte_db_special_attrs \
    {comment condition entry exit language max min mode identifier online operator primary
     raw settings timestamp type}
