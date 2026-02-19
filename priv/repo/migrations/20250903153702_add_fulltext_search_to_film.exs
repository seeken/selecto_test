defmodule SelectoTest.Repo.Migrations.AddFulltextSearchToFilm do
  use Ecto.Migration

  def up do
    # Add fulltext column to film table if it doesn't exist
    execute """
    ALTER TABLE film 
    ADD COLUMN IF NOT EXISTS fulltext tsvector 
    """

    # Create GiST index for full-text search performance
    execute """
    CREATE INDEX IF NOT EXISTS film_fulltext_idx 
    ON film USING gist(fulltext)
    """

    # Create trigger to automatically update fulltext column from title and description
    execute """
    CREATE OR REPLACE FUNCTION film_fulltext_trigger_func() 
    RETURNS trigger AS $$
    BEGIN
      NEW.fulltext := to_tsvector('pg_catalog.english', 
        COALESCE(NEW.title, '') || ' ' || COALESCE(NEW.description, ''));
      RETURN NEW;
    END
    $$ LANGUAGE plpgsql
    """

    # Drop existing trigger if it exists
    execute """
    DROP TRIGGER IF EXISTS film_fulltext_trigger ON film
    """

    # Create the trigger
    execute """
    CREATE TRIGGER film_fulltext_trigger
    BEFORE INSERT OR UPDATE ON film
    FOR EACH ROW
    EXECUTE FUNCTION film_fulltext_trigger_func()
    """

    # Update existing rows to populate the fulltext column
    execute """
    UPDATE film 
    SET fulltext = to_tsvector('pg_catalog.english', 
      COALESCE(title, '') || ' ' || COALESCE(description, ''))
    WHERE fulltext IS NULL
    """

    # Make the fulltext column NOT NULL after populating it
    execute """
    ALTER TABLE film 
    ALTER COLUMN fulltext SET NOT NULL
    """

    # Add default value for future inserts
    execute """
    ALTER TABLE film 
    ALTER COLUMN fulltext SET DEFAULT to_tsvector('english', '')
    """
  end

  def down do
    # Drop the trigger
    execute "DROP TRIGGER IF EXISTS film_fulltext_trigger ON film"

    # Drop the trigger function
    execute "DROP FUNCTION IF EXISTS film_fulltext_trigger_func()"

    # Drop the index
    execute "DROP INDEX IF EXISTS film_fulltext_idx"

    # Drop the column
    execute "ALTER TABLE film DROP COLUMN IF EXISTS fulltext"
  end
end
