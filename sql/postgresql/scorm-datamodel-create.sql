-- This file defines the datamodel used by the RTE for persistent storage.  They
-- don't need to be acs objects and are taken directly from ilias, with referential
-- integrity constraints added for sanity's sake and to reinforce the notion that
-- MYSQL+MyISAM sucks.

-- cp_package references scorm_courses but probably doesn't need to be an object itself.
-- If we need it to be in the future, we can always create this as a subtype of
-- scorm_course.

create table cp_package (
 cp_package_id           integer
                         constraint cp_package_cp_package_id_fk
                         references scorm_courses
                         on delete cascade
                         constraint cp_package_obj_id_pk
                         primary key,
 c_identifier            text,
 jsdata                  text,
 activitytree            text,
 global_to_system        boolean,
 persistpreviousattempts integer,
 c_settings              text,
 xmldata                 text
);

create index cp_package_identifier_idx on cp_package (c_identifier);

-- This sequence isn't strictly necessary but it makes the cp_tree easier to
-- read (for humans).

create sequence cp_node_seq;

create table cp_node (
 cp_node_id  integer
             constraint cp_node_cp_node_id_pk
             primary key,
 nodename    text,
 cp_package_id integer
             constraint cp_node_cp_package_id_fk
             references cp_package
             on delete cascade
);

create index cp_node_nodename_idx on cp_node (nodename);

create table cp_sequencing (
 cp_node_id                             integer
                                        constraint cp_sequencing_cp_node_id_fk
                                        references cp_node (cp_node_id)
                                        on delete cascade
                                        constraint cp_sequencing_cp_node_id_pk
                                        primary key,
 sequencingid                           text,
 activityabsolutedurationlimit          text,
 activityexperienceddurationlimit       text,
 attemptabsolutedurationlimit           text,
 attemptexperienceddurationlimit        text,
 attemptlimit                           integer,
 begintimelimit	                        text,
 choice                                 boolean,
 choiceexit                             boolean,
 completionsetbycontent                 boolean,
 constrainchoice                        boolean,
 endtimelimit                           text,
 flow                                   boolean,
 forwardonly                            boolean,
 id                                     text,
 measuresatisfactionifactive            boolean,
 objectivemeasureweight                 real,
 objectivesetbycontent                  boolean,
 preventactivation                      boolean,
 randomizationtiming                    text,
 reorderchildren                        boolean,
 requiredforcompleted                   text,
 requiredforincomplete                  text,
 requiredfornotsatisfied                text,
 requiredsatisfied                      text,
 rollupobjectivesatisfied               boolean,
 rollupprogresscompletion               boolean,
 selectcount                            boolean,
 selectiontiming                        text,
 tracked                                boolean,
 usecurrentattemptobjectiveinfo         boolean,
 usecurrentattemptprogressinfo          boolean
);

create index cp_sequencing_id_idx on cp_sequencing(id);

create table cp_hidelmsui (
 cp_node_id  integer
             constraint cp_hidelmsui_fk
             references cp_node (cp_node_id)
             on delete cascade,
 value       text
);

create index cp_hidelmsui_ss_sequencing_id_idx on cp_hidelmsui (value);

create table cp_auxilaryresource (
 cp_node_id                      integer
                                 constraint cp_auxilaryresource_cp_node_id_fk
                                 references cp_node (cp_node_id)
                                 on delete cascade,
 auxiliaryresourceid             text,
 purpose                         text
);

create table cp_objective (
 cp_node_id               integer
                          constraint cp_objective_cp_node_id_fk
                          references cp_node (cp_node_id)
                          on delete cascade
                          constraint cp_objective_cp_node_id_pk
                          primary key,
 minnormalizedmeasure     text,
 objectiveid              text,
 c_primary                boolean,
 satisfiedbymeasure       boolean
);

create table cp_condition (
 cp_node_id               integer
                          constraint cp_condition_cp_node_id_fk
                          references cp_node (cp_node_id)
                          on delete cascade
                          constraint cp_condition_cp_node_id_pk
                          primary key,
 c_condition              text,
 measurethreshold         text,
 c_operator	              text,
 referencedobjective      text
);

create table cp_dependency (
 cp_node_id  integer
             constraint cp_dependency_cp_node_id_fk
             references cp_node (cp_node_id)
             on delete cascade
             constraint cp_dependency_cp_node_id_pk
             primary key,
 resourceid  text
);

create index cp_dependency_identifierref_idx on cp_dependency (resourceid);

create table cp_file (
 cp_node_id  integer
             constraint cp_file_cp_node_id_fk
             references cp_node (cp_node_id)
             on delete cascade
             constraint cp_file_cp_node_id_pk
             primary key,
 href        text
);

create table cp_item (
 cp_node_id             integer
                        constraint cp_item_cp_node_id_fk
                        references cp_node (cp_node_id)
                        on delete cascade
                        constraint cp_item_cp_node_id_pk
                        primary key,
 completionthreshold    text,
 datafromlms            text,
 id                     text,
 isvisible              text,
 parameters             text,
 resourceid             text,
 sequencingid           text,
 timelimitaction        text,
 title                  text
);

