ad_library {

    Set of procs useful to a variety of SCORM stuff.

    @creation-date 2010/04/09
    @author Don Baccus
    @cvs-id $Id$
}

namespace eval scorm_core {}

ad_proc scorm_core::db_name {
    -name:required
} {

    The ilias datamodel includes attributes which clash with keywords defined for various
    databases they support.  Such attributes (such as "primary", of "primary key" fame)
    are prepended with "c_" in the datamodel.
 
    @param name The RTE attribute name to transform to the corresponding database attribute.
    @return The name or the name prepended with "c_" depending on whether or not it appears
            in the list of RTE attributes that conflict with various database keywords.

} {
    if { [lsearch -exact [nsv_get scorm_core rte_db_special_attrs] $name] != -1 } {
        return c_$name
    }
    return $name
}

ad_proc scorm_core::default_folder_id {
    -package_id:required
} {

    Get the default folder for a given suite of the SCORM packages.  This is used
    by the default HTTP UI for uploading new courses, and any client package that
    embeds the scorm utility packages must map a folder to a package_id.  The Scorm
    demo package maps a folder to its own instance, a LMS meant to be more "dotLRN-ish"
    might want to map a folder to its parent community (subsite).
} {
    return [db_string get_default_folder_id {}]
}

