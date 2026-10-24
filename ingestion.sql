--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.ingestion_salerecord DROP CONSTRAINT IF EXISTS ingestion_salerecord_source_run_id_74dd04e2_fk_ingestion;
ALTER TABLE IF EXISTS ONLY public.ingestion_salerecord DROP CONSTRAINT IF EXISTS ingestion_salerecord_product_id_b9089e13_fk_ingestion;
ALTER TABLE IF EXISTS ONLY public.ingestion_rejectedrecord DROP CONSTRAINT IF EXISTS ingestion_rejectedre_ingestion_run_id_427d9e54_fk_ingestion;
ALTER TABLE IF EXISTS ONLY public.django_admin_log DROP CONSTRAINT IF EXISTS django_admin_log_user_id_c564eba6_fk_auth_user_id;
ALTER TABLE IF EXISTS ONLY public.django_admin_log DROP CONSTRAINT IF EXISTS django_admin_log_content_type_id_c4bce8eb_fk_django_co;
ALTER TABLE IF EXISTS ONLY public.auth_user_user_permissions DROP CONSTRAINT IF EXISTS auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id;
ALTER TABLE IF EXISTS ONLY public.auth_user_user_permissions DROP CONSTRAINT IF EXISTS auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm;
ALTER TABLE IF EXISTS ONLY public.auth_user_groups DROP CONSTRAINT IF EXISTS auth_user_groups_user_id_6a12ed8b_fk_auth_user_id;
ALTER TABLE IF EXISTS ONLY public.auth_user_groups DROP CONSTRAINT IF EXISTS auth_user_groups_group_id_97559544_fk_auth_group_id;
ALTER TABLE IF EXISTS ONLY public.auth_permission DROP CONSTRAINT IF EXISTS auth_permission_content_type_id_2f476e4b_fk_django_co;
ALTER TABLE IF EXISTS ONLY public.auth_group_permissions DROP CONSTRAINT IF EXISTS auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
ALTER TABLE IF EXISTS ONLY public.auth_group_permissions DROP CONSTRAINT IF EXISTS auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
DROP INDEX IF EXISTS public.sale_sold_at_idx;
DROP INDEX IF EXISTS public.sale_sku_date_idx;
DROP INDEX IF EXISTS public.reject_run_row_idx;
DROP INDEX IF EXISTS public.ingestion_salerecord_source_run_id_74dd04e2;
DROP INDEX IF EXISTS public.ingestion_salerecord_product_id_b9089e13;
DROP INDEX IF EXISTS public.ingestion_rejectedrecord_ingestion_run_id_427d9e54;
DROP INDEX IF EXISTS public.ingestion_product_sku_1a923e5d_like;
DROP INDEX IF EXISTS public.django_session_session_key_c0390e0f_like;
DROP INDEX IF EXISTS public.django_session_expire_date_a5c62663;
DROP INDEX IF EXISTS public.django_admin_log_user_id_c564eba6;
DROP INDEX IF EXISTS public.django_admin_log_content_type_id_c4bce8eb;
DROP INDEX IF EXISTS public.auth_user_username_6821ab7c_like;
DROP INDEX IF EXISTS public.auth_user_user_permissions_user_id_a95ead1b;
DROP INDEX IF EXISTS public.auth_user_user_permissions_permission_id_1fbb5f2c;
DROP INDEX IF EXISTS public.auth_user_groups_user_id_6a12ed8b;
DROP INDEX IF EXISTS public.auth_user_groups_group_id_97559544;
DROP INDEX IF EXISTS public.auth_permission_content_type_id_2f476e4b;
DROP INDEX IF EXISTS public.auth_group_permissions_permission_id_84c5c92e;
DROP INDEX IF EXISTS public.auth_group_permissions_group_id_b120cbf9;
DROP INDEX IF EXISTS public.auth_group_name_a6ea08ec_like;
ALTER TABLE IF EXISTS ONLY public.ingestion_salerecord DROP CONSTRAINT IF EXISTS uniq_sale_transaction_sku;
ALTER TABLE IF EXISTS ONLY public.ingestion_salerecord DROP CONSTRAINT IF EXISTS ingestion_salerecord_pkey;
ALTER TABLE IF EXISTS ONLY public.ingestion_rejectedrecord DROP CONSTRAINT IF EXISTS ingestion_rejectedrecord_pkey;
ALTER TABLE IF EXISTS ONLY public.ingestion_product DROP CONSTRAINT IF EXISTS ingestion_product_sku_key;
ALTER TABLE IF EXISTS ONLY public.ingestion_product DROP CONSTRAINT IF EXISTS ingestion_product_pkey;
ALTER TABLE IF EXISTS ONLY public.ingestion_ingestionrun DROP CONSTRAINT IF EXISTS ingestion_ingestionrun_pkey;
ALTER TABLE IF EXISTS ONLY public.django_session DROP CONSTRAINT IF EXISTS django_session_pkey;
ALTER TABLE IF EXISTS ONLY public.django_migrations DROP CONSTRAINT IF EXISTS django_migrations_pkey;
ALTER TABLE IF EXISTS ONLY public.django_content_type DROP CONSTRAINT IF EXISTS django_content_type_pkey;
ALTER TABLE IF EXISTS ONLY public.django_content_type DROP CONSTRAINT IF EXISTS django_content_type_app_label_model_76bd3d3b_uniq;
ALTER TABLE IF EXISTS ONLY public.django_admin_log DROP CONSTRAINT IF EXISTS django_admin_log_pkey;
ALTER TABLE IF EXISTS ONLY public.auth_user DROP CONSTRAINT IF EXISTS auth_user_username_key;
ALTER TABLE IF EXISTS ONLY public.auth_user_user_permissions DROP CONSTRAINT IF EXISTS auth_user_user_permissions_user_id_permission_id_14a6b632_uniq;
ALTER TABLE IF EXISTS ONLY public.auth_user_user_permissions DROP CONSTRAINT IF EXISTS auth_user_user_permissions_pkey;
ALTER TABLE IF EXISTS ONLY public.auth_user DROP CONSTRAINT IF EXISTS auth_user_pkey;
ALTER TABLE IF EXISTS ONLY public.auth_user_groups DROP CONSTRAINT IF EXISTS auth_user_groups_user_id_group_id_94350c0c_uniq;
ALTER TABLE IF EXISTS ONLY public.auth_user_groups DROP CONSTRAINT IF EXISTS auth_user_groups_pkey;
ALTER TABLE IF EXISTS ONLY public.auth_permission DROP CONSTRAINT IF EXISTS auth_permission_pkey;
ALTER TABLE IF EXISTS ONLY public.auth_permission DROP CONSTRAINT IF EXISTS auth_permission_content_type_id_codename_01ab375a_uniq;
ALTER TABLE IF EXISTS ONLY public.auth_group DROP CONSTRAINT IF EXISTS auth_group_pkey;
ALTER TABLE IF EXISTS ONLY public.auth_group_permissions DROP CONSTRAINT IF EXISTS auth_group_permissions_pkey;
ALTER TABLE IF EXISTS ONLY public.auth_group_permissions DROP CONSTRAINT IF EXISTS auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
ALTER TABLE IF EXISTS ONLY public.auth_group DROP CONSTRAINT IF EXISTS auth_group_name_key;
DROP TABLE IF EXISTS public.ingestion_rejectedrecord;
DROP TABLE IF EXISTS public.ingestion_ingestionrun;
DROP TABLE IF EXISTS public.django_session;
DROP TABLE IF EXISTS public.django_migrations;
DROP TABLE IF EXISTS public.django_content_type;
DROP TABLE IF EXISTS public.django_admin_log;
DROP TABLE IF EXISTS public.auth_user_user_permissions;
DROP TABLE IF EXISTS public.auth_user_groups;
DROP TABLE IF EXISTS public.auth_user;
DROP TABLE IF EXISTS public.auth_permission;
DROP TABLE IF EXISTS public.auth_group_permissions;
DROP TABLE IF EXISTS public.auth_group;
DROP TABLE IF EXISTS public.ingestion_salerecord;
DROP TABLE IF EXISTS public.ingestion_product;
DROP SCHEMA IF EXISTS public;
--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ingestion_product; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_product (
    id bigint NOT NULL,
    sku character varying(100) NOT NULL,
    name character varying(200) NOT NULL,
    category character varying(100) NOT NULL,
    active boolean NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: ingestion_salerecord; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_salerecord (
    id bigint NOT NULL,
    transaction_id character varying(150) NOT NULL,
    sold_at timestamp with time zone NOT NULL,
    sku character varying(100) NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    unit_cost numeric(12,2) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    source_run_id uuid NOT NULL,
    product_id bigint,
    CONSTRAINT ingestion_salerecord_quantity_check CHECK ((quantity >= 0)),
    CONSTRAINT sale_quantity_positive CHECK ((quantity > 0)),
    CONSTRAINT sale_unit_cost_nonnegative CHECK ((unit_cost >= (0)::numeric)),
    CONSTRAINT sale_unit_price_nonnegative CHECK ((unit_price >= (0)::numeric))
);


--
-- Name: auth_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);


