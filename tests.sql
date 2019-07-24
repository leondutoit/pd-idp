
\set keep_test `echo "$KEEP_TEST_DATA"`
\set del_data `echo "$DELETE_EXISTING_DATA"`


create or replace function test_persons_users_groups()
    returns boolean as $$
    declare pid uuid;
    declare num int;
    begin
        insert into persons (given_names, surname, person_expiry_date)
            values ('Sarah', 'Conner', '2020-10-01');
        select person_id from persons where surname = 'Conner' into pid;
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-sconne', '2020-03-28');
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p66-sconne', '2019-12-01');
        -- creation
        assert (select count(*) from persons) = 1, 'person creation issue';
        assert (select count(*) from users) = 2, 'user creation issue';
        assert (select count(*) from groups) = 3, 'group creation issue';
        -- person attribute immutability
        begin
            update persons set row_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'row_id immutable';
        end;
        begin
            update persons set person_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'person_id immutable';
        end;
        begin
            update persons set person_group = 'e14c538a-4b8b-4393-9fb2-056e363899e1-group';
            assert false;
        exception when others then
            raise notice 'person_group immutable';
        end;
        -- user attribute immutability
        begin
            update users set row_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'row_id immutable';
        end;
        begin
            update users set user_id = 'a3981c7f-8e41-4222-9183-1815b6ec9c3b';
            assert false;
        exception when others then
            raise notice 'user_id immutable';
        end;
        begin
            update users set user_name = 'p11-scnr';
            assert false;
        exception when others then
            raise notice 'user_name immutable';
        end;
        begin
            update users set user_group = 'p11-s-group';
            assert false;
        exception when others then
            raise notice 'user_group immutable';
        end;
        -- group attribute immutability
        begin
            update groups set row_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'row_id immutable';
        end;
        begin
            update groups set group_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'group_id immutable';
        end;
        begin
            update groups set group_name = 'p22-lcd-group';
            assert false;
        exception when others then
            raise notice 'group_name immutable';
        end;
        begin
            update groups set group_class = 'secondary';
            assert false;
        exception when others then
            raise notice 'group_class immutable';
        end;
        begin
            update groups set group_type = 'person';
            assert false;
        exception when others then
            raise notice 'group_type immutable';
        end;
        -- states; cascades, constraints
        update persons set person_activated = 'f';
        assert (select count(*) from users where user_activated = 't') = 0,
            'person state changes not propagating to users';
        assert (select count(*) from groups where group_activated = 't') = 0,
            'person state changes not propagating to groups';
        -- try change group states, expect fail
        -- create secondary group, change state, delete it again
        -- expiry dates: cascades, constraints
        update persons set person_expiry_date = '2019-09-09';
        update users set user_expiry_date = '2000-08-08' where user_name like 'p11-%';
        begin
            update groups set group_expiry_date = '2000-01-01' where group_primary_member = 'p11-sconne';
            assert false;
        exception when others then
            raise notice 'primary group updates';
        end;
        -- deletion; cascades, constraints
        begin
            delete from groups where group_type = 'person';
        exception when others then
            raise notice 'person group deletion protected';
        end;
        begin
            delete from groups where group_type = 'user';
        exception when others then
            raise notice 'user group deletion protected';
        end;
        begin
            delete from groups where group_class = 'primary';
        exception when others then
            raise notice 'primary group deletion protected';
        end;
        delete from persons;
        assert (select count(*) from users) = 0, 'cascading delete from person to users not working';
        assert (select count(*) from groups) = 0, 'cascading delete from person to groups not working';
    return true;
    end;
$$ language plpgsql;


