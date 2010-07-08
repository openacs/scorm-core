<?xml version="1.0"?>

<queryset>

    <fullquery name="scorm_core::default_folder_id.get_default_folder_id">
        <querytext>
          select folder_id
          from cr_folders, cr_items
          where parent_id = :package_id
            and package_id = :package_id
            and folder_id = item_id
        </querytext>
    </fullquery>

    <fullquery name="scorm_core::create_course.course_exists">
        <querytext>
          select 1
          from scorm_courses sc, acs_objects ao
          where sc.scorm_course_id = ao.object_id
            and ao.package_id = :package_id
            and ao.title = :title
        </querytext>
    </fullquery>

    <fullquery name="scorm_core::create_course.insert_package">
        <querytext>
          insert into cp_package
            (cp_package_id)
          values
            (:course_id)
        </querytext>
    </fullquery>

    <fullquery name="scorm_core::edit_course.delete_cp_nodes">
        <querytext>
          delete from cp_node
          where cp_package_id = :course_id
        </querytext>
    </fullquery>

    <fullquery name="scorm_core::delete_course.get_folder_id">
        <querytext>
          select folder_id
          from scorm_courses
          where scorm_course_id = :course_id
        </querytext>
    </fullquery>

    <fullquery name="scorm_core::update_rte_data.update_package">
        <querytext>
          update cp_package
          set jsdata = :jsdata,
            xmldata = :xmldata,
            activitytree = :activity_tree,
            global_to_system = :global_to_system
          where cp_package_id = :scorm_course_id
        </querytext>
    </fullquery>


    <fullquery name="scorm_core::get_manifest.get_manifest">
        <querytext>
          select xmldata
          from cp_package
          where cp_package_id = :course_id
        </querytext>
    </fullquery>

    <fullquery name="scorm_core::get_folder.get_folder">
        <querytext>
          select folder_id
          from scorm_courses
          where scorm_course_id = :course_id
        </querytext>
    </fullquery>

    <fullquery name="scorm_core::cp::create_node.insert_cp_node">
        <querytext>
          insert into cp_node
            (cp_node_id, nodename, cp_package_id)
          values
            (:cp_node_id, :nodename, :cp_package_id)
        </querytext>
    </fullquery>

    <fullquery name="scorm_core::cp::create_node.add_to_cp_tree">
        <querytext>
          insert into cp_tree
            (child, depth, cp_package_id, parent, rgt)
          values
            (:cp_node_id, :depth, :cp_package_id, :parent, '0')
        </querytext>
    </fullquery>

    <fullquery name="scorm_core::cp::create_node.insert_cp">
        <querytext>
          insert into cp_[string tolower ${nodename}]
            ([join $attributes ", "])
          values
            (:[join $attributes ", :"])
        </querytext>
    </fullquery>

    <fullquery name="scorm_core::cp::create_node.update_rgt">
        <querytext>
          update cp_tree
          set rgt = :rgt
          where child = :cp_node_id
        </querytext>
    </fullquery>

</queryset>