--
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


--
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_user (
    id integer NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    username character varying(150) NOT NULL,
    first_name character varying(150) NOT NULL,
    last_name character varying(150) NOT NULL,
    email character varying(254) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL
);


--
-- Name: auth_user_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_user_groups (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_user_groups ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_user_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_user ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_user_user_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_user_user_permissions (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    permission_id integer NOT NULL
);


--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auth_user_user_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_user_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_admin_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id integer NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);


--
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


--
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


--
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_session; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


--
-- Name: ingestion_ingestionrun; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_ingestionrun (
    id uuid NOT NULL,
    original_filename character varying(255) NOT NULL,
    raw_file character varying(500) NOT NULL,
    status character varying(20) NOT NULL,
    rows_read integer NOT NULL,
    rows_valid integer NOT NULL,
    rows_rejected integer NOT NULL,
    error_message text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    CONSTRAINT ingestion_ingestionrun_rows_read_check CHECK ((rows_read >= 0)),
    CONSTRAINT ingestion_ingestionrun_rows_rejected_check CHECK ((rows_rejected >= 0)),
    CONSTRAINT ingestion_ingestionrun_rows_valid_check CHECK ((rows_valid >= 0))
);


--
-- Name: ingestion_product_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.ingestion_product ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.ingestion_product_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ingestion_rejectedrecord; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_rejectedrecord (
    id bigint NOT NULL,
    source_row_number integer NOT NULL,
    raw_data jsonb NOT NULL,
    reason character varying(500) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    ingestion_run_id uuid NOT NULL,
    CONSTRAINT ingestion_rejectedrecord_source_row_number_check CHECK ((source_row_number >= 0))
);


