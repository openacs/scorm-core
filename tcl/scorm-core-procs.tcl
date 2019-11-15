ad_library {

    Set of procs useful to a variety of SCORM stuff.

    @creation-date 2010/04/09
    @author Don Baccus
    @cvs-id $Id$
}

namespace eval scorm_core {
    namespace eval cp {}
    namespace eval rte_jsdata {}
    namespace eval rte_activity_tree {}
}

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

ad_proc scorm_core::create_course {
    -package_id:required
    -manifest:required
    {-course_id ""}
    {-online f}
    {-default_lesson_mode browse}
    {-course_type scorm_course}
} {
    Create a Scorm course skeleton based on a parsed manifest.
} {

    # Version check.  At the moment, it's scorm 2004 or or else it's an error.
    set manifest_doc [$manifest documentElement]
    set metadata [$manifest_doc child 1 metadata]
    set schemaversion [$metadata child 1 schemaversion]
    set schema [$metadata child 1 schema]
    if { $schemaversion eq "" ||
         [string trim [string tolower [$schema text]]] ne "adl scorm" ||
         [string trim [string tolower [$schemaversion text]]] ne "2004 3rd edition" &&
         [string trim [string tolower [$schemaversion text]]] ne "cam 1.3" } {
        return -code error [_ scorm-importer.NotSCORM2004]
    }

    set default_organization [scorm_core::get_default_organization -manifest $manifest_doc]
    set title [[$default_organization child 1 title] text]

    if { [db_0or1row course_exists {}] } {
        return -code error [_ scorm-core.CourseExists]
    }

    regsub -all {[<>:\"|/@\#%&+\\ ]} $title {_} name

    set folder_id [scorm_core::create_folder \
                      -name $name \
                      -parent_id [scorm_core::default_folder_id -package_id $package_id] \
                      -package_id $package_id]

    set var_list [subst {
        {folder_id $folder_id}
        {context_id $package_id}
        {package_id $package_id}
        {type scorm2004}
        {online $online}
        {title "$title"}
        {object_type $course_type}
        {${course_type}_id $course_id}
        {default_lesson_mode $default_lesson_mode}
    }]
    set course_id [package_instantiate_object -var_list $var_list $course_type]

    # create row for package even though we don't have any info yet
    db_dml insert_package {}

    scorm_core::update_rte_data \
        -scorm_course_id $course_id \
        -manifest $manifest

    return $course_id
}

ad_proc scorm_core::edit_course {
    -manifest:required
    -course_id:required
} {
    Edit the course information, using a parsed manifest.  At the moment, this
    rebuilds the cp_node structure, so tracking data for the course is lost.
} {

    # Delete old cp_nodes until I can figure out how to preserve them.  This will
    # also delete the cmi data, i.e. tracking information.

    db_dml delete_cp_nodes {}

    scorm_core::update_rte_data \
        -scorm_course_id $course_id \
        -manifest $manifest
}

ad_proc scorm_core::delete_course {
    -course_id:required
} {
    Delete a course and associated tracking data.
} {
    db_1row get_folder_id {}
    content::folder::delete -folder_id $folder_id -cascade_p t
    package_exec_plsql -var_list [subst {{scorm_course_id $course_id}}] scorm_course delete
}

ad_proc scorm_core::update_rte_data {
    -scorm_course_id:required
    -manifest:required
} {
    Update the RTE data - activity tree, jsdata, xmldata
} {
    set xmldata [$manifest asXML]

    # build activity tree with the original document.
    array set adl_info \
        [scorm_core::rte_activity_tree::create -manifest [$manifest documentElement]]

    set activity_tree $adl_info(activity_tree)
    set global_to_system [expr { [string is true $adl_info(global)] ? "t" : "f" }]

    # then build the cp_* structure and jsdata from the transform.
    set transform [scorm_core::transform -manifest $manifest]
    scorm_core::cp::create_node -cp_package_id $scorm_course_id -node $transform
    set jsdata [scorm_core::rte_jsdata::create -manifest $transform]

    db_dml update_package {}
}

ad_proc scorm_core::transform {
    -manifest:required
} {
    Transform the manifest using ilias's normalizing xsl.
} {
    set xsl_src "[acs_root_dir]/packages/scorm-importer/templates/xsl/op/op-scorm13.xsl"
    return [[$manifest xslt [dom parse [::tdom::xmlReadFile $xsl_src]]] documentElement]
}

ad_proc scorm_core::get_manifest {
    -course_id:required
} {
    Return the saved manifest XML.
} {
    return [db_string get_manifest {} -default ""]
}

ad_proc scorm_core::create_folder {
    -name:required
    -parent_id:required
    -package_id:required
} {
    Create a subr (or main) for a class with the necessary 
} {
    set folder_id [content::folder::new \
                      -name $name \
                      -parent_id $parent_id \
                      -package_id $package_id]

    content::folder::register_content_type \
        -folder_id $folder_id  \
        -content_type content_revision \
        -include_subtypes "t"

    content::folder::register_content_type \
        -folder_id $folder_id \
        -content_type content_item \
        -include_subtypes t

    return $folder_id
}

ad_proc scorm_core::get_folder {
    -course_id:required
} {
    Return the folder_id of the course's folder.
} {
    return [db_string get_folder {}]
}

ad_proc scorm_core::cp::create_node {
    {-node:required}
    {-cp_package_id:required}
    {-depth 1}
    {-parent 0}
} {
    Import a node and its children.
} {

    set nodename [$node nodeName]

    # create the node
    set cp_node_id [db_nextval cp_node_seq]
    set rgt $cp_node_id

    db_dml insert_cp_node {}

    # and insert into tree
    db_dml add_to_cp_tree {}

    # gather attributes for insertion, starting with cp_node_id
    set attributes [list cp_node_id]

    # from http://wiki.tcl.tk/1948
    # attributes may return a singleton. In that case, the attribute name is just that.

    # attributes may return a three-element list. In that case it may be approximated as:

    # [lassign $a name namespace uri]

    # however, the uri may be empty and the name and namespace equal. In that case, the
    # attribute appears to be a definition of the uri for the namespace given by $name,
    # although the uri thus defined is not returned in the uri field, the uri-defining
    #attribute is named as if it were $ns:$ns. Finally, the {xmlns {} {}} form appears
    #to be special, and to indicate that the xmlns namespace's uri is being defined. 

    # build up generic attribute list for insertion
    foreach attribute [$node attributes] {
        if { [llength $attribute] == 1 } {
            set _attribute [scorm_core::db_name -name [string tolower $attribute]]
            lappend attributes $_attribute
            set value [$node getAttribute $attribute]
            # convert trues/falses to t/f
            set $_attribute [ad_decode $value true t false f $value]
        } else {
            foreach { name namespace uri } $attribute { break }
            # ignore xmlns (the only trio not handled by transform?)
            if { $name eq "xmlns" } { continue }
            set _name [scorm_core::db_name -name [string tolower $name]]
            lappend attributes $_name
            set value [$node getAttribute $name $namespace]
            # convert trues/falses to t/f
            set $_name [ad_decode $value true t false f $value]
        }
    }

    # stick cp_node_id into DOM for use later
    $node setAttribute foreignId $cp_node_id

    # insert into cp_*
    db_dml insert_cp {}

    # run sub nodes
    foreach child [$node childNodes] {
        set rgt [scorm_core::cp::create_node -node $child -cp_package_id $cp_package_id \
                    -depth [expr $depth + 1] -parent $cp_node_id]
    }

    db_dml update_rgt {}

    return $rgt
}

ad_proc scorm_core::get_default_organization {
    -manifest:required
} {
    Return the default organization for the course, null if none exists.
} {
    set organizations [$manifest child all organizations]
    set default [$organizations getAttribute default]
    foreach organization [$organizations child all organization] {
        if { [$organization getAttribute identifier] eq $default } {
            return $organization
        }
    }
    return ""
}

ad_proc scorm_core::rte_jsdata::create {
    -manifest:required
    {-verbose_p 0}
} {
    build course content jsdata structure in tcl and convert to JSON format for ilias RTE

    ported from ilias
} {

    # This should be in the parser, not the JSON generation code ???
    # first read resources into flat array to resolve item/identifierref later
    foreach resource [$manifest child all resource] {
        set resources([$resource getAttribute id]) $resource
    }

    # iterate through items and set href and scoType as activity attributes
    foreach item [$manifest selectNodes "//*\[local-name()=\"item\"\]"] {
        if { [$item hasAttribute resourceId] } {
            # get reference to resource and set href accordingly
            set resource $resources([$item getAttribute resourceId])
            $item setAttribute href [$resource getAttribute href]
            if { [$resource hasAttribute base] } {
                $item setAttribute base [$resource getAttribute base]
            }
            $item removeAttribute resourceId
            if { [$resource getAttribute scormType] eq "sco" } {
                $item setAttribute sco 1
            }
        }
    }

    set organization_node [$manifest child all organization]

    $organization_node setAttribute base ""

    # We need to kludge the top level, renaming "organization" to "item" and pulling
    # the sequencing nodes into an array at the same level as the "item" structure.

    lappend jsdata item [scorm_core::rte_jsdata::node -node $organization_node]

    set sequencing_nodes {}
    foreach sequencing_node [$manifest child all sequencing] {
        lappend sequencing_nodes [scorm_core::rte_jsdata::node -node $sequencing_node]
    }
    lappend jsdata sequencing [util::json::array::create $sequencing_nodes]

    # extra stuff wanted by the RTE
    lappend jsdata foreignId [$manifest getAttribute foreignId]
    lappend jsdata id [$manifest getAttribute id]
    lappend jsdata base ""

    return [util::json::gen [util::json::object::create $jsdata]]
}

ad_proc scorm_core::rte_jsdata::node {
    -node:required
} {
    build node
} {

    set node_list {}
    foreach attribute [$node attributes] {
        if { [llength $attribute] == 1 } {
            set value [$node getAttribute $attribute]
            lappend node_list $attribute $value
        }
    }

    # process the children

    # XML: list of nodes like <tag_a/><tag_a/><tag_b/><tag_b/>
    # JSON: {"tag_a":[{contents contents}], "tag_b":[{contents contents}]}

    # Since the children can in theory have different tags, we collect the tag names
    # and values in an array and then spit them out after parsing the children.

    # Parse children and collect them by tag name.
    foreach child [$node childNodes] {
        lappend child_nodes([$child nodeName]) [scorm_core::rte_jsdata::node -node $child]
    }

    # Add them to our key/value node_list
    foreach child_name [array names child_nodes] {
        lappend node_list $child_name [util::json::array::create $child_nodes($child_name)]
    }

    return [util::json::object::create $node_list]
}

ad_proc scorm_core::rte_activity_tree::create {
    -manifest:required
    {-verbose_p 0}
} {
    build activity tree structure in tcl and convert to JSON format for ilias RTE

    ported from ilias
} {

    global sequencing_collection
    set sequencing_collection [$manifest getElementsByTagName "imsss:sequencingCollection"]

    set default_org [scorm_core::get_default_organization -manifest $manifest]

    set activity_tree [scorm_core::rte_activity_tree::seq_activity -node $default_org -order -1]

    set adl_info(global) [$default_org getAttribute adlseq:objectivesGlobalToSystem true]
    set adl_info(activity_tree) [util::json::gen $activity_tree]
    return [array get adl_info]

}

ad_proc scorm_core::rte_activity_tree::seq_activity {
    -node:required
    -order:required
} {
    global sequencing_collection

    array set activity [scorm_core::rte_activity_tree::activity_attributes]
    if { [$node hasAttribute identifier] } {
        set activity(mActivityID) [$node getAttribute identifier]
    }

    if { [$node hasAttribute identifierref] } {
        set activity(mResourceID) [$node getAttribute identifierref]
    }

    if { [$node hasAttribute isvisible] } {
        set activity(mIsVisible) [convert_to_bool [$node getAttribute isvisible]]
    }

    set activity(mOrder) $order
    set activity(mActiveOrder) $order
    unset order

    set children [list]
    foreach child [$node childNodes] {
        switch -- [$child localName] {
            item {

                # store counter for child ordering in node
                if { [$node hasAttribute order] } {
                    set order [$node getAttribute order]
                    $node setAttribute order [incr order]
                } else {
                    set order 0
                    $node setAttribute order $order
                }
                lappend children \
                    [scorm_core::rte_activity_tree::seq_activity -node $child -order $order]
            }
            title {
                set activity(mTitle) [$child text]
            }
            sequencing {
                if { [$child hasAttribute IDRef] } {
                    # this sequencing node references a base in the global collection
                    set id_ref [$child getAttribute IDRef]
                    set sequencings [$sequencing_collection getElementsByTagName "imsss:sequencing"]
                    foreach sequencing $sequencings {
                        if { [$sequencing getAttribute ID] eq $id_ref } {
                            # this is now our base
                            set composite_sequencing [$sequencing cloneNode -deep]
                            break
                        }
                    }
                    if { ![info exists composite_sequencing] } {
                        return -code error "Sequencing \"$id_ref\" not found in global collection."
                    }
                    foreach sequencing_child [$child childNodes] {
                        if { [$sequencing_child nodeType] eq "ELEMENT_NODE" } {
                            $composite_sequencing appendChild $sequencing_child
                        }
                    }
                    scorm_core::rte_activity_tree::extract_sequencing_info \
                       -node $composite_sequencing \
                       -result activity
                } else {
                    # no global reference
                    scorm_core::rte_activity_tree::extract_sequencing_info \
                       -node $child \
                       -result activity

                }
            }
        }
    }

    if { [llength $children] } {
        set activity(mChildren) [util::json::array::create $children]
        set activity(mActiveChildren) [util::json::array::create ""]
    } 

    # remove our counter
    if { [$node hasAttribute order] } {
        $node removeAttribute order
    } 

    return \
        [util::json::object::create \
            [list _SeqActivity \
                [util::json::object::create [array get activity]]]]

}

ad_proc scorm_core::rte_activity_tree::extract_sequencing_info {
    -node:required
    -result:required
} {
    upvar $result local_result

    foreach child [$node childNodes] {
        if { [$child nodeType] eq "ELEMENT_NODE" } {
            switch [$child localName] {
                "objectives" {
                    scorm_core::rte_activity_tree::get_objectives \
                        -node $child \
                        -result local_result
                }
                "sequencingRules" {
                    scorm_core::rte_activity_tree::get_sequencing_rules \
                        -node $child \
                        -result local_result
                }
                "rollupRules" {
                    scorm_core::rte_activity_tree::get_rollup_rules \
                        -node $child \
                        -result local_result
                }
                "auxiliaryResources" {
                    scorm_core::rte_activity_tree::get_auxiliary_resources \
                        -node $child \
                        -result local_result
                }
                "controlMode" {
                    if { [$child hasAttribute choice] } {
                        set local_result(mControl_choice) \
                            [convert_to_bool [$child getAttribute choice]]
                    }
                    if { [$child hasAttribute choiceExit] } {
                        set local_result(mControl_choiceExit) \
                            [convert_to_bool [$child getAttribute choiceExit]]
                    }
                    if { [$child hasAttribute flow] } {
                        set local_result(mControl_flow) \
                            [convert_to_bool [$child getAttribute flow]]
                    }
                    if { [$child hasAttribute forwardOnly] } {
                        set local_result(mControl_forwardOnly) \
                            [convert_to_bool [$child getAttribute forwardOnly]]
                    }
                    if { [$child hasAttribute useCurrentAttemptObjectiveInfo] } {
                        set local_result(mUseCurObj) \
                            [convert_to_bool [$child getAttribute useCurrentAttemptObjectiveInfo]]
                    }
                    if { [$child hasAttribute useCurrentAttemptProgressInfo] } {
                        set local_result(mUseCurPro) \
                            [convert_to_bool [$child getAttribute useCurrentAttemptProgressInfo]]
                    }
                }
                "limitConditions" {
                    if { [$child hasAttribute attemptLimit] } {
                        set attempt_limit [$child getAttribute attemptLimit]
                        if { $attempt_limit >= 0 } {
                            set local_result(mMaxAttemptControl) true
                            set local_result(mMaxAttempt) $attempt_limit
                        } else {
                            set local_result(mMaxAttemptControl) false
                            set local_result(mMaxAttempt) -1
                        }
                    }
                    if { [$child hasAttribute attemptAbsoluteDurationLimit] } {
                        set duration [$child getAttribute attemptAbsoluteDurationLimit]
                        if { $duration ne "null" } {
                            set local_result(mActivityAbDurControl) true
                        } else {
                            set local_result(mActivityAbDurControl) false
                        }
                    }
                    if { [$child hasAttribute attemptExperiencedDurationLimit] } {
                        set duration [$child getAttribute attemptExperiencedDurationLimit]
                        if { $duration ne "null" } {
                            set local_result(mAttemptExDurControl) true
                        } else {
                            set local_result(mAttemptExDurControl) false
                        }
                    }
                    if { [$child hasAttribute activityAbsoluteDurationLimit] } {
                        set duration [$child getAttribute activityAbsoluteDurationLimit]
                        if { $duration ne "null" } {
                            set local_result(mActivityAbDurControl) true
                        } else {
                            set local_result(mActivityAbDurControl) false
                        }
                    }
                    if { [$child hasAttribute activityExperiencedDurationLimit] } {
                        set duration [$child getAttribute activityExperiencedDurationLimit]
                        if { $duration ne "null" } {
                            set local_result(mmActivityExDurControl) true
                        } else {
                            set local_result(mmActivityExDurControl) false
                        }
                    }
                    if { [$child hasAttribute beginTimeLimit] } {
                        set time [$child getAttribute beginTimeLimit]
                        if { $time ne "null" } {
                            set local_result(mBeginTimeControl) true
                            set local_result(mBeginTime) $time
                        } else {
                            set local_result(mBeginTimeControl) false
                        }
                    }
                    if { [$child hasAttribute endTimeLimit] } {
                        set time [$child getAttribute endTimeLimit]
                        if { $time ne "null" } {
                            set local_result(mEndTimeControl) true
                            set local_result(mEndTime) $time
                        } else {
                            set local_result(mEndTimeControl) false
                        }
                    }
                }
                "randomizationControls" {
                    if { [$child hasAttribute randomizationTiming] } {
                        set timing [$child getAttribute randomizationTiming]
                        # check vocabulary (according to ilias)
                        switch $timing {
                            onEachNewAttempt - once - never {
                                set local_result(mRandomTiming) $timing
                            }
                            default {
                                set local_result(mSelectTiming) never
                            }
                        }
                    }
                    if { [$child hasAttribute selectCount] } {
                        set count [$child getAttribute selectCount]
                        if { $count >= 0 } {
                            set local_result(mSelectStatus) true
                            set local_result(mSelectCount) $count
                        } else {
                            set local_result(mSelectStatus) false
                        }
                    }
                    if { [$child hasAttribute reorderChildren] } {
                        set local_result(mReorder) \
                            [convert_to_bool [$child hasAttribute reorderChildren]]
                    }
                    if { [$child hasAttribute selectionTiming] } {
                        set timing [$child getAttribute selectionTiming]
                        # check vocabulary (according to ilias)
                        switch $timing {
                            onEachNewAttempt - once - never {
                                set local_result(mSelectTiming) $timing
                            }
                            default {
                                set local_result(mSelectTiming) never
                            }
                        }
                    }
                }
                "deliveryControls" {
                    if { [$child hasAttribute tracked] } {
                        set local_result(mIsTracked) \
                            [convert_to_bool [$child getAttribute tracked]]
                    }
                    if { [$child hasAttribute completionSetByContent] } {
                        set local_result(mContentSetsCompletion) \
                            [convert_to_bool [$child getAttribute completionSetByContent]]
                    }
                    if { [$child hasAttribute objectiveSetByContent] } {
                        set local_result(mContentSetsObj) \
                            [convert_to_bool [$child getAttribute objectiveSetByContent]]
                    }
                }
                "constrainedChoiceConsiderations" {
                    if { [$child hasAttribute preventActivation] } {
                        set local_result(mPreventActivation) \
                            [convert_to_bool [$child getAttribute preventActivation]]
                    }
                    if { [$child hasAttribute constrainChoice] } {
                        set local_result(mConstrainChoice) \
                            [convert_to_bool [$child getAttribute constrainChoice]]
                    }
                }
                "rollupConsiderations" {
                    if { [$child hasAttribute requiredForSatisfied] } {
                        set local_result(mRequiredForSatisfied) [$child getAttribute requiredForSatisfied]
                    }
                    if { [$child hasAttribute requiredForNotSatisfied] } {
                        set local_result(mRequiredForNotSatisfied) [$child getAttribute requiredForNotSatisfied]
                    }
                    if { [$child hasAttribute requiredForCompleted] } {
                        set local_result(mRequiredForCompleted) [$child getAttribute requiredForCompleted]
                    }
                    if { [$child hasAttribute requiredForIncomplete] } {
                        set local_result(mRequiredForImcomplete) [$child getAttribute requiredForIncomplete]
                    }
                    if { [$child hasAttribute measureSatisfactionIfActive] } {
                        set local_result(mActiveMeasure) \
                            [convert_to_bool [$child getAttribute measureSatisfactionIfActive]]
                    }
                }
            }
        }
    }
}

#
# Objectives
#

ad_proc scorm_core::rte_activity_tree::get_objectives {
    -node:required
    -result:required
} {

    upvar $result local_result

    set objectives [list]
    set shortcuts [list]
    foreach child [$node childNodes] {
        if { [$child nodeType] eq "ELEMENT_NODE" } {
            if { [$child localName] eq "primaryObjective" || [$child localName] eq "objective" } {
                lappend objectives \
                    [scorm_core::rte_activity_tree::seq_objective -node $child]
                # to build a json object, we need one big list
                set shortcuts \
                    [concat $shortcuts \
                         [scorm_core::rte_activity_tree::objective_map_shortcut \
                              -node $child]]
            }
        }
    }

    if { [llength $objectives] } {
        set local_result(mObjectives) [util::json::array::create $objectives]
    } else {
        set local_result(mObjectives) null
    }

    if { [llength $shortcuts] } {
        set local_result(mObjMaps) [util::json::object::create $shortcuts]
    } else {
        set local_result(mObjMaps) null
    }

}

ad_proc scorm_core::rte_activity_tree::seq_objective {
    -node:required
} {

    # default objective object
    array set objective [scorm_core::rte_activity_tree::objective_attributes]

    if { [$node localName] eq "primaryObjective" } {
        set objective(mContributesToRollup) true
    }
    if { [$node hasAttribute "objectiveID"] } {
        set objective(mObjID) [$node getAttribute "objectiveID"]
    }
    if { [$node hasAttribute "satisfiedByMeasure"] } {
        set objective(mSatisfiedByMeasure) \
            [scorm_core::rte_activity_tree::convert_to_bool \
                [$node getAttribute "satisfiedByMeasure"]]
    }
    set mnms [$node getElementsByTagName "imsss:minNormalizedMeasure"]
    if { [llength $mnms] == 1 } {
        set objective(mMinMeasure) [$mnms text]
    } elseif { [llength $mnms] > 1 } {
        return -code error "More than one minNormalizedMeasure element detected for seq object"
    }

    set maps [list]
    foreach child [$node getElementsByTagName "imsss:mapInfo"] {
        lappend maps \
            [scorm_core::rte_activity_tree::seq_objective_map -node $child]
    }          

    if { [llength $maps] } {
        set objective(mMaps) [util::json::array::create $maps]
    } else {
        set objective(mMaps) null
    }

    return \
        [util::json::object::create \
             [list _SeqObjective \
                 [util::json::object::create [array get objective]]]]

}

ad_proc scorm_core::rte_activity_tree::objective_map_shortcut {
    -node:required
} {

    set maps [list]
    if { [$node hasAttribute "objectiveID"] } {
        set objective_id [$node getAttribute "objectiveID"]
    }

    foreach child [$node getElementsByTagName "imsss:mapInfo"] {
        lappend maps \
            [scorm_core::rte_activity_tree::seq_objective_map -node $child]
    }

    if { [llength $maps] } {
        return [list $objective_id \
                    [util::json::array::create $maps]]
    } else {
        return ""
    }
}

ad_proc scorm_core::rte_activity_tree::seq_objective_map {
    -node:required
} {

    # default map object
    array set map [scorm_core::rte_activity_tree::map_attributes]

    if { [$node hasAttribute "targetObjectiveID"] } {
        set map(mGlobalObjID) [$node getAttribute "targetObjectiveID"]
    }
    if { [$node hasAttribute "readSatisfiedStatus"] } {
        set map(mReadStatus) [$node getAttribute "readSatisfiedStatus"]
    }
    if { [$node hasAttribute "readNormalizedMeasure"] } {
        set map(mReadMeasure) [$node getAttribute "readNormalizedMeasure"]
    }
    if { [$node hasAttribute "writeSatisfiedStatus"] } {
        set map(mWriteStatus) [$node getAttribute "writeSatisfiedStatus"]
    }
    if { [$node hasAttribute "writeNormalizedMeasure"] } {
        set map(mWriteMeasure) [$node getAttribute "writeNormalizedMeasure"]
    }

    return \
        [util::json::object::create \
            [list _SeqObjectiveMap \
                [util::json::object::create [array get map]]]]
}

#
# Sequencing Rules
#

ad_proc scorm_core::rte_activity_tree::get_sequencing_rules {
    -node:required
    -result:required
} {

    upvar $result local_result

    set pre_rules [list]
    set exit_rules [list]
    set post_rules [list]

    foreach child [$node childNodes] {
        if { [$child nodeType] eq "ELEMENT_NODE" } {
            switch [$child localName] {
                "preConditionRule" {
                    lappend pre_rules \
                        [scorm_core::rte_activity_tree::seq_rule -node $child]
                }
                "exitConditionRule" {
                    lappend exit_rules \
                        [scorm_core::rte_activity_tree::seq_rule -node $child]
                }
                "postConditionRule" {
                    lappend post_rules \
                        [scorm_core::rte_activity_tree::seq_rule -node $child]
                }
            }          
        }
    }

    # nothing in a _SeqRuleset object except mRules so we create everything here
    if { [llength $pre_rules] } {
        set local_result(mPreConditionRules) \
            [util::json::object::create \
                 [list _SeqRuleset \
                      [util::json::object::create \
                           [list mRules \
                                [util::json::array::create $pre_rules]]]]]
    } else {
        set local_result(mPreConditionRules) null
    }

    if { [llength $exit_rules] } {
        set local_result(mExitActionRules) \
            [util::json::object::create \
                 [list _SeqRuleset \
                      [util::json::object::create \
                           [list mRules \
                                [util::json::array::create $exit_rules]]]]]
    } else {
        set local_result(mExitActionRules) null
    }

    if { [llength $post_rules] } {
        set local_result(mPostConditionRules) \
            [util::json::object::create \
                 [list _SeqRuleset \
                      [util::json::object::create \
                           [list mRules \
                                [util::json::array::create $post_rules]]]]]
    } else {
        set local_result(mPostConditionRules) null
    }
    
}

ad_proc scorm_core::rte_activity_tree::seq_rule {
    -node:required
} {
    array set rule [scorm_core::rte_activity_tree::seq_rule_attributes]

    set condition_sets [list]
    foreach child [$node childNodes] {
        if { [$child nodeType] eq "ELEMENT_NODE" } {
            switch [$child localName] {
                "ruleConditions" {
                    # concat rather than append - since we're making a json object, we need one long list
                    set condition_sets \
                        [concat $condition_sets \
                             [scorm_core::rte_activity_tree::seq_condition_set \
                                  -node $child -rule_type "sequencing"]]
                }
                "ruleAction" {
                    if { [$child hasAttribute "action"] } {
                        set rule(mAction) [$child getAttribute "action"]
                    }
                }
            }
        }
    }

    if { [llength $condition_sets] } {
        set rule(mConditions) \
            [util::json::object::create \
                 [list _SeqConditionSet $condition_sets]]
    } else {
        set rule(mConditions) null
    }

    return \
        [util::json::object::create \
            [list _SeqRule \
                [util::json::object::create [array get rule]]]]
}


#
# Rollup Rules
#

ad_proc scorm_core::rte_activity_tree::get_rollup_rules {
    -node:required
    -result:required
} {

    upvar $result local_result

    if { [$node hasAttribute "rollupObjectiveSatisfied"] } {
        set local_result(mIsObjectiveRolledUp) [$node getAttribute "rollupObjectiveSatisfied"]
    }
    if { [$node hasAttribute "objectiveMeasureWeight"] } {
        set local_result(mObjMeasureWeight) [$node getAttribute "objectiveMeasureWeight"]
    }
    if { [$node hasAttribute "rollupProgressCompletion"] } {
        set local_result(mIsProgressRolledUp) [$node getAttribute "rollupProgressCompletion"]
    }

    array set rollup_ruleset [scorm_core::rte_activity_tree::rollup_ruleset_attributes]

    set rollup_rules [list]
    foreach child [$node getElementsByTagName "imsss:rollupRule"] {
        lappend rollup_rules \
            [scorm_core::rte_activity_tree::seq_rollup_rule -node $child]
    }

    if { [llength $rollup_rules] } {
        set rollup_ruleset(mRollupRules) [util::json::array::create $rollup_rules]
        set local_result(mRollupRules) \
            [util::json::object::create \
                 [list _SeqRollupRuleset \
                      [util::json::object::create \
                           [array get rollup_ruleset]]]]
    } else {
        set local_result(mRollupRules) null
    }
}

ad_proc scorm_core::rte_activity_tree::seq_rollup_rule {
    -node:required
} {

    # default rule object
    array set rule [scorm_core::rte_activity_tree::rollup_rule_attributes]

    if { [$node hasAttribute "childActivitySet"] } {
        set rule(mChildActivitySet) [$node getAttribute "childActivitySet"]
    }
    if { [$node hasAttribute "minimumCount"] } {
        set rule(mMinCount) [$node getAttribute "minimumCount"]
    }
    if { [$node hasAttribute "minimumPercent"] } {
        set rule(mMinPercent) [$node getAttribute "minimumPercent"]
    }

    set condition_sets [list]
    foreach child [$node childNodes] {
        if { [$child nodeType] eq "ELEMENT_NODE" } {
            switch [$child localName] {
                "rollupConditions" {
                    # concat rather than append - since we're making a json object, we need one long list
                    set condition_sets \
                        [concat $condition_sets \
                             [scorm_core::rte_activity_tree::seq_condition_set \
                                  -node $child -rule_type "rollup"]]
                }
                "rollupAction" {
                    if { [$child hasAttribute "action"] } {
                        switch [$child getAttribute "action"] {
                            "satisfied" {
                                set rule(mAction) 1
                            }
                            "notSatisfied" {
                                set rule(mAction) 2
                            }
                            "completed" {
                                set rule(mAction) 3
                            }
                            "incomplete" {
                                set rule(mAction) 4
                            }
                        }
                    }
                }
            }
        }
    }

    if { [llength $condition_sets] } {
        set rule(mConditions) \
            [util::json::object::create \
                 [list _SeqConditionSet $condition_sets]]
    } else {
        set rule(mConditions) null
    }

    return \
        [util::json::object::create \
            [list _SeqRollupRule \
                [util::json::object::create [array get rule]]]]

}

#
# Conditions
#

ad_proc scorm_core::rte_activity_tree::seq_condition_set {
    -node:required
    -rule_type:required
} {

    array set condition_set [scorm_core::rte_activity_tree::condition_set_attributes]

    switch $rule_type {
        "sequencing" {
            set condition_set(mRollup) false
            set condition_set(mCombination) all
            set tag_name "imsss:ruleCondition"
        }
        "rollup" {
            set condition_set(mRollup) true
            set condition_set(mCombination) any
            set tag_name "imsss:rollupCondition"
        }
    }

    # override with manifest data if exists
    if { [$node hasAttribute "conditionCombination"] } {
        set condition_set(mCombination) [$node getAttribute "conditionCombination"]
    }

    set conditions [list]
    foreach child [$node getElementsByTagName $tag_name] {
        lappend conditions \
            [scorm_core::rte_activity_tree::seq_condition \
                 -node $child -rule_type $rule_type]
    }

    if { [llength $conditions] } {
        set condition_set(mConditions) [util::json::array::create $conditions]
    } else {
        set condition_set(mConditions) null
    }

    return [util::json::object::create [array get condition_set]]

}

ad_proc scorm_core::rte_activity_tree::seq_condition {
    -node:required
    -rule_type:required
} {

    array set condition [scorm_core::rte_activity_tree::condition_attributes]
    if { [$node hasAttribute "condition"] } {
        set condition(mCondition) [$node getAttribute "condition"]
    }
    if { [$node hasAttribute "operator"] } {
        set condition(mNot) \
            [ad_decode [$node getAttribute "operator"] not true false]
    }

    if { $rule_type eq "sequencing" } {
        if { [$node hasAttribute "referencedObjective"] } {
            set condition(mObjID) [$node getAttribute "referencedObjective"]
        }
        if { [$node hasAttribute "measureThreshold"] } {
            set condition(mThreshold) [$node getAttribute "measureThreshold"]
        }
    }

    return \
        [util::json::object::create \
            [list _SeqCondition \
                [util::json::object::create [array get condition]]]]
}

#
# Auxiliary Resources
#

ad_proc scorm_core::rte_activity_tree::get_auxiliary_resources {
    -node:required
    -result:required
} {
    upvar $result local_result

    set resources [list]
    foreach child [$node getElementsByTagName "auxiliaryResource"] {
        lappend resources \
            [scorm_core::rte_activity_tree::auxiliary_resource -node $child]
    }

    if { [llength $resources] } {
        set local_result(mAuxResources) \
            [util::json::object::create \
                 [list _ADLAuxiliaryResource \
                      [util::json::array::create $resources]]]
    } else {
        set local_result(mAuxResources) null
    }
}

ad_proc scorm_core::rte_activity_tree::auxiliary_resource {
    -node:required
} {

    array set resource [scorm_core::rte_activity_tree::auxiliary_resource_attributes]
    if { [$node hasAttribute "purpose"] } {
        set resource(mType) [$node getAttribute "purpose"]
    }
    if { [$node hasAttribute "auxiliaryResourceID"] } {
        set resource(mResourceID) [$node getAttribute "auxiliaryResourceID"]
    }
    return [util::json::object::create [array get resource]]
}

# helper proc (from ilias)
ad_proc scorm_core::rte_activity_tree::convert_to_bool {
    string
} {
    if { [string toupper $string] eq "FALSE" } {
      return false
    } else {
      return true
    }
}


# "object" constructors
ad_proc scorm_core::rte_activity_tree::objective_attributes { } {
    provide basic constructor for objectives
} {
    return {
        mObjID _primary_
        mSatisfiedByMeasure false
        mActiveMeasure true
        mMinMeasure 1.0
        mContributesToRollup false
    }
}

ad_proc scorm_core::rte_activity_tree::map_attributes { } {
    provide basic constructor for objective maps
} {
    return {
        mGlobalObjID null
        mReadStatus true
        mReadMeasure true
        mWriteStatus false
        mWriteMeasure false
    }
}

ad_proc scorm_core::rte_activity_tree::activity_attributes { } {
    constructor for activity
} {

    return {
        mPreConditionRules null
        mPostConditionRules null
        mExitActionRules null
        mXML null
        mDepth 0
        mCount -1
        mLearnerID _NULL_
        mScopeID null
        mActivityID null
        mResourceID null
        mStateID null
        mTitle null
        mIsVisible true
        mOrder -1
        mActiveOrder -1
        mSelected true
        mParent null
        mIsActive false
        mIsSuspended false
        mChildren null
        mActiveChildren null
        mDeliveryMode normal
        mControl_choice true
        mControl_choiceExit true
        mControl_flow false
        mControl_forwardOnly false
        mConstrainChoice false
        mPreventActivation false
        mUseCurObj true
        mUseCurPro true
        mMaxAttemptControl false
        mMaxAttempt 0
        mAttemptAbDurControl false
        mAttemptAbDur null
        mAttemptExDurControl false
        mAttemptExDur null
        mActivityAbDurControl false
        mActivityAbDur null
        mActivityExDurControl false
        mActivityExDur null
        mBeginTimeControl false
        mBeginTime null
        mEndTimeControl false
        mEndTime null
        mAuxResources null
        mRollupRules null
        mActiveMeasure true
        mRequiredForSatisfied always
        mRequiredForNotSatisfied always
        mRequiredForCompleted always
        mRequiredForIncomplete always
        mObjectives null
        mObjMaps null
        mIsObjectiveRolledUp true
        mObjMeasureWeight 1.0
        mIsProgressRolledUp true
        mSelectTiming never
        mSelectStatus false
        mSelectCount 0
        mSelection false
        mRandomTiming never
        mReorder false
        mRandomized false
        mIsTracked true
        mContentSetsCompletion false
        mContentSetsObj false
        mCurTracking null
        mTracking null
        mNumAttempt 0
        mNumSCOAttempt 0
        mActivityAbDur_track null
        mActivityExDur_track null
    }
}

ad_proc scorm_core::rte_activity_tree::seq_rule_attributes { } {
    provide basic constructor for sequencing rule
} {
    return { 
        mAction ignore
        mConditions null
    }
}

ad_proc scorm_core::rte_activity_tree::rollup_rule_attributes { } {
    provide basic constructor for rollup rule
} {
    return { 
        mAction 1
        mChildActivitySet all
        mMinCount 0
        mMinPercent 0.0
        mConditions null
    }
}

ad_proc scorm_core::rte_activity_tree::rollup_ruleset_attributes { } {
    provide basic constructor for rollup rulesets
} {
    return {
        mRollupRules null
        mIsSatisfied false
        mIsNotSatisfied false
        mIsCompleted false
        mIsIncomplete false
    }
}

ad_proc scorm_core::rte_activity_tree::condition_set_attributes { } {
    provide basic constructor for sequence condition sets
} {
    return {
        mCombination null
        mConditions null
        mRetry false
        mRollup false
    }
}

ad_proc scorm_core::rte_activity_tree::condition_attributes { } {
    provide basic constructor for sequence conditions
} {
    return {
        mCondition null
        mNot false
        mObjID null
        mThreshold 0.0
    }
}

ad_proc scorm_core::rte_activity_tree::control_mode_attributes {
    -node:required
} {
    provide basic constructor for control mode
} {
    return {
        choice true
        flow true
    }
}

ad_proc scorm_core::rte_activity_tree::auxiliary_resource_attributes {
    -node:required
} {
    provide basic constructor for auxiliary resources
} {
    return {
        mType null
        mResourceID null
        mParameter null
    }
}
