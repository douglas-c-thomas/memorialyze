/*
  # Add user creation trigger

  1. Changes
    - Create trigger function to handle new user creation
    - Add trigger to auth.users table
    - Ensure profile creation on user signup

  2. Security
    - Function runs with security definer to ensure proper permissions
*/

-- Create a secure trigger function that creates a profile for new users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, display_name)
  VALUES (
    NEW.id,
    COALESCE(
      (NEW.raw_user_meta_data->>'display_name')::text,
      split_part(NEW.email, '@', 1)
    )
  );
  RETURN NEW;
END;
$$;

-- Create trigger on auth.users table
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();