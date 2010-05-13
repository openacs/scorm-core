
drop function scorm_course__new (integer,varchar,varchar,varchar,varchar,varchar,integer,varchar,integer,integer,varchar);

drop function scorm_course__delete (integer);

select acs_attribute__drop_attribute (
	'scorm_course',
	'scorm_course_id'
);

select acs_attribute__drop_attribute (
	'scorm_course',
	'auto_review'
);

select acs_attribute__drop_attribute (
	'scorm_course',
	'credit'
);

select acs_attribute__drop_attribute (
	'scorm_course',
	'default_lesson_mode'
);

select acs_attribute__drop_attribute (
	'scorm_course',
	'c_online'
);

select acs_attribute__drop_attribute (
	'scorm_course',
	'c_type'
);


select acs_attribute__drop_attribute (
	'scorm_course',
	'folder_id'
);

select acs_object_type__drop_type (
   'scorm_course',
   't'
);

drop table scorm_courses cascade;