create index cp_item_id_idx on cp_item (id);
create index cp_item_ss_sequencing_id_idx on cp_item (sequencingid);

create table cp_resource (
 cp_node_id  integer
              constraint cp_resource_cp_node_id_fk
              references cp_node (cp_node_id)
              on delete cascade
              constraint cp_resource_cp_node_id_pk
              primary key,
 base         text,
 href         text,
 id           text,
 scormtype    text,
 c_type       text
);

create index cp_resource_import_id_idx on cp_resource (id);

create table cp_manifest (
 cp_node_id              integer
                         constraint cp_manifest_cp_node_id_fk
                         references cp_node (cp_node_id)
                         on delete cascade
                         constraint cp_manifest_cp_node_id_pk
                         primary key,
 base                    text,
 defaultorganization     text,
 id                      text,
 title                   text,
 uri                     text,
 version                 text
);

create index cp_manifest_id_idx on cp_manifest (id);

create table cp_mapinfo (
 cp_node_id             integer
                        constraint cp_mapinfo_cp_node_id_fk
                        references cp_node (cp_node_id)
                        on delete cascade
                        constraint cp_mapinfo_cp_node_id_pk
                        primary key,
 readnormalizedmeasure  boolean,
 readsatisfiedstatus    boolean,
 targetobjectiveid      text,
 writenormalizedmeasure boolean,
 writesatisfiedstatus   boolean
);

create index cp_mapinfo_targetobjectiveid_idx on cp_mapinfo (targetobjectiveid);

create table cp_organization (
 cp_node_id                  integer
                             constraint cp_organization_cp_node_id_fk
                             references cp_node (cp_node_id)
                             on delete cascade
                             constraint cp_organization_cp_node_id_pk
                             primary key,
 id                          text,
 objectivesglobaltosys       boolean,
 sequencingid                text,
 structure                   text,
 title                       text
);

create index cp_organization_id_idx on cp_organization (id);
create index cp_organization_ss_sequencing_id on cp_organization (sequencingid);

create table cp_rule (
 cp_node_id             integer
                        constraint cp_rule_cp_node_id_fk
                        references cp_node (cp_node_id)
                        on delete cascade  
                        constraint cp_rule_cp_node_id_pk
                        primary key,
 action              	text,
 childactivityset       text,
 conditioncombination	text,
 minimumcount           integer,
 minimumpercent         text,
 c_type                 text
);

create table cp_tree (
 child         integer
               constraint cp_tree_child_fk
               references cp_node
               on delete cascade,
 depth         integer,
 cp_package_id integer
               constraint cp_tree_cp_package_id_fk
               references cp_package
               on delete cascade,
 parent        integer,
 rgt           integer
);

create index cp_tree_child_idx on cp_tree (child);
create index cp_tree_parent_idx on cp_tree (parent);
create index cp_tree_cp_package_id_idx on cp_tree (cp_package_id);

comment on table cp_tree is '
  To find all of the children of a node, execute the query:

  select children.child
  from cp_tree parent, cp_tree children
  where children.child between parent.child+1 and parent.rgt
    and children.cp_package_id = (the course id)
  order by children.child

  To restrict the query to the immediate children, add

  and children.parent = parent.child

  The restriction by course id is necessary because we do not guarantee that the
  nodes for a course are numbered consecutively (they will not be after a course
  is edited).
';

create table cp_suspend (
 user_id       integer
               constraint cp_suspend_user_id_fk
               references users
               on delete cascade,
 cp_package_id integer
               constraint cp_suspend_cp_package_id_fk
               references cp_package
               on delete cascade,
 constraint    cp_suspend_pk
               primary key (user_id, cp_package_id),
 data        text
);

create table lng_data (
 module      varchar(30)
             constraint lng_data_pk
             primary key,
 identifier  varchar(50),
 lang_key    varchar(2),
 value       text
);

create index lng_data_lang_key on lng_data (lang_key);

-- MS: was a circular key reference in orig (cmi_node_id was both autoincrement here 
-- and fk to cmi_interactions, which in turn referenced this table)
create table cmi_node (
 cmi_node_id                    integer
                                constraint cmi_node_cmi_node_id_pk
                                primary key,
 cp_node_id                     integer
                                constraint cp_node_cp_node_id_fk
                                references cp_node (cp_node_id)
                                on delete cascade,
 accesscount                    integer,
 accessduration                 text,
 accessed                       text,
 activityabsoluteduration       text,
 activityattemptcount           integer,
 activityexperiencedduration    text,
 activityprogressstatus         integer,
 attemptabsoluteduration        text,
 attemptcompletionamount        real,
 attemptcompletionstatus        integer,
 attemptexperiencedduration     text,
 attemptprogressstatus          integer,
 audio_captioning               integer,
 audio_level                    real,
 availablechildren              text,
 completion                     real,
 completion_status              text,
 completion_threshold           text,
 created                        text,
 credit                         text,
 delivery_speed                 real,
 c_entry                        text,
 c_exit                         text,
 c_language                     text,
 launch_data                    text,
 learner_name                   text,
 location                       text,
 c_max                          real,
 c_min                          real,
 c_mode                         text,
 modified                       text,
 progress_measure               real,
 c_raw                          real,
 scaled                         real,
 scaled_passing_score           real,
 session_time                   text,
 success_status                 text,
 suspend_data                   text,
 total_time                     text,
 user_id                        integer
                                constraint cp_node_user_id_fk
                                references users
                                on delete cascade,
 c_timestamp                    timestamptz
);

