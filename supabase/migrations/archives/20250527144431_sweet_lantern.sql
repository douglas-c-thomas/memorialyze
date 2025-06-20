/*
  # Initial Schema Setup for TimeStitch

  1. Tables
    - profiles: User profile information
    - family_groups: Family group management
    - group_members: Group membership and roles
    - group_invitations: Invitation system for groups

  2. Security
    - Row Level Security (RLS) enabled on all tables
    - Policies for user-specific access control
    - Secure role management with enum type

  3. Triggers
    - Automatic updated_at timestamp management
    - Automatic profile creation for new users
*/

-- Create custom types if they don't exist
DO $$ BEGIN
    CREATE TYPE group_role AS ENUM ('admin', 'contributor', 'viewer');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create profiles table if it doesn't exist
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users ON DELETE CASCADE,
    display_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS and create policies for profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Users can insert their own profile"
        ON profiles FOR INSERT TO authenticated
        WITH CHECK (auth.uid() = user_id);
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can update their own profile"
        ON profiles FOR UPDATE TO authenticated
        USING (auth.uid() = user_id);
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can view their own profile"
        ON profiles FOR SELECT TO authenticated
        USING (auth.uid() = user_id);
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Create family_groups table if it doesn't exist
CREATE TABLE IF NOT EXISTS family_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    created_by UUID NOT NULL REFERENCES auth.users,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS and create policies for family_groups
ALTER TABLE family_groups ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Authenticated users can create groups"
        ON family_groups FOR INSERT TO authenticated
        WITH CHECK (auth.uid() = created_by);
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Group admins can update groups"
        ON family_groups FOR UPDATE TO authenticated
        USING (EXISTS (
            SELECT 1 FROM group_members
            WHERE group_members.group_id = family_groups.id
            AND group_members.user_id = auth.uid()
            AND group_members.role = 'admin'
        ));
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Group members can view groups"
        ON family_groups FOR SELECT TO authenticated
        USING (EXISTS (
            SELECT 1 FROM group_members
            WHERE group_members.group_id = family_groups.id
            AND group_members.user_id = auth.uid()
        ));
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Create group_members table if it doesn't exist
CREATE TABLE IF NOT EXISTS group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES family_groups ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
    role group_role NOT NULL DEFAULT 'viewer',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(group_id, user_id)
);

-- Enable RLS and create policies for group_members
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Admins manage group members"
        ON group_members FOR ALL TO authenticated
        USING (user_id = auth.uid() AND role = 'admin');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can view own memberships"
        ON group_members FOR SELECT TO authenticated
        USING (user_id = auth.uid());
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "View members of joined groups"
        ON group_members FOR SELECT TO authenticated
        USING (EXISTS (
            SELECT 1 FROM group_members my_membership
            WHERE my_membership.group_id = group_members.group_id
            AND my_membership.user_id = auth.uid()
        ));
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Create group_invitations table if it doesn't exist
CREATE TABLE IF NOT EXISTS group_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES family_groups ON DELETE CASCADE,
    email TEXT NOT NULL,
    role group_role NOT NULL DEFAULT 'viewer',
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES auth.users
);

-- Enable RLS and create policies for group_invitations
ALTER TABLE group_invitations ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Group admins can manage invitations"
        ON group_invitations FOR ALL TO authenticated
        USING (EXISTS (
            SELECT 1 FROM group_members
            WHERE group_members.group_id = group_invitations.group_id
            AND group_members.user_id = auth.uid()
            AND group_members.role = 'admin'
        ));
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can view invitations sent to their email"
        ON group_invitations FOR SELECT TO authenticated
        USING (lower(email) = lower(auth.email()));
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Create triggers for updated_at columns
DO $$ BEGIN
    CREATE TRIGGER update_profiles_updated_at
        BEFORE UPDATE ON profiles
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TRIGGER update_family_groups_updated_at
        BEFORE UPDATE ON family_groups
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TRIGGER update_group_members_updated_at
        BEFORE UPDATE ON group_members
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Create trigger for new user profile
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (user_id)
    VALUES (NEW.id);
    RETURN NEW;
END;
$$ language 'plpgsql';

DO $$ BEGIN
    CREATE TRIGGER on_auth_user_created
        AFTER INSERT ON auth.users
        FOR EACH ROW
        EXECUTE FUNCTION handle_new_user();
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;