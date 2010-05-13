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

</queryset>