--
-- Name: ingestion_rejectedrecord_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.ingestion_rejectedrecord ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.ingestion_rejectedrecord_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ingestion_salerecord_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.ingestion_salerecord ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.ingestion_salerecord_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: auth_group; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_group (id, name) FROM stdin;
\.


--
-- Data for Name: auth_group_permissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
\.


--
-- Data for Name: auth_permission; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
1	Can add log entry	1	add_logentry
2	Can change log entry	1	change_logentry
3	Can delete log entry	1	delete_logentry
4	Can view log entry	1	view_logentry
5	Can add permission	2	add_permission
6	Can change permission	2	change_permission
7	Can delete permission	2	delete_permission
8	Can view permission	2	view_permission
9	Can add group	3	add_group
10	Can change group	3	change_group
11	Can delete group	3	delete_group
12	Can view group	3	view_group
13	Can add user	4	add_user
14	Can change user	4	change_user
15	Can delete user	4	delete_user
16	Can view user	4	view_user
17	Can add content type	5	add_contenttype
18	Can change content type	5	change_contenttype
19	Can delete content type	5	delete_contenttype
20	Can view content type	5	view_contenttype
21	Can add session	6	add_session
22	Can change session	6	change_session
23	Can delete session	6	delete_session
24	Can view session	6	view_session
25	Can add ingestion run	7	add_ingestionrun
26	Can change ingestion run	7	change_ingestionrun
27	Can delete ingestion run	7	delete_ingestionrun
28	Can view ingestion run	7	view_ingestionrun
29	Can add rejected record	8	add_rejectedrecord
30	Can change rejected record	8	change_rejectedrecord
31	Can delete rejected record	8	delete_rejectedrecord
32	Can view rejected record	8	view_rejectedrecord
33	Can add sale record	9	add_salerecord
34	Can change sale record	9	change_salerecord
35	Can delete sale record	9	delete_salerecord
36	Can view sale record	9	view_salerecord
37	Can add product	10	add_product
38	Can change product	10	change_product
39	Can delete product	10	delete_product
40	Can view product	10	view_product
\.


