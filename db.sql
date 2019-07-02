
-- A generic DB backend for IDPs

-- a possible public SQL API
-- /rpc/person_create
-- /rpc/person_describe
-- /rpc/person_get
-- /rpc/person_set
-- /rpc/person_groups

-- /rpc/user_create
-- /rpc/user_describe
-- /rpc/user_get
-- /rpc/user_set
-- /rpc/user_groups

-- /rpc/group_create
-- /rpc/group_describe
-- /rpc/group_member_add
-- /rpc/group_member_remove
-- /rpc/group_list
-- /rpc/group_list_all
-- /rpc/group_moderator_add
-- /rpc/group_moderatr_remove


--create extension pgcrypto;

drop table if exists persons cascade;
create table if not exists persons(
    person_id uuid unique not null default gen_random_uuid(),
    person_activated boolean not null default 't',
    person_expiry_date date,
    person_group text,
    given_names text not null,
    surname text not null
    -- other info
    -- password?
    -- otp?
);

create or replace function person_management()
    returns trigger as $$
    declare new_pid text;
    declare new_pgrp text;
    begin
        if (TG_OP = 'INSERT') then
            if OLD.person_group is null then
                new_pgrp := NEW.person_id || '-group';
                update persons set person_group = new_pgrp where person_id = NEW.person_id;
                insert into groups (group_name, group_class, group_type, group_primary_member, group_desciption)
                    values (new_pgrp, 'primary', 'person', NEW.person_id, 'personal group');
            end if;
        elsif (TG_OP = 'DELETE') then
            delete from groups where group_name = OLD.person_group;
        elsif (TG_OP = 'UPDATE') then
            if OLD.person_activated != NEW.person_activated then
                update users set user_activated = NEW.person_activated where person_id = OLD.person_id;
                update groups set group_activated = NEW.person_activated where group_name = OLD.person_group;
                end if;
        end if;
    return new;
    end;
$$ language plpgsql;
create trigger person_group_trigger after insert or delete or update on persons
    for each row execute procedure person_management();

-- make fields immutable
-- propagate state changes to users, and person groups

drop table if exists users cascade;
create table if not exists users(
    person_id uuid not null references persons (person_id) on delete cascade,
    user_id uuid unique not null default gen_random_uuid(),
    user_activated boolean not null default 't',
    user_expiry_date date,
    user_name text unique not null,
    user_group text
    -- other info
);

create or replace function user_management()
    returns trigger as $$
    declare new_unam text;
    declare new_ugrp text;
    begin
        if (TG_OP = 'INSERT') then
            if OLD.user_group is null then
                new_ugrp := NEW.user_name || '-group';
                update users set user_group = new_ugrp where user_name = NEW.user_name;
                insert into groups (group_name, group_class, group_type, group_primary_member, group_desciption)
                    values (new_ugrp, 'primary', 'user', NEW.user_name, 'user group');
            end if;
        elsif (TG_OP = 'DELETE') then
            delete from groups where group_name = OLD.user_group;
        elsif (TG_OP = 'UPDATE') then
            if OLD.user_activated != NEW.user_activated then
                update groups set group_activated = NEW.user_activated where group_name = OLD.user_group;
            end if;
        end if;
    return new;
    end;
$$ language plpgsql;
create trigger user_group_trigger after insert or delete or update on users
    for each row execute procedure user_management();

-- make fields immutable

drop table if exists groups cascade;
create table if not exists groups(
    group_id uuid unique not null default gen_random_uuid(),
    group_activated boolean not null default 't',
    group_expiry_date date,
    group_name text unique not null,
    group_class text check (group_class in ('primary', 'secondary')),
    group_type text check (group_type in ('person', 'user', 'generic')),
    group_primary_member text,
    group_desciption text,
    group_metadata json
);
-- ensure only secondary groups can be deactivated here
-- primary groups are deactivated by decativating primary members

drop table if exists group_memberships cascade;
create table if not exists group_memberships(
    group_name text not null references groups (group_name) on delete cascade,
    group_member_name text not null references groups (group_name) on delete cascade,
    group_membership_expiry_date date,
    unique (group_name, group_member_name) -- cannot be member of itself
);
-- assert group_class == secondary
-- TODO: add constraint to prevent cyclical graphs
-- group_new_parent_is_child_of_new_child
-- group_get_children

drop table if exists group_moderators cascade;
create table if not exists group_moderators(
    group_name text not null references groups (group_name) on delete cascade,
    group_moderator_name text not null references groups (group_name) on delete cascade,
    group_moderator_description text,
    group_moderator_metadata json,
    group_moderator_expiry_date date
);
-- TODO: add constraint to prevent cyclical graphs
-- group_new_parent_is_child_of_new_child
-- group_get_children
-- group_get_parents
