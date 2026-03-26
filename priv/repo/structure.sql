--
-- PostgreSQL database dump
--

\restrict rg0elzNot8GCe2OeIm2dN7XcZUmVl8eizTI0GhAcRdTd4bieELRlqZAfHzVwmy2

-- Dumped from database version 16.9 (Debian 16.9-1.pgdg120+1)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: bıgınt; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public."bıgınt" AS bigint;


--
-- Name: mpaa_rating; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.mpaa_rating AS ENUM (
    'G',
    'PG',
    'PG-13',
    'R',
    'NC-17'
);


--
-- Name: year; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.year AS integer
	CONSTRAINT year_check CHECK (((VALUE >= 1901) AND (VALUE <= 2155)));


--
-- Name: _group_concat(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._group_concat(text, text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
SELECT CASE
  WHEN $2 IS NULL THEN $1
  WHEN $1 IS NULL THEN $2
  ELSE $1 || ', ' || $2
END
$_$;


--
-- Name: film_fulltext_trigger_func(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.film_fulltext_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.fulltext := to_tsvector('pg_catalog.english', 
    COALESCE(NEW.title, '') || ' ' || COALESCE(NEW.description, ''));
  RETURN NEW;
END
$$;


--
-- Name: film_in_stock(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.film_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) RETURNS SETOF integer
    LANGUAGE sql
    AS $_$
     SELECT inventory_id
     FROM inventory
     WHERE film_id = $1
     AND store_id = $2
     AND inventory_in_stock(inventory_id);
$_$;


--
-- Name: film_not_in_stock(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.film_not_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) RETURNS SETOF integer
    LANGUAGE sql
    AS $_$
    SELECT inventory_id
    FROM inventory
    WHERE film_id = $1
    AND store_id = $2
    AND NOT inventory_in_stock(inventory_id);
$_$;


--
-- Name: get_customer_balance(integer, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_customer_balance(p_customer_id integer, p_effective_date timestamp with time zone) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
       --#OK, WE NEED TO CALCULATE THE CURRENT BALANCE GIVEN A CUSTOMER_ID AND A DATE
       --#THAT WE WANT THE BALANCE TO BE EFFECTIVE FOR. THE BALANCE IS:
       --#   1) RENTAL FEES FOR ALL PREVIOUS RENTALS
       --#   2) ONE DOLLAR FOR EVERY DAY THE PREVIOUS RENTALS ARE OVERDUE
       --#   3) IF A FILM IS MORE THAN RENTAL_DURATION * 2 OVERDUE, CHARGE THE REPLACEMENT_COST
       --#   4) SUBTRACT ALL PAYMENTS MADE BEFORE THE DATE SPECIFIED
DECLARE
    v_rentfees DECIMAL(5,2); --#FEES PAID TO RENT THE VIDEOS INITIALLY
    v_overfees INTEGER;      --#LATE FEES FOR PRIOR RENTALS
    v_payments DECIMAL(5,2); --#SUM OF PAYMENTS MADE PREVIOUSLY
BEGIN
    SELECT COALESCE(SUM(film.rental_rate),0) INTO v_rentfees
    FROM film, inventory, rental
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

    SELECT COALESCE(SUM(IF((rental.return_date - rental.rental_date) > (film.rental_duration * '1 day'::interval),
        ((rental.return_date - rental.rental_date) - (film.rental_duration * '1 day'::interval)),0)),0) INTO v_overfees
    FROM rental, inventory, film
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

    SELECT COALESCE(SUM(payment.amount),0) INTO v_payments
    FROM payment
    WHERE payment.payment_date <= p_effective_date
    AND payment.customer_id = p_customer_id;

    RETURN v_rentfees + v_overfees - v_payments;
END
$$;


--
-- Name: inventory_held_by_customer(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inventory_held_by_customer(p_inventory_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_customer_id INTEGER;
BEGIN

  SELECT customer_id INTO v_customer_id
  FROM rental
  WHERE return_date IS NULL
  AND inventory_id = p_inventory_id;

  RETURN v_customer_id;
END $$;


--
-- Name: inventory_in_stock(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inventory_in_stock(p_inventory_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_rentals INTEGER;
    v_out     INTEGER;
BEGIN
    -- AN ITEM IS IN-STOCK IF THERE ARE EITHER NO ROWS IN THE rental TABLE
    -- FOR THE ITEM OR ALL ROWS HAVE return_date POPULATED

    SELECT count(*) INTO v_rentals
    FROM rental
    WHERE inventory_id = p_inventory_id;

    IF v_rentals = 0 THEN
      RETURN TRUE;
    END IF;

    SELECT COUNT(rental_id) INTO v_out
    FROM inventory LEFT JOIN rental USING(inventory_id)
    WHERE inventory.inventory_id = p_inventory_id
    AND rental.return_date IS NULL;

    IF v_out > 0 THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
END $$;


--
-- Name: last_day(timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.last_day(timestamp with time zone) RETURNS date
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
  SELECT CASE
    WHEN EXTRACT(MONTH FROM $1) = 12 THEN
      (((EXTRACT(YEAR FROM $1) + 1) operator(pg_catalog.||) '-01-01')::date - INTERVAL '1 day')::date
    ELSE
      ((EXTRACT(YEAR FROM $1) operator(pg_catalog.||) '-' operator(pg_catalog.||) (EXTRACT(MONTH FROM $1) + 1) operator(pg_catalog.||) '-01')::date - INTERVAL '1 day')::date
    END
$_$;


--
-- Name: last_updated(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.last_updated() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.last_update = CURRENT_TIMESTAMP;
    RETURN NEW;
END $$;


--
-- Name: customer_customer_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.customer_customer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: customer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer (
    customer_id integer DEFAULT nextval('public.customer_customer_id_seq'::regclass) NOT NULL,
    store_id integer NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    email text,
    address_id integer NOT NULL,
    activebool boolean DEFAULT true NOT NULL,
    create_date date DEFAULT CURRENT_DATE NOT NULL,
    last_update timestamp with time zone DEFAULT now(),
    active integer
);


--
-- Name: rewards_report(integer, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rewards_report(min_monthly_purchases integer, min_dollar_amount_purchased numeric) RETURNS SETOF public.customer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE
    last_month_start DATE;
    last_month_end DATE;
rr RECORD;
tmpSQL TEXT;
BEGIN

    /* Some sanity checks... */
    IF min_monthly_purchases = 0 THEN
        RAISE EXCEPTION 'Minimum monthly purchases parameter must be > 0';
    END IF;
    IF min_dollar_amount_purchased = 0.00 THEN
        RAISE EXCEPTION 'Minimum monthly dollar amount purchased parameter must be > $0.00';
    END IF;

    last_month_start := CURRENT_DATE - '3 month'::interval;
    last_month_start := to_date((extract(YEAR FROM last_month_start) || '-' || extract(MONTH FROM last_month_start) || '-01'),'YYYY-MM-DD');
    last_month_end := LAST_DAY(last_month_start);

    /*
    Create a temporary storage area for Customer IDs.
    */
    CREATE TEMPORARY TABLE tmpCustomer (customer_id INTEGER NOT NULL PRIMARY KEY);

    /*
    Find all customers meeting the monthly purchase requirements
    */

    tmpSQL := 'INSERT INTO tmpCustomer (customer_id)
        SELECT p.customer_id
        FROM payment AS p
        WHERE DATE(p.payment_date) BETWEEN '||quote_literal(last_month_start) ||' AND '|| quote_literal(last_month_end) || '
        GROUP BY customer_id
        HAVING SUM(p.amount) > '|| min_dollar_amount_purchased || '
        AND COUNT(customer_id) > ' ||min_monthly_purchases ;

    EXECUTE tmpSQL;

    /*
    Output ALL customer information of matching rewardees.
    Customize output as needed.
    */
    FOR rr IN EXECUTE 'SELECT c.* FROM tmpCustomer AS t INNER JOIN customer AS c ON t.customer_id = c.customer_id' LOOP
        RETURN NEXT rr;
    END LOOP;

    /* Clean up */
    tmpSQL := 'DROP TABLE tmpCustomer';
    EXECUTE tmpSQL;

RETURN;
END
$_$;


--
-- Name: group_concat(text); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE public.group_concat(text) (
    SFUNC = public._group_concat,
    STYPE = text
);


--
-- Name: actor_actor_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.actor_actor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: actor; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.actor (
    actor_id integer DEFAULT nextval('public.actor_actor_id_seq'::regclass) NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL,
    imdb_nconst character varying(255)
);


--
-- Name: category_category_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category (
    category_id integer DEFAULT nextval('public.category_category_id_seq'::regclass) NOT NULL,
    name text NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: film_film_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.film_film_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: film; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.film (
    film_id integer DEFAULT nextval('public.film_film_id_seq'::regclass) NOT NULL,
    title text NOT NULL,
    description text,
    release_year public.year,
    language_id integer NOT NULL,
    original_language_id integer,
    rental_duration smallint DEFAULT 3 NOT NULL,
    rental_rate numeric(4,2) DEFAULT 4.99 NOT NULL,
    length smallint,
    replacement_cost numeric(5,2) DEFAULT 19.99 NOT NULL,
    rating public.mpaa_rating DEFAULT 'G'::public.mpaa_rating,
    last_update timestamp with time zone DEFAULT now() NOT NULL,
    special_features text[],
    fulltext tsvector DEFAULT to_tsvector('english'::regconfig, ''::text) NOT NULL,
    imdb_tconst character varying(255)
);


--
-- Name: film_actor; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.film_actor (
    actor_id integer NOT NULL,
    film_id integer NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: film_category; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.film_category (
    film_id integer NOT NULL,
    category_id integer NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: actor_info; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.actor_info AS
 SELECT a.actor_id,
    a.first_name,
    a.last_name,
    public.group_concat(DISTINCT ((c.name || ': '::text) || ( SELECT public.group_concat(f.title) AS group_concat
           FROM ((public.film f
             JOIN public.film_category fc_1 ON ((f.film_id = fc_1.film_id)))
             JOIN public.film_actor fa_1 ON ((f.film_id = fa_1.film_id)))
          WHERE ((fc_1.category_id = c.category_id) AND (fa_1.actor_id = a.actor_id))
          GROUP BY fa_1.actor_id))) AS film_info
   FROM (((public.actor a
     LEFT JOIN public.film_actor fa ON ((a.actor_id = fa.actor_id)))
     LEFT JOIN public.film_category fc ON ((fa.film_id = fc.film_id)))
     LEFT JOIN public.category c ON ((fc.category_id = c.category_id)))
  GROUP BY a.actor_id, a.first_name, a.last_name;


--
-- Name: address_address_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.address_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: address; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.address (
    address_id integer DEFAULT nextval('public.address_address_id_seq'::regclass) NOT NULL,
    address text NOT NULL,
    address2 text,
    district text NOT NULL,
    city_id integer NOT NULL,
    postal_code text,
    phone text NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: authors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.authors (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    bio text,
    avatar_url character varying(255),
    active boolean DEFAULT true NOT NULL,
    role character varying(255) DEFAULT 'author'::character varying,
    follower_count integer DEFAULT 0,
    verified boolean DEFAULT false,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: authors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.authors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: authors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.authors_id_seq OWNED BY public.authors.id;


--
-- Name: blog_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blog_tags (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    description text,
    color character varying(255),
    post_count integer DEFAULT 0,
    featured boolean DEFAULT false,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: blog_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blog_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blog_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blog_tags_id_seq OWNED BY public.blog_tags.id;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    description text,
    color character varying(255),
    active boolean DEFAULT true,
    post_count integer DEFAULT 0,
    parent_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: city_city_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.city_city_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: city; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.city (
    city_id integer DEFAULT nextval('public.city_city_id_seq'::regclass) NOT NULL,
    city text NOT NULL,
    country_id integer NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id bigint NOT NULL,
    content text NOT NULL,
    author_name character varying(255),
    author_email character varying(255),
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    like_count integer DEFAULT 0,
    reply_count integer DEFAULT 0,
    post_id bigint NOT NULL,
    parent_id bigint,
    author_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comments_id_seq OWNED BY public.comments.id;


--
-- Name: country_country_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.country_country_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: country; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.country (
    country_id integer DEFAULT nextval('public.country_country_id_seq'::regclass) NOT NULL,
    country text NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: customer_list; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.customer_list AS
 SELECT cu.customer_id AS id,
    ((cu.first_name || ' '::text) || cu.last_name) AS name,
    a.address,
    a.postal_code AS "zip code",
    a.phone,
    city.city,
    country.country,
        CASE
            WHEN cu.activebool THEN 'active'::text
            ELSE ''::text
        END AS notes,
    cu.store_id AS sid
   FROM (((public.customer cu
     JOIN public.address a ON ((cu.address_id = a.address_id)))
     JOIN public.city ON ((a.city_id = city.city_id)))
     JOIN public.country ON ((city.country_id = country.country_id)));


--
-- Name: exported_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exported_views (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    context character varying(255) NOT NULL,
    path character varying(255),
    view_type character varying(255) NOT NULL,
    public_id character varying(255) NOT NULL,
    signature_version integer DEFAULT 1 NOT NULL,
    cache_ttl_hours integer DEFAULT 3 NOT NULL,
    ip_allowlist_text text,
    snapshot_blob bytea NOT NULL,
    cache_blob bytea,
    cache_generated_at timestamp without time zone,
    cache_expires_at timestamp without time zone,
    last_execution_time_ms double precision,
    last_row_count integer,
    last_payload_bytes integer,
    access_count integer DEFAULT 0 NOT NULL,
    last_accessed_at timestamp without time zone,
    last_error text,
    disabled_at timestamp without time zone,
    user_id character varying(255),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: exported_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.exported_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: exported_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.exported_views_id_seq OWNED BY public.exported_views.id;


--
-- Name: film_flag; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.film_flag (
    id bigint NOT NULL,
    film_id bigint,
    flag_id bigint,
    value character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: film_flag_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.film_flag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: film_flag_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.film_flag_id_seq OWNED BY public.film_flag.id;


--
-- Name: film_list; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.film_list AS
 SELECT film.film_id AS fid,
    film.title,
    film.description,
    category.name AS category,
    film.rental_rate AS price,
    film.length,
    film.rating,
    public.group_concat(((actor.first_name || ' '::text) || actor.last_name)) AS actors
   FROM ((((public.category
     LEFT JOIN public.film_category ON ((category.category_id = film_category.category_id)))
     LEFT JOIN public.film ON ((film_category.film_id = film.film_id)))
     JOIN public.film_actor ON ((film.film_id = film_actor.film_id)))
     JOIN public.actor ON ((film_actor.actor_id = actor.actor_id)))
  GROUP BY film.film_id, film.title, film.description, category.name, film.rental_rate, film.length, film.rating;


--
-- Name: film_tag; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.film_tag (
    id bigint NOT NULL,
    film_id bigint,
    tag_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: film_tag_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.film_tag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: film_tag_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.film_tag_id_seq OWNED BY public.film_tag.id;


--
-- Name: filter_sets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.filter_sets (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    domain character varying(255) NOT NULL,
    filters jsonb NOT NULL,
    user_id character varying(255) NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    is_shared boolean DEFAULT false NOT NULL,
    is_system boolean DEFAULT false NOT NULL,
    usage_count integer DEFAULT 0 NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: flag; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flag (
    id bigint NOT NULL,
    name character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: flag_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flag_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flag_id_seq OWNED BY public.flag.id;


--
-- Name: imdb_stage_cast; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.imdb_stage_cast (
    tconst text,
    nconst text
);


--
-- Name: imdb_stage_movies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.imdb_stage_movies (
    tconst text,
    title_type text,
    primary_title text,
    original_title text,
    is_adult text,
    start_year text,
    end_year text,
    runtime_minutes text,
    genres text
);


--
-- Name: imdb_stage_names; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.imdb_stage_names (
    nconst text,
    primary_name text
);


--
-- Name: inventory_inventory_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inventory_inventory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inventory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory (
    inventory_id integer DEFAULT nextval('public.inventory_inventory_id_seq'::regclass) NOT NULL,
    film_id integer NOT NULL,
    store_id integer NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: language_language_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.language_language_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: language; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.language (
    language_id integer DEFAULT nextval('public.language_language_id_seq'::regclass) NOT NULL,
    name character(20) NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: nicer_but_slower_film_list; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.nicer_but_slower_film_list AS
 SELECT film.film_id AS fid,
    film.title,
    film.description,
    category.name AS category,
    film.rental_rate AS price,
    film.length,
    film.rating,
    public.group_concat((((upper("substring"(actor.first_name, 1, 1)) || lower("substring"(actor.first_name, 2))) || upper("substring"(actor.last_name, 1, 1))) || lower("substring"(actor.last_name, 2)))) AS actors
   FROM ((((public.category
     LEFT JOIN public.film_category ON ((category.category_id = film_category.category_id)))
     LEFT JOIN public.film ON ((film_category.film_id = film.film_id)))
     JOIN public.film_actor ON ((film.film_id = film_actor.film_id)))
     JOIN public.actor ON ((film_actor.actor_id = actor.actor_id)))
  GROUP BY film.film_id, film.title, film.description, category.name, film.rental_rate, film.length, film.rating;


--
-- Name: parameterized_products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parameterized_products (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    price numeric(10,2),
    category_id bigint,
    active boolean DEFAULT true,
    featured boolean DEFAULT false,
    min_price_threshold numeric(10,2) DEFAULT 0.0,
    inventory_count integer DEFAULT 0,
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: parameterized_products_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parameterized_products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: parameterized_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parameterized_products_id_seq OWNED BY public.parameterized_products.id;


--
-- Name: payment_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment (
    payment_id integer DEFAULT nextval('public.payment_payment_id_seq'::regclass) NOT NULL,
    customer_id integer NOT NULL,
    staff_id integer NOT NULL,
    rental_id integer NOT NULL,
    amount numeric(5,2) NOT NULL,
    payment_date timestamp with time zone NOT NULL
)
PARTITION BY RANGE (payment_date);


--
-- Name: payment_p2022_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_p2022_01 (
    payment_id integer DEFAULT nextval('public.payment_payment_id_seq'::regclass) NOT NULL,
    customer_id integer NOT NULL,
    staff_id integer NOT NULL,
    rental_id integer NOT NULL,
    amount numeric(5,2) NOT NULL,
    payment_date timestamp with time zone NOT NULL
);


--
-- Name: payment_p2022_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_p2022_02 (
    payment_id integer DEFAULT nextval('public.payment_payment_id_seq'::regclass) NOT NULL,
    customer_id integer NOT NULL,
    staff_id integer NOT NULL,
    rental_id integer NOT NULL,
    amount numeric(5,2) NOT NULL,
    payment_date timestamp with time zone NOT NULL
);


--
-- Name: payment_p2022_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_p2022_03 (
    payment_id integer DEFAULT nextval('public.payment_payment_id_seq'::regclass) NOT NULL,
    customer_id integer NOT NULL,
    staff_id integer NOT NULL,
    rental_id integer NOT NULL,
    amount numeric(5,2) NOT NULL,
    payment_date timestamp with time zone NOT NULL
);


--
-- Name: payment_p2022_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_p2022_04 (
    payment_id integer DEFAULT nextval('public.payment_payment_id_seq'::regclass) NOT NULL,
    customer_id integer NOT NULL,
    staff_id integer NOT NULL,
    rental_id integer NOT NULL,
    amount numeric(5,2) NOT NULL,
    payment_date timestamp with time zone NOT NULL
);


--
-- Name: payment_p2022_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_p2022_05 (
    payment_id integer DEFAULT nextval('public.payment_payment_id_seq'::regclass) NOT NULL,
    customer_id integer NOT NULL,
    staff_id integer NOT NULL,
    rental_id integer NOT NULL,
    amount numeric(5,2) NOT NULL,
    payment_date timestamp with time zone NOT NULL
);


--
-- Name: payment_p2022_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_p2022_06 (
    payment_id integer DEFAULT nextval('public.payment_payment_id_seq'::regclass) NOT NULL,
    customer_id integer NOT NULL,
    staff_id integer NOT NULL,
    rental_id integer NOT NULL,
    amount numeric(5,2) NOT NULL,
    payment_date timestamp with time zone NOT NULL
);


--
-- Name: payment_p2022_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_p2022_07 (
    payment_id integer DEFAULT nextval('public.payment_payment_id_seq'::regclass) NOT NULL,
    customer_id integer NOT NULL,
    staff_id integer NOT NULL,
    rental_id integer NOT NULL,
    amount numeric(5,2) NOT NULL,
    payment_date timestamp with time zone NOT NULL
);


--
-- Name: planets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planets (
    id bigint NOT NULL,
    name character varying(255),
    mass double precision,
    radius double precision,
    surface_temp double precision,
    atmosphere boolean DEFAULT false NOT NULL,
    solar_system_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: planets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.planets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: planets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.planets_id_seq OWNED BY public.planets.id;


--
-- Name: post_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_categories (
    post_id bigint NOT NULL,
    category_id bigint NOT NULL
);


--
-- Name: post_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_tags (
    post_id bigint NOT NULL,
    blog_tag_id bigint NOT NULL,
    created_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id bigint NOT NULL,
    title character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    content text NOT NULL,
    excerpt character varying(255),
    status character varying(255) DEFAULT 'draft'::character varying NOT NULL,
    published_at timestamp(0) without time zone,
    featured boolean DEFAULT false,
    view_count integer DEFAULT 0,
    like_count integer DEFAULT 0,
    comment_count integer DEFAULT 0,
    reading_time_minutes integer,
    author_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: product_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_categories (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    parent_id bigint,
    active boolean DEFAULT true,
    description text,
    sort_order integer DEFAULT 0,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: product_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.product_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: product_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.product_categories_id_seq OWNED BY public.product_categories.id;


--
-- Name: product_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_reviews (
    id bigint NOT NULL,
    product_id bigint NOT NULL,
    user_id bigint,
    rating integer NOT NULL,
    title character varying(255),
    content text,
    verified_purchase boolean DEFAULT false,
    helpful_votes integer DEFAULT 0,
    status character varying(255) DEFAULT 'published'::character varying,
    sentiment character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: product_reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.product_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: product_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.product_reviews_id_seq OWNED BY public.product_reviews.id;


--
-- Name: regional_pricing; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.regional_pricing (
    id bigint NOT NULL,
    product_id bigint NOT NULL,
    region_code character varying(10) NOT NULL,
    currency character varying(3) NOT NULL,
    price numeric(10,2),
    tax_rate numeric(5,4) DEFAULT 0.0,
    active boolean DEFAULT true,
    effective_date date,
    expiry_date date,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: regional_pricing_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.regional_pricing_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: regional_pricing_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.regional_pricing_id_seq OWNED BY public.regional_pricing.id;


--
-- Name: rental_rental_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rental_rental_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rental; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rental (
    rental_id integer DEFAULT nextval('public.rental_rental_id_seq'::regclass) NOT NULL,
    rental_date timestamp with time zone NOT NULL,
    inventory_id integer NOT NULL,
    customer_id integer NOT NULL,
    return_date timestamp with time zone,
    staff_id integer NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: rental_by_category; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.rental_by_category AS
 SELECT c.name AS category,
    sum(p.amount) AS total_sales
   FROM (((((public.payment p
     JOIN public.rental r ON ((p.rental_id = r.rental_id)))
     JOIN public.inventory i ON ((r.inventory_id = i.inventory_id)))
     JOIN public.film f ON ((i.film_id = f.film_id)))
     JOIN public.film_category fc ON ((f.film_id = fc.film_id)))
     JOIN public.category c ON ((fc.category_id = c.category_id)))
  GROUP BY c.name
  ORDER BY (sum(p.amount)) DESC
  WITH NO DATA;


--
-- Name: sales_by_film_category; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.sales_by_film_category AS
 SELECT c.name AS category,
    sum(p.amount) AS total_sales
   FROM (((((public.payment p
     JOIN public.rental r ON ((p.rental_id = r.rental_id)))
     JOIN public.inventory i ON ((r.inventory_id = i.inventory_id)))
     JOIN public.film f ON ((i.film_id = f.film_id)))
     JOIN public.film_category fc ON ((f.film_id = fc.film_id)))
     JOIN public.category c ON ((fc.category_id = c.category_id)))
  GROUP BY c.name
  ORDER BY (sum(p.amount)) DESC;


--
-- Name: staff_staff_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_staff_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff (
    staff_id integer DEFAULT nextval('public.staff_staff_id_seq'::regclass) NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    address_id integer NOT NULL,
    email text,
    store_id integer NOT NULL,
    active boolean DEFAULT true NOT NULL,
    username text NOT NULL,
    password text,
    last_update timestamp with time zone DEFAULT now() NOT NULL,
    picture bytea
);


--
-- Name: store_store_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.store_store_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: store; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store (
    store_id integer DEFAULT nextval('public.store_store_id_seq'::regclass) NOT NULL,
    manager_staff_id integer NOT NULL,
    address_id integer NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sales_by_store; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.sales_by_store AS
 SELECT ((c.city || ','::text) || cy.country) AS store,
    ((m.first_name || ' '::text) || m.last_name) AS manager,
    sum(p.amount) AS total_sales
   FROM (((((((public.payment p
     JOIN public.rental r ON ((p.rental_id = r.rental_id)))
     JOIN public.inventory i ON ((r.inventory_id = i.inventory_id)))
     JOIN public.store s ON ((i.store_id = s.store_id)))
     JOIN public.address a ON ((s.address_id = a.address_id)))
     JOIN public.city c ON ((a.city_id = c.city_id)))
     JOIN public.country cy ON ((c.country_id = cy.country_id)))
     JOIN public.staff m ON ((s.manager_staff_id = m.staff_id)))
  GROUP BY cy.country, c.city, s.store_id, m.first_name, m.last_name
  ORDER BY cy.country, c.city;


--
-- Name: satellites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.satellites (
    id bigint NOT NULL,
    name character varying(255),
    period double precision,
    mass double precision,
    radius double precision,
    planet_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: satellites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.satellites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: satellites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.satellites_id_seq OWNED BY public.satellites.id;


--
-- Name: saved_view_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_view_configs (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    context character varying(255) NOT NULL,
    view_type character varying(255) NOT NULL,
    params jsonb NOT NULL,
    user_id character varying(255),
    description text,
    is_public boolean DEFAULT false,
    version integer DEFAULT 1,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: saved_view_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.saved_view_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: saved_view_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.saved_view_configs_id_seq OWNED BY public.saved_view_configs.id;


--
-- Name: saved_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_views (
    id bigint NOT NULL,
    name character varying(255),
    context character varying(255),
    params jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: saved_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.saved_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: saved_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.saved_views_id_seq OWNED BY public.saved_views.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: seasonal_discounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.seasonal_discounts (
    id bigint NOT NULL,
    product_id bigint NOT NULL,
    season character varying(255) NOT NULL,
    tier character varying(255) NOT NULL,
    discount_percent numeric(5,2) NOT NULL,
    active boolean DEFAULT true,
    start_date date,
    end_date date,
    description text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: seasonal_discounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.seasonal_discounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: seasonal_discounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.seasonal_discounts_id_seq OWNED BY public.seasonal_discounts.id;


--
-- Name: shortened_urls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shortened_urls (
    id uuid NOT NULL,
    short_code character varying(255) NOT NULL,
    long_url text NOT NULL,
    expires_at timestamp(0) without time zone,
    click_count integer DEFAULT 0 NOT NULL,
    last_accessed_at timestamp(0) without time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    creator_id uuid,
    is_public boolean DEFAULT true NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: solar_systems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solar_systems (
    id bigint NOT NULL,
    name character varying(255),
    galaxy character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: solar_systems_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solar_systems_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solar_systems_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solar_systems_id_seq OWNED BY public.solar_systems.id;


--
-- Name: staff_list; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.staff_list AS
 SELECT s.staff_id AS id,
    ((s.first_name || ' '::text) || s.last_name) AS name,
    a.address,
    a.postal_code AS "zip code",
    a.phone,
    city.city,
    country.country,
    s.store_id AS sid
   FROM (((public.staff s
     JOIN public.address a ON ((s.address_id = a.address_id)))
     JOIN public.city ON ((a.city_id = city.city_id)))
     JOIN public.country ON ((city.country_id = country.country_id)));


--
-- Name: tag; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag (
    id bigint NOT NULL,
    name character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: tag_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_id_seq OWNED BY public.tag.id;


--
-- Name: test_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test_users (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255),
    role character varying(255) DEFAULT 'customer'::character varying,
    active boolean DEFAULT true,
    subscription_tier character varying(255) DEFAULT 'standard'::character varying,
    region character varying(255) DEFAULT 'US'::character varying,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: test_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.test_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: test_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.test_users_id_seq OWNED BY public.test_users.id;


--
-- Name: user_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_preferences (
    id bigint NOT NULL,
    user_id bigint,
    preference_key character varying(100) NOT NULL,
    preference_value jsonb,
    is_active boolean DEFAULT true,
    priority integer DEFAULT 0,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: user_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_preferences_id_seq OWNED BY public.user_preferences.id;


--
-- Name: payment_p2022_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment ATTACH PARTITION public.payment_p2022_01 FOR VALUES FROM ('2022-01-01 00:00:00+00') TO ('2022-02-01 00:00:00+00');


--
-- Name: payment_p2022_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment ATTACH PARTITION public.payment_p2022_02 FOR VALUES FROM ('2022-02-01 00:00:00+00') TO ('2022-03-01 00:00:00+00');


--
-- Name: payment_p2022_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment ATTACH PARTITION public.payment_p2022_03 FOR VALUES FROM ('2022-03-01 00:00:00+00') TO ('2022-04-01 00:00:00+00');


--
-- Name: payment_p2022_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment ATTACH PARTITION public.payment_p2022_04 FOR VALUES FROM ('2022-04-01 00:00:00+00') TO ('2022-05-01 00:00:00+00');


--
-- Name: payment_p2022_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment ATTACH PARTITION public.payment_p2022_05 FOR VALUES FROM ('2022-05-01 00:00:00+00') TO ('2022-06-01 00:00:00+00');


--
-- Name: payment_p2022_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment ATTACH PARTITION public.payment_p2022_06 FOR VALUES FROM ('2022-06-01 00:00:00+00') TO ('2022-07-01 00:00:00+00');


--
-- Name: payment_p2022_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment ATTACH PARTITION public.payment_p2022_07 FOR VALUES FROM ('2022-07-01 00:00:00+00') TO ('2022-08-01 00:00:00+00');


--
-- Name: authors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authors ALTER COLUMN id SET DEFAULT nextval('public.authors_id_seq'::regclass);


--
-- Name: blog_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_tags ALTER COLUMN id SET DEFAULT nextval('public.blog_tags_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass);


--
-- Name: exported_views id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exported_views ALTER COLUMN id SET DEFAULT nextval('public.exported_views_id_seq'::regclass);


--
-- Name: film_flag id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_flag ALTER COLUMN id SET DEFAULT nextval('public.film_flag_id_seq'::regclass);


--
-- Name: film_tag id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_tag ALTER COLUMN id SET DEFAULT nextval('public.film_tag_id_seq'::regclass);


--
-- Name: flag id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flag ALTER COLUMN id SET DEFAULT nextval('public.flag_id_seq'::regclass);


--
-- Name: parameterized_products id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parameterized_products ALTER COLUMN id SET DEFAULT nextval('public.parameterized_products_id_seq'::regclass);


--
-- Name: planets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planets ALTER COLUMN id SET DEFAULT nextval('public.planets_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: product_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories ALTER COLUMN id SET DEFAULT nextval('public.product_categories_id_seq'::regclass);


--
-- Name: product_reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_reviews ALTER COLUMN id SET DEFAULT nextval('public.product_reviews_id_seq'::regclass);


--
-- Name: regional_pricing id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regional_pricing ALTER COLUMN id SET DEFAULT nextval('public.regional_pricing_id_seq'::regclass);


--
-- Name: satellites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.satellites ALTER COLUMN id SET DEFAULT nextval('public.satellites_id_seq'::regclass);


--
-- Name: saved_view_configs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_view_configs ALTER COLUMN id SET DEFAULT nextval('public.saved_view_configs_id_seq'::regclass);


--
-- Name: saved_views id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_views ALTER COLUMN id SET DEFAULT nextval('public.saved_views_id_seq'::regclass);


--
-- Name: seasonal_discounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_discounts ALTER COLUMN id SET DEFAULT nextval('public.seasonal_discounts_id_seq'::regclass);


--
-- Name: solar_systems id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solar_systems ALTER COLUMN id SET DEFAULT nextval('public.solar_systems_id_seq'::regclass);


--
-- Name: tag id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag ALTER COLUMN id SET DEFAULT nextval('public.tag_id_seq'::regclass);


--
-- Name: test_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_users ALTER COLUMN id SET DEFAULT nextval('public.test_users_id_seq'::regclass);


--
-- Name: user_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences ALTER COLUMN id SET DEFAULT nextval('public.user_preferences_id_seq'::regclass);


--
-- Name: actor actor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.actor
    ADD CONSTRAINT actor_pkey PRIMARY KEY (actor_id);


--
-- Name: address address_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);


--
-- Name: authors authors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authors
    ADD CONSTRAINT authors_pkey PRIMARY KEY (id);


--
-- Name: blog_tags blog_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_tags
    ADD CONSTRAINT blog_tags_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: category category_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT category_pkey PRIMARY KEY (category_id);


--
-- Name: city city_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.city
    ADD CONSTRAINT city_pkey PRIMARY KEY (city_id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: country country_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.country
    ADD CONSTRAINT country_pkey PRIMARY KEY (country_id);


--
-- Name: customer customer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (customer_id);


--
-- Name: exported_views exported_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exported_views
    ADD CONSTRAINT exported_views_pkey PRIMARY KEY (id);


--
-- Name: film_actor film_actor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_actor
    ADD CONSTRAINT film_actor_pkey PRIMARY KEY (actor_id, film_id);


--
-- Name: film_category film_category_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_category
    ADD CONSTRAINT film_category_pkey PRIMARY KEY (film_id, category_id);


--
-- Name: film_flag film_flag_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_flag
    ADD CONSTRAINT film_flag_pkey PRIMARY KEY (id);


--
-- Name: film film_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film
    ADD CONSTRAINT film_pkey PRIMARY KEY (film_id);


--
-- Name: film_tag film_tag_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_tag
    ADD CONSTRAINT film_tag_pkey PRIMARY KEY (id);


--
-- Name: filter_sets filter_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.filter_sets
    ADD CONSTRAINT filter_sets_pkey PRIMARY KEY (id);


--
-- Name: flag flag_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flag
    ADD CONSTRAINT flag_pkey PRIMARY KEY (id);


--
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY (inventory_id);


--
-- Name: language language_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.language
    ADD CONSTRAINT language_pkey PRIMARY KEY (language_id);


--
-- Name: parameterized_products parameterized_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parameterized_products
    ADD CONSTRAINT parameterized_products_pkey PRIMARY KEY (id);


--
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (payment_date, payment_id);


--
-- Name: payment_p2022_01 payment_p2022_01_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_01
    ADD CONSTRAINT payment_p2022_01_pkey PRIMARY KEY (payment_date, payment_id);


--
-- Name: payment_p2022_02 payment_p2022_02_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_02
    ADD CONSTRAINT payment_p2022_02_pkey PRIMARY KEY (payment_date, payment_id);


--
-- Name: payment_p2022_03 payment_p2022_03_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_03
    ADD CONSTRAINT payment_p2022_03_pkey PRIMARY KEY (payment_date, payment_id);


--
-- Name: payment_p2022_04 payment_p2022_04_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_04
    ADD CONSTRAINT payment_p2022_04_pkey PRIMARY KEY (payment_date, payment_id);


--
-- Name: payment_p2022_05 payment_p2022_05_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_05
    ADD CONSTRAINT payment_p2022_05_pkey PRIMARY KEY (payment_date, payment_id);


--
-- Name: payment_p2022_06 payment_p2022_06_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_06
    ADD CONSTRAINT payment_p2022_06_pkey PRIMARY KEY (payment_date, payment_id);


--
-- Name: payment_p2022_07 payment_p2022_07_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_07
    ADD CONSTRAINT payment_p2022_07_pkey PRIMARY KEY (payment_date, payment_id);


--
-- Name: planets planets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planets
    ADD CONSTRAINT planets_pkey PRIMARY KEY (id);


--
-- Name: post_categories post_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_categories
    ADD CONSTRAINT post_categories_pkey PRIMARY KEY (post_id, category_id);


--
-- Name: post_tags post_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_pkey PRIMARY KEY (post_id, blog_tag_id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: product_categories product_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_pkey PRIMARY KEY (id);


--
-- Name: product_reviews product_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_reviews
    ADD CONSTRAINT product_reviews_pkey PRIMARY KEY (id);


--
-- Name: regional_pricing regional_pricing_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regional_pricing
    ADD CONSTRAINT regional_pricing_pkey PRIMARY KEY (id);


--
-- Name: rental rental_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental
    ADD CONSTRAINT rental_pkey PRIMARY KEY (rental_id);


--
-- Name: satellites satellites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.satellites
    ADD CONSTRAINT satellites_pkey PRIMARY KEY (id);


--
-- Name: saved_view_configs saved_view_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_view_configs
    ADD CONSTRAINT saved_view_configs_pkey PRIMARY KEY (id);


--
-- Name: saved_views saved_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_views
    ADD CONSTRAINT saved_views_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: seasonal_discounts seasonal_discounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_discounts
    ADD CONSTRAINT seasonal_discounts_pkey PRIMARY KEY (id);


--
-- Name: shortened_urls shortened_urls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shortened_urls
    ADD CONSTRAINT shortened_urls_pkey PRIMARY KEY (id);


--
-- Name: solar_systems solar_systems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solar_systems
    ADD CONSTRAINT solar_systems_pkey PRIMARY KEY (id);


--
-- Name: staff staff_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (staff_id);


--
-- Name: store store_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store
    ADD CONSTRAINT store_pkey PRIMARY KEY (store_id);


--
-- Name: tag tag_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag
    ADD CONSTRAINT tag_pkey PRIMARY KEY (id);


--
-- Name: test_users test_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_users
    ADD CONSTRAINT test_users_pkey PRIMARY KEY (id);


--
-- Name: user_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (id);


--
-- Name: actor_imdb_nconst_unique_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX actor_imdb_nconst_unique_idx ON public.actor USING btree (imdb_nconst);


--
-- Name: authors_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX authors_active_index ON public.authors USING btree (active);


--
-- Name: authors_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX authors_email_index ON public.authors USING btree (email);


--
-- Name: authors_role_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX authors_role_index ON public.authors USING btree (role);


--
-- Name: blog_tags_featured_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX blog_tags_featured_index ON public.blog_tags USING btree (featured);


--
-- Name: blog_tags_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX blog_tags_slug_index ON public.blog_tags USING btree (slug);


--
-- Name: categories_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX categories_active_index ON public.categories USING btree (active);


--
-- Name: categories_parent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX categories_parent_id_index ON public.categories USING btree (parent_id);


--
-- Name: categories_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX categories_slug_index ON public.categories USING btree (slug);


--
-- Name: comments_author_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_author_id_index ON public.comments USING btree (author_id);


--
-- Name: comments_parent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_parent_id_index ON public.comments USING btree (parent_id);


--
-- Name: comments_post_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_post_id_index ON public.comments USING btree (post_id);


--
-- Name: comments_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_status_index ON public.comments USING btree (status);


--
-- Name: exported_views_cache_expires_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX exported_views_cache_expires_at_index ON public.exported_views USING btree (cache_expires_at);


--
-- Name: exported_views_context_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX exported_views_context_index ON public.exported_views USING btree (context);


--
-- Name: exported_views_context_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX exported_views_context_user_id_index ON public.exported_views USING btree (context, user_id);


--
-- Name: exported_views_public_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX exported_views_public_id_index ON public.exported_views USING btree (public_id);


--
-- Name: film_fulltext_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX film_fulltext_idx ON public.film USING gist (fulltext);


--
-- Name: film_imdb_tconst_unique_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX film_imdb_tconst_unique_idx ON public.film USING btree (imdb_tconst);


--
-- Name: filter_sets_domain_is_shared_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX filter_sets_domain_is_shared_index ON public.filter_sets USING btree (domain, is_shared);


--
-- Name: filter_sets_domain_is_system_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX filter_sets_domain_is_system_index ON public.filter_sets USING btree (domain, is_system);


--
-- Name: filter_sets_user_id_domain_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX filter_sets_user_id_domain_index ON public.filter_sets USING btree (user_id, domain);


--
-- Name: filter_sets_user_id_domain_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX filter_sets_user_id_domain_name_index ON public.filter_sets USING btree (user_id, domain, name);


--
-- Name: filter_sets_user_id_is_default_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX filter_sets_user_id_is_default_index ON public.filter_sets USING btree (user_id, is_default);


--
-- Name: idx_actor_last_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_actor_last_name ON public.actor USING btree (last_name);


--
-- Name: idx_fk_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_address_id ON public.customer USING btree (address_id);


--
-- Name: idx_fk_city_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_city_id ON public.address USING btree (city_id);


--
-- Name: idx_fk_country_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_country_id ON public.city USING btree (country_id);


--
-- Name: idx_fk_film_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_film_id ON public.film_actor USING btree (film_id);


--
-- Name: idx_fk_inventory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_inventory_id ON public.rental USING btree (inventory_id);


--
-- Name: idx_fk_language_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_language_id ON public.film USING btree (language_id);


--
-- Name: idx_fk_original_language_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_original_language_id ON public.film USING btree (original_language_id);


--
-- Name: idx_fk_payment_p2022_01_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_payment_p2022_01_customer_id ON public.payment_p2022_01 USING btree (customer_id);


--
-- Name: idx_fk_payment_p2022_01_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_payment_p2022_01_staff_id ON public.payment_p2022_01 USING btree (staff_id);


--
-- Name: idx_fk_payment_p2022_02_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_payment_p2022_02_customer_id ON public.payment_p2022_02 USING btree (customer_id);


--
-- Name: idx_fk_payment_p2022_02_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_payment_p2022_02_staff_id ON public.payment_p2022_02 USING btree (staff_id);


--
-- Name: idx_fk_payment_p2022_03_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_payment_p2022_03_customer_id ON public.payment_p2022_03 USING btree (customer_id);


--
-- Name: idx_fk_payment_p2022_03_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_payment_p2022_03_staff_id ON public.payment_p2022_03 USING btree (staff_id);


--
-- Name: idx_fk_payment_p2022_04_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_payment_p2022_04_customer_id ON public.payment_p2022_04 USING btree (customer_id);


--
-- Name: idx_fk_payment_p2022_04_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_payment_p2022_04_staff_id ON public.payment_p2022_04 USING btree (staff_id);


--
-- Name: idx_fk_payment_p2022_05_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_payment_p2022_05_customer_id ON public.payment_p2022_05 USING btree (customer_id);


--
-- Name: idx_fk_payment_p2022_05_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_payment_p2022_05_staff_id ON public.payment_p2022_05 USING btree (staff_id);


--
-- Name: idx_fk_payment_p2022_06_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_payment_p2022_06_customer_id ON public.payment_p2022_06 USING btree (customer_id);


--
-- Name: idx_fk_payment_p2022_06_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_payment_p2022_06_staff_id ON public.payment_p2022_06 USING btree (staff_id);


--
-- Name: idx_fk_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fk_store_id ON public.customer USING btree (store_id);


--
-- Name: idx_last_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_last_name ON public.customer USING btree (last_name);


--
-- Name: idx_store_id_film_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_store_id_film_id ON public.inventory USING btree (store_id, film_id);


--
-- Name: idx_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_title ON public.film USING btree (title);


--
-- Name: idx_unq_manager_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unq_manager_staff_id ON public.store USING btree (manager_staff_id);


--
-- Name: idx_unq_rental_rental_date_inventory_id_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unq_rental_rental_date_inventory_id_customer_id ON public.rental USING btree (rental_date, inventory_id, customer_id);


--
-- Name: imdb_stage_cast_nconst_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX imdb_stage_cast_nconst_idx ON public.imdb_stage_cast USING btree (nconst);


--
-- Name: imdb_stage_cast_tconst_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX imdb_stage_cast_tconst_idx ON public.imdb_stage_cast USING btree (tconst);


--
-- Name: imdb_stage_movies_tconst_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX imdb_stage_movies_tconst_idx ON public.imdb_stage_movies USING btree (tconst);


--
-- Name: imdb_stage_names_nconst_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX imdb_stage_names_nconst_idx ON public.imdb_stage_names USING btree (nconst);


--
-- Name: index_for_saved_view_name_context; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_for_saved_view_name_context ON public.saved_views USING btree (name, context);


--
-- Name: index_for_tag_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_for_tag_name ON public.tag USING btree (name);


--
-- Name: parameterized_products_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX parameterized_products_active_index ON public.parameterized_products USING btree (active);


--
-- Name: parameterized_products_category_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX parameterized_products_category_id_index ON public.parameterized_products USING btree (category_id);


--
-- Name: parameterized_products_featured_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX parameterized_products_featured_index ON public.parameterized_products USING btree (featured);


--
-- Name: parameterized_products_price_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX parameterized_products_price_index ON public.parameterized_products USING btree (price);


--
-- Name: payment_p2022_01_customer_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payment_p2022_01_customer_id_idx ON public.payment_p2022_01 USING btree (customer_id);


--
-- Name: payment_p2022_02_customer_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payment_p2022_02_customer_id_idx ON public.payment_p2022_02 USING btree (customer_id);


--
-- Name: payment_p2022_03_customer_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payment_p2022_03_customer_id_idx ON public.payment_p2022_03 USING btree (customer_id);


--
-- Name: payment_p2022_04_customer_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payment_p2022_04_customer_id_idx ON public.payment_p2022_04 USING btree (customer_id);


--
-- Name: payment_p2022_05_customer_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payment_p2022_05_customer_id_idx ON public.payment_p2022_05 USING btree (customer_id);


--
-- Name: payment_p2022_06_customer_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payment_p2022_06_customer_id_idx ON public.payment_p2022_06 USING btree (customer_id);


--
-- Name: planets_solar_system_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX planets_solar_system_id_index ON public.planets USING btree (solar_system_id);


--
-- Name: post_categories_category_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_categories_category_id_index ON public.post_categories USING btree (category_id);


--
-- Name: post_categories_post_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_categories_post_id_index ON public.post_categories USING btree (post_id);


--
-- Name: post_tags_blog_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_tags_blog_tag_id_index ON public.post_tags USING btree (blog_tag_id);


--
-- Name: post_tags_post_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_tags_post_id_index ON public.post_tags USING btree (post_id);


--
-- Name: posts_author_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_author_id_index ON public.posts USING btree (author_id);


--
-- Name: posts_featured_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_featured_index ON public.posts USING btree (featured);


--
-- Name: posts_published_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_published_at_index ON public.posts USING btree (published_at);


--
-- Name: posts_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX posts_slug_index ON public.posts USING btree (slug);


--
-- Name: posts_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_status_index ON public.posts USING btree (status);


--
-- Name: product_categories_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_categories_active_index ON public.product_categories USING btree (active);


--
-- Name: product_categories_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_categories_name_index ON public.product_categories USING btree (name);


--
-- Name: product_categories_parent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_categories_parent_id_index ON public.product_categories USING btree (parent_id);


--
-- Name: product_reviews_product_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_reviews_product_id_index ON public.product_reviews USING btree (product_id);


--
-- Name: product_reviews_rating_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_reviews_rating_index ON public.product_reviews USING btree (rating);


--
-- Name: product_reviews_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_reviews_status_index ON public.product_reviews USING btree (status);


--
-- Name: product_reviews_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_reviews_user_id_index ON public.product_reviews USING btree (user_id);


--
-- Name: product_reviews_verified_purchase_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_reviews_verified_purchase_index ON public.product_reviews USING btree (verified_purchase);


--
-- Name: regional_pricing_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX regional_pricing_active_index ON public.regional_pricing USING btree (active);


--
-- Name: regional_pricing_currency_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX regional_pricing_currency_index ON public.regional_pricing USING btree (currency);


--
-- Name: regional_pricing_product_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX regional_pricing_product_id_index ON public.regional_pricing USING btree (product_id);


--
-- Name: regional_pricing_product_id_region_code_currency_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX regional_pricing_product_id_region_code_currency_index ON public.regional_pricing USING btree (product_id, region_code, currency);


--
-- Name: regional_pricing_region_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX regional_pricing_region_code_index ON public.regional_pricing USING btree (region_code);


--
-- Name: rental_category; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX rental_category ON public.rental_by_category USING btree (category);


--
-- Name: satellites_planet_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX satellites_planet_id_index ON public.satellites USING btree (planet_id);


--
-- Name: saved_view_configs_public_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX saved_view_configs_public_idx ON public.saved_view_configs USING btree (is_public);


--
-- Name: saved_view_configs_unique_name_per_view_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX saved_view_configs_unique_name_per_view_type ON public.saved_view_configs USING btree (name, context, view_type, user_id);


--
-- Name: saved_view_configs_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX saved_view_configs_user_id_idx ON public.saved_view_configs USING btree (user_id);


--
-- Name: saved_view_configs_view_type_context_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX saved_view_configs_view_type_context_idx ON public.saved_view_configs USING btree (view_type, context);


--
-- Name: seasonal_discounts_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_discounts_active_index ON public.seasonal_discounts USING btree (active);


--
-- Name: seasonal_discounts_product_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_discounts_product_id_index ON public.seasonal_discounts USING btree (product_id);


--
-- Name: seasonal_discounts_product_id_season_tier_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX seasonal_discounts_product_id_season_tier_index ON public.seasonal_discounts USING btree (product_id, season, tier);


--
-- Name: seasonal_discounts_season_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_discounts_season_index ON public.seasonal_discounts USING btree (season);


--
-- Name: seasonal_discounts_tier_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX seasonal_discounts_tier_index ON public.seasonal_discounts USING btree (tier);


--
-- Name: shortened_urls_creator_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX shortened_urls_creator_id_index ON public.shortened_urls USING btree (creator_id);


--
-- Name: shortened_urls_expires_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX shortened_urls_expires_at_index ON public.shortened_urls USING btree (expires_at);


--
-- Name: shortened_urls_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX shortened_urls_inserted_at_index ON public.shortened_urls USING btree (inserted_at);


--
-- Name: shortened_urls_short_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX shortened_urls_short_code_index ON public.shortened_urls USING btree (short_code);


--
-- Name: test_users_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX test_users_active_index ON public.test_users USING btree (active);


--
-- Name: test_users_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX test_users_email_index ON public.test_users USING btree (email);


--
-- Name: test_users_region_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX test_users_region_index ON public.test_users USING btree (region);


--
-- Name: test_users_role_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX test_users_role_index ON public.test_users USING btree (role);


--
-- Name: test_users_subscription_tier_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX test_users_subscription_tier_index ON public.test_users USING btree (subscription_tier);


--
-- Name: user_preferences_is_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_preferences_is_active_index ON public.user_preferences USING btree (is_active);


--
-- Name: user_preferences_preference_key_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_preferences_preference_key_index ON public.user_preferences USING btree (preference_key);


--
-- Name: user_preferences_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_preferences_user_id_index ON public.user_preferences USING btree (user_id);


--
-- Name: user_preferences_user_id_preference_key_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_preferences_user_id_preference_key_index ON public.user_preferences USING btree (user_id, preference_key);


--
-- Name: payment_p2022_01_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.payment_pkey ATTACH PARTITION public.payment_p2022_01_pkey;


--
-- Name: payment_p2022_02_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.payment_pkey ATTACH PARTITION public.payment_p2022_02_pkey;


--
-- Name: payment_p2022_03_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.payment_pkey ATTACH PARTITION public.payment_p2022_03_pkey;


--
-- Name: payment_p2022_04_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.payment_pkey ATTACH PARTITION public.payment_p2022_04_pkey;


--
-- Name: payment_p2022_05_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.payment_pkey ATTACH PARTITION public.payment_p2022_05_pkey;


--
-- Name: payment_p2022_06_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.payment_pkey ATTACH PARTITION public.payment_p2022_06_pkey;


--
-- Name: payment_p2022_07_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.payment_pkey ATTACH PARTITION public.payment_p2022_07_pkey;


--
-- Name: film film_fulltext_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER film_fulltext_trigger BEFORE INSERT OR UPDATE ON public.film FOR EACH ROW EXECUTE FUNCTION public.film_fulltext_trigger_func();


--
-- Name: actor last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.actor FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: address last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.address FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: category last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.category FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: city last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.city FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: country last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.country FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: customer last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.customer FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: film last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.film FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: film_actor last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.film_actor FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: film_category last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.film_category FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: inventory last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.inventory FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: language last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.language FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: rental last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.rental FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: staff last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.staff FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: store last_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER last_updated BEFORE UPDATE ON public.store FOR EACH ROW EXECUTE FUNCTION public.last_updated();


--
-- Name: address address_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address
    ADD CONSTRAINT address_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.city(city_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: categories categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- Name: city city_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.city
    ADD CONSTRAINT city_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.country(country_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: comments comments_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.authors(id) ON DELETE SET NULL;


--
-- Name: comments comments_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.comments(id) ON DELETE CASCADE;


--
-- Name: comments comments_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: customer customer_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: customer customer_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.store(store_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: film_actor film_actor_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_actor
    ADD CONSTRAINT film_actor_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actor(actor_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: film_actor film_actor_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_actor
    ADD CONSTRAINT film_actor_film_id_fkey FOREIGN KEY (film_id) REFERENCES public.film(film_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: film_category film_category_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_category
    ADD CONSTRAINT film_category_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.category(category_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: film_category film_category_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_category
    ADD CONSTRAINT film_category_film_id_fkey FOREIGN KEY (film_id) REFERENCES public.film(film_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: film_flag film_flag_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_flag
    ADD CONSTRAINT film_flag_film_id_fkey FOREIGN KEY (film_id) REFERENCES public.film(film_id) ON DELETE CASCADE;


--
-- Name: film_flag film_flag_flag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_flag
    ADD CONSTRAINT film_flag_flag_id_fkey FOREIGN KEY (flag_id) REFERENCES public.flag(id) ON DELETE CASCADE;


--
-- Name: film film_language_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film
    ADD CONSTRAINT film_language_id_fkey FOREIGN KEY (language_id) REFERENCES public.language(language_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: film film_original_language_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film
    ADD CONSTRAINT film_original_language_id_fkey FOREIGN KEY (original_language_id) REFERENCES public.language(language_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: film_tag film_tag_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_tag
    ADD CONSTRAINT film_tag_film_id_fkey FOREIGN KEY (film_id) REFERENCES public.film(film_id) ON DELETE CASCADE;


--
-- Name: film_tag film_tag_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.film_tag
    ADD CONSTRAINT film_tag_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tag(id) ON DELETE CASCADE;


--
-- Name: inventory inventory_film_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_film_id_fkey FOREIGN KEY (film_id) REFERENCES public.film(film_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory inventory_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.store(store_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: parameterized_products parameterized_products_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parameterized_products
    ADD CONSTRAINT parameterized_products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.product_categories(id) ON DELETE RESTRICT;


--
-- Name: payment_p2022_01 payment_p2022_01_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_01
    ADD CONSTRAINT payment_p2022_01_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id);


--
-- Name: payment_p2022_01 payment_p2022_01_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_01
    ADD CONSTRAINT payment_p2022_01_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES public.rental(rental_id);


--
-- Name: payment_p2022_01 payment_p2022_01_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_01
    ADD CONSTRAINT payment_p2022_01_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(staff_id);


--
-- Name: payment_p2022_02 payment_p2022_02_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_02
    ADD CONSTRAINT payment_p2022_02_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id);


--
-- Name: payment_p2022_02 payment_p2022_02_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_02
    ADD CONSTRAINT payment_p2022_02_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES public.rental(rental_id);


--
-- Name: payment_p2022_02 payment_p2022_02_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_02
    ADD CONSTRAINT payment_p2022_02_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(staff_id);


--
-- Name: payment_p2022_03 payment_p2022_03_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_03
    ADD CONSTRAINT payment_p2022_03_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id);


--
-- Name: payment_p2022_03 payment_p2022_03_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_03
    ADD CONSTRAINT payment_p2022_03_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES public.rental(rental_id);


--
-- Name: payment_p2022_03 payment_p2022_03_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_03
    ADD CONSTRAINT payment_p2022_03_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(staff_id);


--
-- Name: payment_p2022_04 payment_p2022_04_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_04
    ADD CONSTRAINT payment_p2022_04_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id);


--
-- Name: payment_p2022_04 payment_p2022_04_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_04
    ADD CONSTRAINT payment_p2022_04_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES public.rental(rental_id);


--
-- Name: payment_p2022_04 payment_p2022_04_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_04
    ADD CONSTRAINT payment_p2022_04_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(staff_id);


--
-- Name: payment_p2022_05 payment_p2022_05_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_05
    ADD CONSTRAINT payment_p2022_05_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id);


--
-- Name: payment_p2022_05 payment_p2022_05_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_05
    ADD CONSTRAINT payment_p2022_05_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES public.rental(rental_id);


--
-- Name: payment_p2022_05 payment_p2022_05_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_05
    ADD CONSTRAINT payment_p2022_05_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(staff_id);


--
-- Name: payment_p2022_06 payment_p2022_06_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_06
    ADD CONSTRAINT payment_p2022_06_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id);


--
-- Name: payment_p2022_06 payment_p2022_06_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_06
    ADD CONSTRAINT payment_p2022_06_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES public.rental(rental_id);


--
-- Name: payment_p2022_06 payment_p2022_06_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_p2022_06
    ADD CONSTRAINT payment_p2022_06_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(staff_id);


--
-- Name: planets planets_solar_system_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planets
    ADD CONSTRAINT planets_solar_system_id_fkey FOREIGN KEY (solar_system_id) REFERENCES public.solar_systems(id);


--
-- Name: post_categories post_categories_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_categories
    ADD CONSTRAINT post_categories_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- Name: post_categories post_categories_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_categories
    ADD CONSTRAINT post_categories_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_tags post_tags_blog_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_blog_tag_id_fkey FOREIGN KEY (blog_tag_id) REFERENCES public.blog_tags(id) ON DELETE CASCADE;


--
-- Name: post_tags post_tags_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: posts posts_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.authors(id) ON DELETE SET NULL;


--
-- Name: product_categories product_categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.product_categories(id) ON DELETE SET NULL;


--
-- Name: product_reviews product_reviews_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_reviews
    ADD CONSTRAINT product_reviews_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.parameterized_products(id) ON DELETE CASCADE;


--
-- Name: product_reviews product_reviews_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_reviews
    ADD CONSTRAINT product_reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.test_users(id) ON DELETE CASCADE;


--
-- Name: regional_pricing regional_pricing_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regional_pricing
    ADD CONSTRAINT regional_pricing_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.parameterized_products(id) ON DELETE CASCADE;


--
-- Name: rental rental_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental
    ADD CONSTRAINT rental_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental rental_inventory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental
    ADD CONSTRAINT rental_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES public.inventory(inventory_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental rental_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental
    ADD CONSTRAINT rental_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(staff_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: satellites satellites_planet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.satellites
    ADD CONSTRAINT satellites_planet_id_fkey FOREIGN KEY (planet_id) REFERENCES public.planets(id);


--
-- Name: seasonal_discounts seasonal_discounts_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seasonal_discounts
    ADD CONSTRAINT seasonal_discounts_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.parameterized_products(id) ON DELETE CASCADE;


--
-- Name: staff staff_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: staff staff_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.store(store_id);


--
-- Name: store store_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store
    ADD CONSTRAINT store_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: user_preferences user_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.test_users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict rg0elzNot8GCe2OeIm2dN7XcZUmVl8eizTI0GhAcRdTd4bieELRlqZAfHzVwmy2

INSERT INTO public."schema_migrations" (version) VALUES (20221015214453);
INSERT INTO public."schema_migrations" (version) VALUES (20221015214649);
INSERT INTO public."schema_migrations" (version) VALUES (20221015214850);
INSERT INTO public."schema_migrations" (version) VALUES (20221221055639);
INSERT INTO public."schema_migrations" (version) VALUES (20240411000000);
INSERT INTO public."schema_migrations" (version) VALUES (20240411201849);
INSERT INTO public."schema_migrations" (version) VALUES (20240411202734);
INSERT INTO public."schema_migrations" (version) VALUES (20250812000001);
INSERT INTO public."schema_migrations" (version) VALUES (20250812000002);
INSERT INTO public."schema_migrations" (version) VALUES (20250812000003);
INSERT INTO public."schema_migrations" (version) VALUES (20250812000004);
INSERT INTO public."schema_migrations" (version) VALUES (20250812000005);
INSERT INTO public."schema_migrations" (version) VALUES (20250812000006);
INSERT INTO public."schema_migrations" (version) VALUES (20250812000007);
INSERT INTO public."schema_migrations" (version) VALUES (20250828190954);
INSERT INTO public."schema_migrations" (version) VALUES (20250903153702);
INSERT INTO public."schema_migrations" (version) VALUES (20250911162452);
INSERT INTO public."schema_migrations" (version) VALUES (20250912191320);
INSERT INTO public."schema_migrations" (version) VALUES (20250916032340);
INSERT INTO public."schema_migrations" (version) VALUES (20260225143000);
INSERT INTO public."schema_migrations" (version) VALUES (20260316155432);