--
-- Data for Name: auth_user; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_user (id, password, last_login, is_superuser, username, first_name, last_name, email, is_staff, is_active, date_joined) FROM stdin;
\.


--
-- Data for Name: auth_user_groups; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_user_groups (id, user_id, group_id) FROM stdin;
\.


--
-- Data for Name: auth_user_user_permissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_user_user_permissions (id, user_id, permission_id) FROM stdin;
\.


--
-- Data for Name: django_admin_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
\.


--
-- Data for Name: django_content_type; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.django_content_type (id, app_label, model) FROM stdin;
1	admin	logentry
2	auth	permission
3	auth	group
4	auth	user
5	contenttypes	contenttype
6	sessions	session
7	ingestion	ingestionrun
8	ingestion	rejectedrecord
9	ingestion	salerecord
10	ingestion	product
\.


--
-- Data for Name: django_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.django_migrations (id, app, name, applied) FROM stdin;
1	contenttypes	0001_initial	2026-10-24 18:25:28.733631+03
2	auth	0001_initial	2026-10-24 18:25:28.901747+03
3	admin	0001_initial	2026-10-24 18:25:28.994064+03
4	admin	0002_logentry_remove_auto_add	2026-10-24 18:25:29.002864+03
5	admin	0003_logentry_add_action_flag_choices	2026-10-24 18:25:29.020486+03
6	contenttypes	0002_remove_content_type_name	2026-10-24 18:25:29.05108+03
7	auth	0002_alter_permission_name_max_length	2026-10-24 18:25:29.066581+03
8	auth	0003_alter_user_email_max_length	2026-10-24 18:25:29.066581+03
9	auth	0004_alter_user_username_opts	2026-10-24 18:25:29.095359+03
10	auth	0005_alter_user_last_login_null	2026-10-24 18:25:29.12109+03
11	auth	0006_require_contenttypes_0002	2026-10-24 18:25:29.12109+03
12	auth	0007_alter_validators_add_error_messages	2026-10-24 18:25:29.142383+03
13	auth	0008_alter_user_username_max_length	2026-10-24 18:25:29.175721+03
14	auth	0009_alter_user_last_name_max_length	2026-10-24 18:25:29.191703+03
15	auth	0010_alter_group_name_max_length	2026-10-24 18:25:29.218045+03
16	auth	0011_update_proxy_permissions	2026-10-24 18:25:29.233311+03
17	auth	0012_alter_user_first_name_max_length	2026-10-24 18:25:29.256236+03
18	ingestion	0001_initial	2026-10-24 18:25:29.268933+03
19	ingestion	0002_rejectedrecord_salerecord	2026-10-24 18:25:29.385469+03
20	sessions	0001_initial	2026-10-24 18:25:29.409439+03
21	ingestion	0003_product_salerecord_product	2026-10-24 18:38:23.698064+03
\.


--
-- Data for Name: django_session; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
\.


