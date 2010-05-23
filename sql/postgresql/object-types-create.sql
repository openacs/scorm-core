-- Define acs object types needed by our SCORM 2004 packages.

-- DRB: Note that ilias supports multiple course formats, while at the moment,
-- at least, we are only supporting SCORM 2004 (and perhaps 1.2 after conversion
-- to SCORM 2004, which appears to be possible).  I'm maintaining the two-table
-- and two-type structure from ilias in case we want to generalize our architecture
-- in the future to support something like AICC.  I'm making the assumption that
-- whatever format we might support consists of files stored in the CR.

-- There's no intention of showing type and attribute names at the moment so I'm
-- not localizing them for the moment ...

-- Several of these columns need check constraints once we figure out how the
-- data model is used in more detail.  Also, "n/y" should be boolean and "t/f" if
-- we can do so without touching the RTE (I believe everything in this table is
-- isolated from the RTE).

create table scorm_courses (
 scorm_course_id     integer
                     constraint scorm_courses_scorm_course_id_fk
                     references acs_objects
                     on delete cascade
                     constraint scorm_courses_scorm_course_id_pk
                     primary key,
 auto_review         boolean default 'f',
 credit              varchar(10) default 'credit'
                     constraint scorm_courses_credit_ck
                     check (credit in ('credit', 'no_credit')),
 default_lesson_mode varchar(8) default 'normal'
                     constraint scorm_courses_default_lesson_mode_ck
                     check (default_lesson_mode in ('normal', 'browse')),
 online              boolean default 'f',
 type                text
                     constraint scorm_courses_type_ck
                     check (type in ('scorm', 'scorm2004')),
 folder_id           integer
                     constraint scorm_courses_folder_id_fk
                     references cr_folders
                     on delete cascade
                     constraint scorm_courses_folder_id_nn
                     not null
);

select acs_object_type__create_type (
   'scorm_course',
   'Scorm Course',
   'Scorm Courses',
   'acs_object',
   'scorm_courses',
   'scorm_course_id',
   'scorm_course',
   'f',
   'null',
   'null'
   );

select acs_attribute__create_attribute (
	'scorm_course',
	'scorm_course_id',
	'integer',
	'Scorm Course Id',
	'Scorm Course Id',
	null,
	null,
	null,
	1,
	1,
	null,
	'type_specific',
	'f'
	);

select acs_attribute__create_attribute (
	'scorm_course',
	'auto_review',
	'boolean',
	'Auto Review',
	'Auto Reviews',
	null,
	null,
	'n',
	1,
	1,
	null,
	'type_specific',
	'f'
	);


select acs_attribute__create_attribute (
	'scorm_course',
	'credit',
	'string',
	'Credit',
	'Credits',
	null,
	null,
	'credit',
	1,
	1,
	null,
	'type_specific',
	'f'
	);

select acs_attribute__create_attribute (
	'scorm_course',
	'default_lesson_mode',
	'string',
	'Default Lesson Mode',
	'Default Lesson Modes',
	null,
	null,
	'normal',
	1,
	1,
	null,
	'type_specific',
	'f'
	);

select acs_attribute__create_attribute (
	'scorm_course',
	'online',
	'boolean',
	'Online',
	'Onlines',
	null,
	null,
	'n',
	1,
	1,
	null,
	'type_specific',
	'f'
	);

select acs_attribute__create_attribute (
	'scorm_course',
	'type',
	'text',
	'Type',
	'Types',
	null,
	null,
	null,
	1,
	1,
	null,
	'type_specific',
	'f'
	);


select acs_attribute__create_attribute (
	'scorm_course',
	'folder_id',
	'integer',
	'Folder Id',
	'Folder Id',
	null,
	null,
	null,
	1,
	1,
	null,
	'type_specific',
	'f'
	);

select define_function_args('scorm_course__new','scorm_course_id,object_type;scorm_course,auto_review;f,credit;credit,default_lesson_mode;normal,online;f,type,folder_id,title,context_id,creation_user,creation_ip,package_id');

create or replace function scorm_course__new (integer,text,boolean,varchar,varchar,boolean,varchar,integer,varchar,integer,integer,varchar,integer)
returns integer as '
declare
  p_scorm_course_id      alias for $1;
  p_object_type          alias for $2;
  p_auto_review          alias for $3; 
  p_credit               alias for $4;  
  p_default_lesson_mode  alias for $5;  
  p_online               alias for $6;
  p_type                 alias for $7;
  p_folder_id            alias for $8;
  p_title                alias for $9;
  p_context_id           alias for $10;
  p_creation_user        alias for $11;
  p_creation_ip          alias for $12;
  p_package_id           alias for $13;
  v_scorm_course_id      scorm_courses.scorm_course_id%TYPE;
begin
    v_scorm_course_id := acs_object__new (
      p_scorm_course_id,
      p_object_type,
      now(),
      p_creation_user,
      p_creation_ip,
      p_context_id,
      ''t'',
      p_title,
      p_package_id
    );

    insert into scorm_courses
     (scorm_course_id, auto_review, credit, default_lesson_mode, online, type, folder_id)
    values
     (v_scorm_course_id, p_auto_review, p_credit, p_default_lesson_mode, p_online, p_type,
      p_folder_id);

    return v_scorm_course_id;
   
end;' language 'plpgsql';

select define_function_args('scorm_course__delete','scorm_course_id');
create or replace function scorm_course__delete (integer)
returns integer as '
declare
  p_scorm_course_id            alias for $1;  
begin
    PERFORM acs_object__delete(p_scorm_course_id);

    return 0; 
end;' language 'plpgsql';