create index cmi_node_cp_node_id_idx on cmi_node (cp_node_id);
create index cmi_node_completion_status_idx on cmi_node (completion_status);
create index cmi_node_credit_idx on cmi_node (credit);
create index cmi_node_cmi_node_id on cmi_node (cmi_node_id);
create index cmi_node_user_id on cmi_node (user_id);

create table cmi_interaction (
 cmi_interaction_id          integer
                             constraint cmi_interactions_interaction_id_pk
                             primary key,
 cmi_node_id                 integer
                             constraint cmi_interaction_cmi_node_id_fk
                             references cmi_node (cmi_node_id)
                             on delete cascade,
 description                 text,
 id                          text,
 latency                     text,
 learner_response            text,
 result                      text,
 c_timestamp                 timestamptz,
 c_type                      text,
 weighting                   real
);

create index cmi_interactions_id_idx on cmi_interaction (id);
create index cmi_interactions_type_idx on cmi_interaction (c_type);

create table cmi_correct_response (
 cmi_correct_response_id          integer
                                  constraint cmi_correct_responses_response_id_pk
                                  primary key,
 cmi_interaction_id               integer
                                  constraint cmi_correct_responses_interaction_id_fk
                                  references cmi_interaction (cmi_interaction_id)
                                  on delete cascade,
 pattern                          varchar(255)
);

create index cmi_correct_responses_interaction_id_idx on cmi_correct_response (cmi_interaction_id);

create table cmi_objective (
 cmi_objective_id          integer
                           constraint cmi_objective_objective_id_pk
                           primary key,
 cmi_interaction_id        integer
                           constraint cmi_objective_interaction_id_fk
                           references cmi_interaction (cmi_interaction_id)
                           on delete cascade,
 cmi_node_id               integer
                           constraint cmi_objective_cmi_node_id_fk
                           references cmi_node (cmi_node_id)
                           on delete cascade,
 completion_status         real,
 description               text,
 id                        varchar(255),
 c_max                     real,
 c_min                     real,
 c_raw                     real,
 scaled                    real,
 progress_measure          real,
 success_status            varchar(32),
 scope                     varchar(16)
);

create index cmi_objectives_interaction_id_idx on cmi_objective (cmi_interaction_id);
create index cmi_objectives_id_idx on cmi_objective (id);
create index cmi_objectives_success_status_idx on cmi_objective (success_status);

create table cmi_gobjective (
 user_id                    integer
                            constraint cmi_gobjective_user_id_fk
                            references users
                            on delete cascade,
 satisfied                  text,
 measure                    text,
 scope_id                   integer,
 status                     text,
 objective_id               text,
 constraint                 cmi_gobjective_pk
                            primary key (user_id, objective_id, scope_id)
);

create table cmi_comment (
 cmi_comment_id          integer
                         constraint cmi_comment_pk
                         primary key,
 cmi_node_id             integer
                         constraint cmi_comment_cmi_node_id_fk
                         references cmi_node (cmi_node_id)
                         on delete cascade,
 c_comment               text,
 c_timestamp             timestamptz,
 location                varchar(255),
 sourceislms             integer
);

create index cmi_comment_cmi_node_id_idx on cmi_comment(cmi_node_id);

-- scorm stuff? not part of scorm 2004 data model in ilias but is used
-- what is sco_id ????
create table scorm_tracking (
 user_id       integer
               constraint scorm_tracking_user_id_fk
               references users
               on delete cascade,
 cp_package_id integer
               constraint scorm_tracking_cp_package_id_fk
               references cp_package
               on delete cascade,
 sco_id        integer,
 c_timestamp   timestamptz,
 lvalue        text,
 rvalue        text,
 constraint    scorm_tracking_pk
               primary key (user_id, cp_package_id, sco_id, lvalue)
);

-- same for this table (wtf??)
create table cmi_custom (
 user_id       integer
               constraint cmi_custom_user_id_fk
               references users
               on delete cascade,
 cp_package_id integer
               constraint cmi_custom_cp_package_id_fk
               references cp_package
               on delete cascade,
 sco_id        integer,
 c_timestamp   timestamptz,
 lvalue        text,
 rvalue        text,
 constraint    cmi_custom_pk
               primary key (user_id, cp_package_id, sco_id, lvalue)
);