--
-- Data for Name: ingestion_ingestionrun; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingestion_ingestionrun (id, original_filename, raw_file, status, rows_read, rows_valid, rows_rejected, error_message, created_at, completed_at) FROM stdin;
9babf604-c5b9-4f2c-9e9d-a53dfccb72d7	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\9babf604-c5b9-4f2c-9e9d-a53dfccb72d7.csv	PENDING	0	0	0		2026-10-24 18:58:12.522705+03	\N
f52f7297-004a-465d-8688-4962b07f33e0	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\f52f7297-004a-465d-8688-4962b07f33e0.csv	PENDING	0	0	0		2026-10-24 19:03:37.269418+03	\N
f5b0b277-d687-4f24-ab4f-857afa270d4a	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\f5b0b277-d687-4f24-ab4f-857afa270d4a.csv	PENDING	0	0	0		2026-10-24 19:05:50.090366+03	\N
92959120-2f75-4819-8268-4acb01395f13	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\92959120-2f75-4819-8268-4acb01395f13.csv	PENDING	0	0	0		2026-10-24 19:07:02.218271+03	\N
6feb3a1f-43b9-4f09-8c8b-73ae98f3d849	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\6feb3a1f-43b9-4f09-8c8b-73ae98f3d849.csv	PENDING	0	0	0		2026-10-24 19:08:06.381923+03	\N
2e7945cd-75c1-4003-8efb-d1a58d9a56c2	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\2e7945cd-75c1-4003-8efb-d1a58d9a56c2.csv	SUCCEEDED	6	5	1		2026-10-24 19:13:35.831755+03	2026-10-24 19:13:35.877678+03
784384cf-104a-4065-a6ee-82fa1b75e153	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\784384cf-104a-4065-a6ee-82fa1b75e153.csv	SUCCEEDED	6	5	1		2026-10-24 19:14:23.721591+03	2026-10-24 19:14:23.747651+03
a328a53d-b146-4d81-9978-5f9215eac05e	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\a328a53d-b146-4d81-9978-5f9215eac05e.csv	SUCCEEDED	6	5	1		2026-10-24 19:17:52.882667+03	2026-10-24 19:17:52.947734+03
\.


--
-- Data for Name: ingestion_product; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingestion_product (id, sku, name, category, active, created_at, updated_at) FROM stdin;
26	SKU-003	SKU-003	Uncategorised	t	2026-10-24 19:13:35.873154+03	2026-10-24 19:13:35.873154+03
27	SKU-002	SKU-002	Uncategorised	t	2026-10-24 19:13:35.873154+03	2026-10-24 19:13:35.873154+03
28	SKU-004	SKU-004	Uncategorised	t	2026-10-24 19:13:35.873154+03	2026-10-24 19:13:35.873154+03
29	SKU-001	SKU-001	Uncategorised	t	2026-10-24 19:13:35.873154+03	2026-10-24 19:13:35.873154+03
30	SKU-005	SKU-005	Uncategorised	t	2026-10-24 19:13:35.873154+03	2026-10-24 19:13:35.873154+03
\.


--
-- Data for Name: ingestion_rejectedrecord; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingestion_rejectedrecord (id, source_row_number, raw_data, reason, created_at, ingestion_run_id) FROM stdin;
6	4	{"sku": "SKU-001", "sold_at": "2026-10-20 10:30:00", "quantity": "3", "unit_cost": "15.0", "unit_price": "25.0", "transaction_id": "TXN-1001"}	Duplicate transaction_id and SKU in file	2026-10-24 19:13:35.850893+03	2e7945cd-75c1-4003-8efb-d1a58d9a56c2
7	4	{"sku": "SKU-001", "sold_at": "2026-10-20 10:30:00", "quantity": "3", "unit_cost": "15.0", "unit_price": "25.0", "transaction_id": "TXN-1001"}	Duplicate transaction_id and SKU in file	2026-10-24 19:14:23.736591+03	784384cf-104a-4065-a6ee-82fa1b75e153
8	4	{"sku": "SKU-001", "sold_at": "2026-10-20 10:30:00", "quantity": "3", "unit_cost": "15.0", "unit_price": "100.0", "transaction_id": "TXN-1001"}	Duplicate transaction_id and SKU in file	2026-10-24 19:17:52.922476+03	a328a53d-b146-4d81-9978-5f9215eac05e
\.