create or replace function test_group_memeberships_moderators()
    returns boolean as $$
    declare pid uuid;
    declare row record;
    begin
        -- create persons and users
        insert into persons (given_names, surname, person_expiry_date)
            values ('Sarah', 'Conner', '2020-10-01');
        select person_id from persons where surname = 'Conner' into pid;
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-sconne', '2020-03-28');
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p66-sconne', '2019-12-01');
        insert into persons (given_names, surname, person_expiry_date)
            values ('John', 'Conner2', '2020-10-01');
        select person_id from persons where surname = 'Conner2' into pid;
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-jconn', '2020-03-28');
        insert into persons (given_names, surname, person_expiry_date)
            values ('Frank', 'Castle', '2020-10-01');
        select person_id from persons where surname = 'Castle' into pid;
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-fcl', '2020-03-28');
        insert into persons (given_names, surname, person_expiry_date)
            values ('Virginia', 'Woolf', '2020-10-01');
        select person_id from persons where surname = 'Woolf' into pid;
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-vwf', '2020-03-28');
        insert into persons (given_names, surname, person_expiry_date)
            values ('David', 'Gilgamesh', '2020-10-01');
        select person_id from persons where surname = 'Gilgamesh' into pid;
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-dgmsh', '2020-03-28');
        -- create groups
        insert into groups (group_name, group_class, group_type)
            values ('p11-admin-group', 'secondary', 'generic');
        insert into groups (group_name, group_class, group_type)
            values ('p11-export-group', 'secondary', 'generic');
        insert into groups (group_name, group_class, group_type)
            values ('p11-publication-group', 'secondary', 'generic');
        insert into groups (group_name, group_class, group_type)
            values ('p11-clinical-group', 'secondary', 'generic');
        insert into groups (group_name, group_class, group_type)
            values ('p11-import-group', 'secondary', 'generic');
        insert into groups (group_name, group_class, group_type)
            values ('p11-special-group', 'secondary', 'generic');
        -- add members
        insert into group_memberships (group_name, group_member_name)
            values ('p11-export-group', 'p11-admin-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-export-group', 'p11-sconne-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-export-group', 'p11-jconn-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-export-group', 'p11-clinical-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-admin-group', 'p11-fcl-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-publication-group', 'p11-vwf-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-admin-group', 'p11-publication-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-clinical-group', 'p11-dgmsh-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-special-group', 'p11-import-group');
        /*
        This gives a valid group membership graph as follows:

            p11-export-group
                -> p11-sconne-group
                -> p11-jconn-group
                -> p11-clinical-group
                    -> p11-dgmsh-group
                -> p11-admin-group
                    -> p11-fcl-group
                    -> p11-publication-group
                        -> p11-vwf-group

        We should be able to resolve such DAGs, of arbitrary depth
        until we can report back the list of all group_primary_member(s).
        And optionally, the structure of the graph. In this case the list is:

            p11-sconne
            p11-jconn
            p11-dgmsh
            p11-fcl
            p11-vwf

        */
        raise notice 'group_name, group_member_name, group_class, group_type, group_primary_member';
        for row in select * from first_order_members loop
            raise notice '%', row;
        end loop;


        /* GROUP MEMBERS */

        -- referential constraints
        begin
            insert into group_moderators (group_name, group_member_name)
                values ('p77-clinical-group', 'p11-special-group');
            assert false;
        exception when others then
            raise notice 'group_memberships: referential constraints work';
        end;
        -- redundancy
        begin
            insert into group_memberships (group_name, group_member_name) values ('p11-export-group','p11-publication-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_memberships: redundancy check works';
        end;
        -- cyclicality
        begin
            insert into group_memberships (group_name, group_member_name) values ('p11-publication-group','p11-export-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_memberships: cyclicality check works';
        end;
        -- immutability
        begin
            update group_memberships set row_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'group_memberships: row_id immutable';
        end;
        begin
            update group_memberships set group_name = 'p11-clinical-group' where group_name = 'p11-special-group';
            assert false;
        exception when others then
            raise notice 'group_memberships: group_name immutable';
        end;
        begin
            update group_memberships set group_member_name = 'p11-clinical-group' where group_name = 'p11-special-group';
            assert false;
        exception when others then
            raise notice 'group_memberships: group_member_name immutable';
        end;
        -- group classes
        begin
            insert into group_memberships values ('p11-sconne-group', 'p11-special-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_memberships: primary groups cannot have new members';
        end;
        -- new relations and group activation state
        begin
            update groups set group_activated = 'f' where group_name = 'p11-import-group';
            insert into group_memberships (group_name, group_member_name) values ('p11-publication-group','p11-import-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_memberships: deactivated groups cannot be used in new relations';
        end;
        -- new relations and group expiry
        begin
            update groups set group_expiry_date = '2017-01-01' where group_name = 'p11-import-group';
            insert into group_memberships (group_name, group_member_name) values ('p11-publication-group','p11-import-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_memberships: expired groups cannot be used in new relations';
        end;
        -- shouldnt be able to be a member of itself
        begin
            insert into group_moderators (group_name, group_member_name)
                values ('p11-special-group', 'p11-special-group');
            assert false;
        exception when others then
            raise notice 'group_memberships: redundancy check - groups cannot be members of themselves';
        end;

        /* GROUP MODERATORS */

        insert into group_moderators (group_name, group_moderator_name)
            values ('p11-import-group', 'p11-admin-group');
        insert into group_moderators (group_name, group_moderator_name)
            values ('p11-clinical-group', 'p11-special-group');
        -- referential constraints
        begin
            insert into group_moderators (group_name, group_moderator_name)
                values ('p77-clinical-group', 'p11-special-group');
            assert false;
        exception when others then
            raise notice 'group_moderators: referential constraints work';
        end;
        -- immutability
        begin
            update group_moderators set row_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'group_moderators: row_id immutable';
        end;
        begin
            update group_moderators set group_name = 'p11-admin-group' where group_name = 'p11-import-group';
            assert false;
        exception when others then
            raise notice 'group_moderators: group_name immutable';
        end;
        begin
            update group_moderators set group_member_name = 'p11-export-group' where group_name = 'p11-import-group';
            assert false;
        exception when others then
            raise notice 'group_moderators: group_member_name immutable';
        end;
        -- redundancy
        begin
            insert into group_moderators (group_name, group_moderator_name)
                values ('p11-clinical-group', 'p11-special-group');
            assert false;
        exception when others then
            raise notice 'group_moderators: redundancy check works - cannot recreate existing relations';
        end;
        begin
            insert into group_moderators (group_name, group_moderator_name)
                values ('p11-clinical-group', 'p11-clinical-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_moderators: redundancy check works - groups cannot moderate themselves';
        end;
        -- cyclicality
        begin
            insert into group_moderators (group_name, group_moderator_name)
                values ('p11-special-group', 'p11-clinical-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_moderators: cyclicality check works';
        end;
        -- new relations and group activation state
        begin
            update groups set group_activated = 'f' where group_name = 'p11-export-group';
            insert into group_moderators (group_name, group_moderator_name)
                values ('p11-export-group', 'p11-admin-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_moderators: deactivated groups cannot be used';
        end;
        -- new relations and group expiry
        begin
            update groups set group_expiry_date = '2011-01-01' where group_name = 'p11-export-group';
            insert into group_moderators (group_name, group_moderator_name)
                values ('p11-export-group', 'p11-admin-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_moderators: expired groups cannot be used';
        end;
        update groups set group_expiry_date = '2011-01-01' where group_name = 'p11-export-group';
        --delete from persons;
        --delete from groups;
        return true;
    end;
$$ language plpgsql;


create or replace function test_capabilities_http()
    returns boolean as $$
    declare cid uuid;
    begin
        insert into capabilities_http (capability_name, capability_default_claims,
                                  capability_required_groups, capability_group_match_method,
                                  capability_lifetime, capability_description, capability_expiry_date)
            values ('p11import', '{"role": "p11_import_user"}',
                    '{"p11-export-group", "p11-special-group"}', 'exact',
                    '123', 'bla', current_date);
        insert into capabilities_http (capability_name, capability_default_claims,
                                  capability_required_groups, capability_group_match_method,
                                  capability_lifetime, capability_description, capability_expiry_date)
            values ('export', '{"role": "export_user"}',
                    '{"admin-group", "export-group"}', 'wildcard',
                    '123', 'bla', current_date);
        insert into capabilities_http (capability_name, capability_default_claims,
                                  capability_required_groups, capability_group_match_method,
                                  capability_lifetime, capability_description, capability_expiry_date)
            values ('admin', '{"role": "admin_user"}',
                    '{"admin-group", "special-group"}', 'wildcard',
                    '123', 'bla', current_date);
        -- immutability
        begin
            update capabilities_http set row_id = '35b77cf9-0a6f-49d7-83df-e388d75c4b0b';
            assert false;
        exception when assert_failure then
            raise notice 'capabilities_http: row_id immutable';
        end;
        begin
            update capabilities_http set capability_id = '35b77cf9-0a6f-49d7-83df-e388d75c4b0b';
            assert false;
        exception when assert_failure then
            raise notice 'capabilities_http: capability_id immutable';
        end;
        -- uniqueness
        begin
            insert into capabilities_http (capability_name, capability_default_claims,
                                  capability_required_groups, capability_group_match_method,
                                  capability_lifetime, capability_description, capability_expiry_date)
                values ('admin', '{"role": "admin_user"}',
                        '{"admin-group", "special-group"}', 'wildcard',
                        '123', 'bla', current_date);
            assert false;
        exception when others then
            raise notice 'capabilities_http: name uniqueness guaranteed';
        end;
        -- referential constraints
        begin
            insert into capabilities_http (capability_name, capability_default_claims,
                                  capability_required_groups, capability_group_match_method,
                                  capability_lifetime, capability_description, capability_expiry_date)
            values ('admin2', '{"role": "admin_user"}',
                    '{"admin2-group", "very-special-group"}', 'wildcard',
                    '123', 'bla', current_date);
            assert false;
        exception when assert_failure then
            raise notice 'capabilities_http: group must exist to be referenced in new capability';
        end;
        select capability_id from capabilities_http where capability_name = 'p11import' into cid;
        insert into capabilities_http_grants (capability_id, capability_name, capability_http_method, capability_uri_pattern)
            values (cid, 'p11import', 'PUT', '/p11/files');
        select capability_id from capabilities_http where capability_name = 'export' into cid;
        insert into capabilities_http_grants (capability_id, capability_name, capability_http_method, capability_uri_pattern)
            values (cid, 'export', 'GET', '/(.*)/export');
        select capability_id from capabilities_http where capability_name = 'admin' into cid;
        insert into capabilities_http_grants (capability_id, capability_name, capability_http_method, capability_uri_pattern)
            values (cid, 'admin', 'DELETE', '/(.*)/files');
        insert into capabilities_http_grants (capability_id, capability_name, capability_http_method, capability_uri_pattern)
            values (cid, 'admin', 'GET', '/(.*)/admin');
        -- immutability
        begin
            update capabilities_http_grants set row_id = '35b77cf9-0a6f-49d7-83df-e388d75c4b0b';
            assert false;
        exception when assert_failure then
            raise notice 'capabilities_http_grants: row_id immutable';
        end;
        begin
            update capabilities_http_grants set capability_id = '35b77cf9-0a6f-49d7-83df-e388d75c4b0b';
            assert false;
        exception when assert_failure then
            raise notice 'capabilities_http_grants: capability_id immutable';
        end;
        -- referential constraints
        begin
            insert into capabilities_http_grants (capability_id, capability_name, capability_http_method, capability_uri_pattern)
                values ('35b77cf9-0a6f-49d7-83df-e388d75c4b0b', 'admin', 'GET', '/(.*)/admin');
            assert false;
        exception when others then
            raise notice 'capabilities_http_grants: capability_id should reference entry in capabilities_http';
        end;
        begin
            insert into capabilities_http_grants (capability_id, capability_name, capability_http_method, capability_uri_pattern)
                values (cid, 'admin2', 'GET', '/(.*)/admin');
            assert false;
        exception when others then
            raise notice 'capabilities_http_grants: capability_name should refernce entry in capabilities_http';
        end;
        return true;
    end;
$$ language plpgsql;


create or replace function test_audit()
    returns boolean as $$
    declare pid uuid;
    declare rid uuid;
    declare msg text;
    begin
        select person_id from persons limit 1 into pid;
        select row_id from persons where person_id = pid into rid;
        update persons set person_activated = 'f' where person_id = pid;
        msg := 'audit_log does not work';
        assert (select old_data from audit_log where row_id = rid) = 'true', msg;
        assert (select new_data from audit_log where row_id = rid) = 'false', msg;
        assert (select table_name from audit_log where row_id = rid) = 'persons', msg;
        assert (select column_name from audit_log where row_id = rid) = 'person_activated', msg;
        return true;
    end;
$$ language plpgsql;


create or replace function test_funcs()
    returns boolean as $$
    declare data json;
    declare pgrp text;
    declare pid uuid;
    declare cid uuid;
    declare err text;
    declare ans text;
    begin
        -- person_groups
        insert into persons (given_names, surname, person_expiry_date)
            values ('Salvador', 'Dali', '2050-10-01');
        select person_group from persons where surname = 'Dali' into pgrp;
        insert into groups (group_name, group_class, group_type)
            values ('p11-surrealist-group', 'secondary', 'generic');
        select person_id from persons where surname = 'Dali' into pid;
        select group_member_add('p11-surrealist-group', pid::text) into ans;
        select json_array_elements(person_groups->'groups')
            from person_groups(pid::text) into data;
        err := 'person_groups issue';
        assert data->>'member_group' = 'p11-surrealist-group', err;
        assert data->>'member_name' = pgrp, err;
        assert data->>'group_activated' = 'true', err;
        assert data->>'group_expiry_date' is null, err;
        -- person_capabilities
        insert into capabilities_http (capability_name, capability_default_claims,
                                  capability_required_groups, capability_group_match_method,
                                  capability_lifetime, capability_description, capability_expiry_date)
            values ('p11-art', '{"role": "p11_art_user"}',
                    '{"p11-surrealist-group", "p11-admin-group"}', 'exact',
                    '123', 'bla', current_date);
        select capability_id from capabilities_http where capability_name = 'p11-art' into cid;
        insert into capabilities_http_grants (capability_id, capability_name, capability_http_method, capability_uri_pattern)
            values (cid, 'p11-art', 'GET', '/(.*)/art');
        select json_array_elements(person_capabilities) from
            person_capabilities(pid::text, 't') into data;
        err := 'person_capabilities issue';
        assert data->>'group' = 'p11-surrealist-group', err;
        assert json_array_elements_text(data->'capabilities_http') = 'p11-art', err;
        assert json_array_elements_text(data->'grants') is not null, err;
        -- person_access
        err := 'person_access issue';
        select person_access(pid::text) into data;
        assert data->'person_group_access' is not null, err;
        assert data->'user_group_access' is null, err;
        -- group_member_add (with a user)
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-dali', '2040-12-01');
        select group_member_add('p11-surrealist-group', 'p11-dali') into ans;
        assert (select count(*) from group_memberships where group_member_name = 'p11-dali-group') = 1, 'group_member_add issue';
        -- user_groups
        select json_array_elements(user_groups->'groups') from user_groups('p11-dali') into data;
        err := 'user_groups issue';
        assert data->>'member_name' = 'p11-dali-group', err;
        assert data->>'member_group' = 'p11-surrealist-group', err;
        assert data->>'group_activated' = 'true', err;
        assert data->>'group_expiry_date' is null, err;
        -- user_capabilities
        select json_array_elements(user_capabilities) from
            user_capabilities('p11-dali', 't') into data;
        assert data->>'group' = 'p11-surrealist-group', err;
        assert json_array_elements_text(data->'capabilities_http') = 'p11-art', err;
        assert json_array_elements_text(data->'grants') is not null, err;
        -- group_members
        insert into persons (given_names, surname, person_expiry_date)
            values ('Andre', 'Breton', '2050-10-01');
        select person_group from persons where surname = 'Breton' into pgrp;
        insert into groups (group_name, group_class, group_type)
            values ('p11-painter-group', 'secondary', 'generic');
        select person_id from persons where surname = 'Breton' into pid;
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-abtn', '2050-01-01');
        select group_member_add('p11-painter-group', 'p11-abtn') into ans;
        select group_member_add('p11-surrealist-group', 'p11-painter-group') into ans;
        select group_members('p11-surrealist-group') into data;
        select person_group from persons where surname = 'Dali' into pgrp;
        assert data->'direct_members'->0->>'group_member' = pgrp;
        assert data->'direct_members'->1->>'group_member' = 'p11-dali-group';
        assert data->'direct_members'->2->>'group_member' = 'p11-painter-group';
        assert data->'transitive_members'->0->>'group' = 'p11-painter-group';
        assert data->'transitive_members'->0->>'group_member' = 'p11-abtn-group';
        assert data->'transitive_members'->0->>'primary_member' = 'p11-abtn';
        assert data->'transitive_members'->0->>'activated' = 'true';
        assert data->'transitive_members'->0->>'expiry_date' is null;
        select person_id from persons where surname = 'Dali' into pid;
        assert data->'ultimate_members'->>0 = pid::text;
        assert data->'ultimate_members'->>1 = 'p11-abtn';
        assert data->'ultimate_members'->>2 = 'p11-dali';
        -- group_member_remove
        select group_member_remove('p11-surrealist-group', 'p11-dali') into ans;
        assert (select count(*) from group_memberships
                where group_member_name = 'p11-dali-group'
                and group_name = 'p11-surrealist-group') = 0,
            'group_member_remove issue';
        -- group_capabilities
        select group_capabilities('p11-surrealist-group') into data;
        assert data->'capabilities_http'->>0 = 'p11-art';
        -- capability_grants
        select capability_grants('p11-art') into data;
        assert data->0->>'http_method' = 'GET';
        assert data->0->>'uri_pattern' = '/(.*)/art';
        return true;
    end;
$$ language plpgsql;


create or replace function test_cascading_deletes(keep_data boolean)
    returns boolean as $$
    begin
        if keep_data = 'true' then
            -- if KEEP_TEST_DATA is set to true this will not run
            -- this can be handlt for keeping test data in the DB
            -- for interactive test and dev purposes
            raise info 'Keeping test data';
            return true;
        end if;
        -- otherwise we delete all of it, and check test_cascading_deletes
        raise info 'deleting existing data';
        delete from persons;
        delete from groups;
        delete from audit_log;
        delete from capabilities_http;
        return true;
    end;
$$ language plpgsql;


create or replace function check_no_data(del_existing boolean)
    returns boolean as $$
    declare ans boolean;
    begin
        -- by default, tests can only be run when _all_ tables are empty
        -- to help mitigate a tragic production accident
        if del_existing = 'true' then
            select test_cascading_deletes(false) into ans;
        end if;
        assert (select count(*) from persons) = 0, 'persons not empty';
        assert (select count(*) from users) = 0, 'users not empty';
        assert (select count(*) from groups) = 0, 'groups not empty';
        assert (select count(*) from capabilities_http) = 0, 'capabilities_http not empty';
        return true;
    end;
$$ language plpgsql;


select check_no_data(:del_data);
select test_persons_users_groups();
select test_group_memeberships_moderators();
select test_capabilities_http();
select test_audit();
select test_funcs();
select test_cascading_deletes(:keep_test);

drop function if exists check_no_data(boolean);
drop function if exists test_persons_users_groups();
drop function if exists test_group_memeberships_moderators();
drop function if exists test_capabilities_http();
drop function if exists test_audit();
drop function if exists test_funcs();
drop function if exists test_cascading_deletes(boolean);