--
-- Data for Name: ingestion_salerecord; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingestion_salerecord (id, transaction_id, sold_at, sku, quantity, unit_price, unit_cost, created_at, source_run_id, product_id) FROM stdin;
1	TXN-1001	2026-10-20 13:30:00+03	SKU-001	3	25.00	15.00	2026-10-24 19:13:35.877678+03	2e7945cd-75c1-4003-8efb-d1a58d9a56c2	29
2	TXN-1002	2026-10-20 14:15:00+03	SKU-002	2	40.00	22.00	2026-10-24 19:13:35.877678+03	2e7945cd-75c1-4003-8efb-d1a58d9a56c2	27
3	TXN-1004	2026-10-20 16:30:00+03	SKU-003	4	12.50	7.00	2026-10-24 19:13:35.877678+03	2e7945cd-75c1-4003-8efb-d1a58d9a56c2	26
4	TXN-1005	2026-10-20 17:10:00+03	SKU-004	2	60.00	35.00	2026-10-24 19:13:35.877678+03	2e7945cd-75c1-4003-8efb-d1a58d9a56c2	28
5	TXN-1006	2026-10-20 17:10:00+03	SKU-005	2	68.00	25.00	2026-10-24 19:13:35.877678+03	2e7945cd-75c1-4003-8efb-d1a58d9a56c2	30
\.


--
-- Name: auth_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);


--
-- Name: auth_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_permission_id_seq', 40, true);


--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_user_groups_id_seq', 1, false);


--
-- Name: auth_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_user_id_seq', 1, false);


--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auth_user_user_permissions_id_seq', 1, false);


--
-- Name: django_admin_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);


--
-- Name: django_content_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.django_content_type_id_seq', 10, true);


--
-- Name: django_migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.django_migrations_id_seq', 21, true);


--
-- Name: ingestion_product_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ingestion_product_id_seq', 30, true);


--
-- Name: ingestion_rejectedrecord_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ingestion_rejectedrecord_id_seq', 8, true);


--
-- Name: ingestion_salerecord_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ingestion_salerecord_id_seq', 5, true);


--
-- Name: auth_group auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- Name: auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);


--
-- Name: auth_group_permissions auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_group auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- Name: auth_permission auth_permission_content_type_id_codename_01ab375a_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);


--
-- Name: auth_permission auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups auth_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups auth_user_groups_user_id_group_id_94350c0c_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_group_id_94350c0c_uniq UNIQUE (user_id, group_id);


--
-- Name: auth_user auth_user_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user
    ADD CONSTRAINT auth_user_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions auth_user_user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_permission_id_14a6b632_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_permission_id_14a6b632_uniq UNIQUE (user_id, permission_id);


--
-- Name: auth_user auth_user_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user
    ADD CONSTRAINT auth_user_username_key UNIQUE (username);


--
-- Name: django_admin_log django_admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- Name: django_content_type django_content_type_app_label_model_76bd3d3b_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);


--
-- Name: django_content_type django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- Name: django_migrations django_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- Name: django_session django_session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- Name: ingestion_ingestionrun ingestion_ingestionrun_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_ingestionrun
    ADD CONSTRAINT ingestion_ingestionrun_pkey PRIMARY KEY (id);


--
-- Name: ingestion_product ingestion_product_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_product
    ADD CONSTRAINT ingestion_product_pkey PRIMARY KEY (id);


--
-- Name: ingestion_product ingestion_product_sku_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_product
    ADD CONSTRAINT ingestion_product_sku_key UNIQUE (sku);


--
-- Name: ingestion_rejectedrecord ingestion_rejectedrecord_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_rejectedrecord
    ADD CONSTRAINT ingestion_rejectedrecord_pkey PRIMARY KEY (id);


--
-- Name: ingestion_salerecord ingestion_salerecord_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_salerecord
    ADD CONSTRAINT ingestion_salerecord_pkey PRIMARY KEY (id);


--
-- Name: ingestion_salerecord uniq_sale_transaction_sku; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_salerecord
    ADD CONSTRAINT uniq_sale_transaction_sku UNIQUE (transaction_id, sku);


--
-- Name: auth_group_name_a6ea08ec_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);


--
-- Name: auth_group_permissions_group_id_b120cbf9; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);


--
-- Name: auth_group_permissions_permission_id_84c5c92e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);


--
-- Name: auth_permission_content_type_id_2f476e4b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);


--
-- Name: auth_user_groups_group_id_97559544; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_user_groups_group_id_97559544 ON public.auth_user_groups USING btree (group_id);


--
-- Name: auth_user_groups_user_id_6a12ed8b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_user_groups_user_id_6a12ed8b ON public.auth_user_groups USING btree (user_id);


--
-- Name: auth_user_user_permissions_permission_id_1fbb5f2c; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_user_user_permissions_permission_id_1fbb5f2c ON public.auth_user_user_permissions USING btree (permission_id);


--
-- Name: auth_user_user_permissions_user_id_a95ead1b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_user_user_permissions_user_id_a95ead1b ON public.auth_user_user_permissions USING btree (user_id);


--
-- Name: auth_user_username_6821ab7c_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auth_user_username_6821ab7c_like ON public.auth_user USING btree (username varchar_pattern_ops);


--
-- Name: django_admin_log_content_type_id_c4bce8eb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);


--
-- Name: django_admin_log_user_id_c564eba6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);


--
-- Name: django_session_expire_date_a5c62663; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);


--
-- Name: django_session_session_key_c0390e0f_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);


--
-- Name: ingestion_product_sku_1a923e5d_like; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingestion_product_sku_1a923e5d_like ON public.ingestion_product USING btree (sku varchar_pattern_ops);


--
-- Name: ingestion_rejectedrecord_ingestion_run_id_427d9e54; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingestion_rejectedrecord_ingestion_run_id_427d9e54 ON public.ingestion_rejectedrecord USING btree (ingestion_run_id);


--
-- Name: ingestion_salerecord_product_id_b9089e13; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingestion_salerecord_product_id_b9089e13 ON public.ingestion_salerecord USING btree (product_id);


--
-- Name: ingestion_salerecord_source_run_id_74dd04e2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ingestion_salerecord_source_run_id_74dd04e2 ON public.ingestion_salerecord USING btree (source_run_id);


--
-- Name: reject_run_row_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reject_run_row_idx ON public.ingestion_rejectedrecord USING btree (ingestion_run_id, source_row_number);


--
-- Name: sale_sku_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sale_sku_date_idx ON public.ingestion_salerecord USING btree (sku, sold_at);


--
-- Name: sale_sold_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sale_sold_at_idx ON public.ingestion_salerecord USING btree (sold_at);


--
-- Name: auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups auth_user_groups_group_id_97559544_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_group_id_97559544_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups auth_user_groups_user_id_6a12ed8b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_6a12ed8b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log django_admin_log_user_id_c564eba6_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: ingestion_rejectedrecord ingestion_rejectedre_ingestion_run_id_427d9e54_fk_ingestion; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_rejectedrecord
    ADD CONSTRAINT ingestion_rejectedre_ingestion_run_id_427d9e54_fk_ingestion FOREIGN KEY (ingestion_run_id) REFERENCES public.ingestion_ingestionrun(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: ingestion_salerecord ingestion_salerecord_product_id_b9089e13_fk_ingestion; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_salerecord
    ADD CONSTRAINT ingestion_salerecord_product_id_b9089e13_fk_ingestion FOREIGN KEY (product_id) REFERENCES public.ingestion_product(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: ingestion_salerecord ingestion_salerecord_source_run_id_74dd04e2_fk_ingestion; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_salerecord
    ADD CONSTRAINT ingestion_salerecord_source_run_id_74dd04e2_fk_ingestion FOREIGN KEY (source_run_id) REFERENCES public.ingestion_ingestionrun(id) DEFERRABLE INITIALLY DEFERRED;


--
-- PostgreSQL database dump complete
--

