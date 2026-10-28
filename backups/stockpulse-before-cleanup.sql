--
-- PostgreSQL database dump
--

\restrict nbXFQYgO6GtOPNf2htgKflKLJjczJfvVkkQPeI91Y3mdxaqQwzoB3pJyNWgNYEm

-- Dumped from database version 17.11 (Debian 17.11-1.pgdg13+2)
-- Dumped by pg_dump version 17.11 (Debian 17.11-1.pgdg13+2)

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

--
-- Name: analytics_marts; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA analytics_marts;


ALTER SCHEMA analytics_marts OWNER TO postgres;

--
-- Name: analytics_staging; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA analytics_staging;


ALTER SCHEMA analytics_staging OWNER TO postgres;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: fct_daily_sales; Type: TABLE; Schema: analytics_marts; Owner: postgres
--

CREATE TABLE analytics_marts.fct_daily_sales (
    sale_date date,
    sales_lines bigint,
    transactions bigint,
    units_sold bigint,
    revenue numeric,
    cost_of_goods_sold numeric,
    gross_profit numeric,
    gross_margin_rate numeric
);


ALTER TABLE analytics_marts.fct_daily_sales OWNER TO postgres;

--
-- Name: mart_product_performance; Type: TABLE; Schema: analytics_marts; Owner: postgres
--

CREATE TABLE analytics_marts.mart_product_performance (
    sku character varying(100),
    product_name text,
    category text,
    units_sold bigint,
    sales_lines bigint,
    transactions bigint,
    revenue numeric,
    cost_of_goods_sold numeric,
    gross_profit numeric
);


ALTER TABLE analytics_marts.mart_product_performance OWNER TO postgres;

--
-- Name: ingestion_product; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.ingestion_product OWNER TO postgres;

--
-- Name: stg_products; Type: VIEW; Schema: analytics_staging; Owner: postgres
--

CREATE VIEW analytics_staging.stg_products AS
 SELECT id AS product_id,
    sku,
    name AS product_name,
    category,
    active AS is_active,
    created_at AS product_created_at,
    updated_at AS product_updated_at
   FROM public.ingestion_product;


ALTER VIEW analytics_staging.stg_products OWNER TO postgres;

--
-- Name: ingestion_salerecord; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.ingestion_salerecord OWNER TO postgres;

--
-- Name: stg_sales; Type: VIEW; Schema: analytics_staging; Owner: postgres
--

CREATE VIEW analytics_staging.stg_sales AS
 SELECT id AS sale_record_id,
    transaction_id,
    sku,
    product_id,
    sold_at,
    quantity,
    unit_price,
    unit_cost,
    source_run_id,
    created_at AS record_created_at
   FROM public.ingestion_salerecord;


ALTER VIEW analytics_staging.stg_sales OWNER TO postgres;

--
-- Name: kafka_sales_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.kafka_sales_events (
    event_id uuid NOT NULL,
    transaction_id character varying(100) NOT NULL,
    sold_at timestamp with time zone NOT NULL,
    sku character varying(100) NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    unit_cost numeric(12,2) NOT NULL,
    raw_payload jsonb NOT NULL,
    ingested_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT kafka_sales_events_quantity_check CHECK ((quantity > 0)),
    CONSTRAINT kafka_sales_events_unit_cost_check CHECK ((unit_cost >= (0)::numeric)),
    CONSTRAINT kafka_sales_events_unit_price_check CHECK ((unit_price >= (0)::numeric))
);


ALTER TABLE public.kafka_sales_events OWNER TO postgres;

--
-- Name: stg_unified_sales; Type: VIEW; Schema: analytics_staging; Owner: postgres
--

CREATE VIEW analytics_staging.stg_unified_sales AS
 WITH django_sales AS (
         SELECT (ingestion_salerecord.id)::text AS record_id,
            ingestion_salerecord.transaction_id,
            ingestion_salerecord.sku,
            ingestion_salerecord.product_id,
            ingestion_salerecord.sold_at,
            ingestion_salerecord.quantity,
            ingestion_salerecord.unit_price,
            ingestion_salerecord.unit_cost,
            ingestion_salerecord.source_run_id,
            ingestion_salerecord.created_at AS record_created_at,
            'django_csv'::text AS source_system,
            1 AS source_priority
           FROM public.ingestion_salerecord
        ), kafka_sales AS (
         SELECT (kafka_sales_events.event_id)::text AS record_id,
            kafka_sales_events.transaction_id,
            kafka_sales_events.sku,
            NULL::bigint AS product_id,
            kafka_sales_events.sold_at,
            kafka_sales_events.quantity,
            kafka_sales_events.unit_price,
            kafka_sales_events.unit_cost,
            NULL::uuid AS source_run_id,
            kafka_sales_events.ingested_at AS record_created_at,
            'kafka'::text AS source_system,
            2 AS source_priority
           FROM public.kafka_sales_events
        ), combined_sales AS (
         SELECT django_sales.record_id,
            django_sales.transaction_id,
            django_sales.sku,
            django_sales.product_id,
            django_sales.sold_at,
            django_sales.quantity,
            django_sales.unit_price,
            django_sales.unit_cost,
            django_sales.source_run_id,
            django_sales.record_created_at,
            django_sales.source_system,
            django_sales.source_priority
           FROM django_sales
        UNION ALL
         SELECT kafka_sales.record_id,
            kafka_sales.transaction_id,
            kafka_sales.sku,
            kafka_sales.product_id,
            kafka_sales.sold_at,
            kafka_sales.quantity,
            kafka_sales.unit_price,
            kafka_sales.unit_cost,
            kafka_sales.source_run_id,
            kafka_sales.record_created_at,
            kafka_sales.source_system,
            kafka_sales.source_priority
           FROM kafka_sales
        ), ranked_sales AS (
         SELECT combined_sales.record_id,
            combined_sales.transaction_id,
            combined_sales.sku,
            combined_sales.product_id,
            combined_sales.sold_at,
            combined_sales.quantity,
            combined_sales.unit_price,
            combined_sales.unit_cost,
            combined_sales.source_run_id,
            combined_sales.record_created_at,
            combined_sales.source_system,
            combined_sales.source_priority,
            row_number() OVER (PARTITION BY combined_sales.transaction_id, combined_sales.sku ORDER BY combined_sales.source_priority, combined_sales.record_created_at, combined_sales.record_id) AS business_key_rank
           FROM combined_sales
        )
 SELECT record_id,
    transaction_id,
    sku,
    product_id,
    sold_at,
    quantity,
    unit_price,
    unit_cost,
    source_run_id,
    record_created_at,
    source_system
   FROM ranked_sales
  WHERE (business_key_rank = 1);


ALTER VIEW analytics_staging.stg_unified_sales OWNER TO postgres;

--
-- Name: auth_group; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);


ALTER TABLE public.auth_group OWNER TO postgres;

--
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
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
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_group_permissions OWNER TO postgres;

--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
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
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


ALTER TABLE public.auth_permission OWNER TO postgres;

--
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
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
-- Name: auth_user; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.auth_user OWNER TO postgres;

--
-- Name: auth_user_groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auth_user_groups (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


ALTER TABLE public.auth_user_groups OWNER TO postgres;

--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
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
-- Name: auth_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
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
-- Name: auth_user_user_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auth_user_user_permissions (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_user_user_permissions OWNER TO postgres;

--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
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
-- Name: django_admin_log; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.django_admin_log OWNER TO postgres;

--
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
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
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


ALTER TABLE public.django_content_type OWNER TO postgres;

--
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
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
-- Name: django_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


ALTER TABLE public.django_migrations OWNER TO postgres;

--
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
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
-- Name: django_session; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


ALTER TABLE public.django_session OWNER TO postgres;

--
-- Name: ingestion_ingestionrun; Type: TABLE; Schema: public; Owner: postgres
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
    validation_errors jsonb NOT NULL,
    CONSTRAINT ingestion_ingestionrun_rows_read_check CHECK ((rows_read >= 0)),
    CONSTRAINT ingestion_ingestionrun_rows_rejected_check CHECK ((rows_rejected >= 0)),
    CONSTRAINT ingestion_ingestionrun_rows_valid_check CHECK ((rows_valid >= 0))
);


ALTER TABLE public.ingestion_ingestionrun OWNER TO postgres;

--
-- Name: ingestion_product_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
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
-- Name: ingestion_rejectedrecord; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.ingestion_rejectedrecord OWNER TO postgres;

--
-- Name: ingestion_rejectedrecord_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
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
-- Name: ingestion_salerecord_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
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
-- Name: kafka_rejected_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.kafka_rejected_events (
    rejection_id bigint NOT NULL,
    event_id text,
    raw_payload jsonb,
    reason text NOT NULL,
    rejected_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.kafka_rejected_events OWNER TO postgres;

--
-- Name: kafka_rejected_events_rejection_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.kafka_rejected_events ALTER COLUMN rejection_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.kafka_rejected_events_rejection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: fct_daily_sales; Type: TABLE DATA; Schema: analytics_marts; Owner: postgres
--

COPY analytics_marts.fct_daily_sales (sale_date, sales_lines, transactions, units_sold, revenue, cost_of_goods_sold, gross_profit, gross_margin_rate) FROM stdin;
2026-09-25	3	3	41	4625.71	2632.71	1993.00	0.43085277719528461577
2026-09-26	2	2	28	3938.47	2508.81	1429.66	0.36299882949470225748
2026-09-27	2	2	24	1578.72	758.80	819.92	0.51935745414006283572
2026-09-28	5	5	68	6591.44	3531.97	3059.47	0.46415805954389329191
2026-09-29	1	1	19	2343.84	1371.04	972.80	0.41504539559014267185
2026-09-30	3	3	23	2660.87	1351.12	1309.75	0.49222622676042046398
2026-10-20	5	5	13	461.00	237.00	224.00	0.48590021691973969631
2026-10-25	28	28	271	31813.31	16941.48	14871.83	0.46747194806199040590
2026-10-26	24	24	179	13501.08	7852.62	5648.46	0.41837097476646312739
2026-10-27	23	23	210	29129.13	15419.38	13709.75	0.47065429005260369946
2026-10-28	22	22	281	30771.32	16836.40	13934.92	0.45285415120313330725
2026-10-29	20	19	196	25233.24	13602.07	11631.17	0.46094635488744212000
2026-10-30	30	28	276	28785.53	14712.77	14072.76	0.48888312982251846674
\.


--
-- Data for Name: mart_product_performance; Type: TABLE DATA; Schema: analytics_marts; Owner: postgres
--

COPY analytics_marts.mart_product_performance (sku, product_name, category, units_sold, sales_lines, transactions, revenue, cost_of_goods_sold, gross_profit) FROM stdin;
SKU-001	SKU-001	Uncategorised	5	2	2	125.00	75.00	50.00
SKU-002	SKU-002	Uncategorised	5	2	2	200.00	128.00	72.00
SKU-003	SKU-003	Uncategorised	4	1	1	50.00	28.00	22.00
SKU-004	SKU-004	Uncategorised	2	1	1	120.00	70.00	50.00
SKU-005	SKU-005	Uncategorised	2	1	1	136.00	50.00	86.00
SKU-100	SKU-100	Uncategorised	10	2	2	967.06	474.42	492.64
SKU-101	SKU-101	Uncategorised	34	5	5	3140.51	1744.50	1396.01
SKU-102	SKU-102	Uncategorised	38	4	4	3830.01	2069.37	1760.64
SKU-103	SKU-103	Uncategorised	47	4	4	2269.78	1286.65	983.13
SKU-104	SKU-104	Uncategorised	57	5	5	6091.19	3625.14	2466.05
SKU-105	SKU-105	Uncategorised	17	3	3	3819.31	2175.60	1643.71
SKU-106	SKU-106	Uncategorised	31	4	4	2638.60	1415.28	1223.32
SKU-107	SKU-107	Uncategorised	34	5	5	2178.12	1369.07	809.05
SKU-108	SKU-108	Uncategorised	37	3	3	3697.93	2392.45	1305.48
SKU-109	SKU-109	Uncategorised	14	3	3	2048.99	1131.59	917.40
SKU-110	SKU-110	Uncategorised	75	8	8	10880.29	5615.51	5264.78
SKU-111	SKU-111	Uncategorised	23	3	3	3679.69	2185.10	1494.59
SKU-112	SKU-112	Uncategorised	72	6	6	9273.01	4601.11	4671.90
SKU-113	SKU-113	Uncategorised	19	3	3	2093.42	1104.41	989.01
SKU-114	SKU-114	Uncategorised	23	2	2	3116.18	1666.15	1450.03
SKU-115	SKU-115	Uncategorised	4	1	1	403.28	190.32	212.96
SKU-116	SKU-116	Uncategorised	29	3	3	3119.89	1884.18	1235.71
SKU-117	SKU-117	Uncategorised	15	3	3	879.15	450.81	428.34
SKU-118	SKU-118	Uncategorised	79	5	5	6660.87	3678.55	2982.32
SKU-119	SKU-119	Uncategorised	4	1	1	537.52	305.96	231.56
SKU-120	SKU-120	Uncategorised	31	3	3	5136.89	2841.96	2294.93
SKU-121	SKU-121	Uncategorised	78	7	7	7989.54	4741.17	3248.37
SKU-122	SKU-122	Uncategorised	51	6	6	5775.25	2968.15	2807.10
SKU-123	SKU-123	Uncategorised	51	3	3	2827.89	1741.58	1086.31
SKU-124	SKU-124	Uncategorised	34	3	3	5741.05	3722.56	2018.49
SKU-125	SKU-125	Uncategorised	67	5	5	7801.16	4124.85	3676.31
SKU-126	SKU-126	Uncategorised	39	2	2	1482.22	708.75	773.47
SKU-127	SKU-127	Uncategorised	13	1	1	86.19	35.10	51.09
SKU-128	SKU-128	Uncategorised	19	3	3	3408.03	1471.56	1936.47
SKU-129	SKU-129	Uncategorised	29	3	3	3863.12	2273.80	1589.32
SKU-130	SKU-130	Uncategorised	28	2	2	2529.56	1246.11	1283.45
SKU-131	SKU-131	Uncategorised	17	2	2	1421.51	943.99	477.52
SKU-133	SKU-133	Uncategorised	59	5	5	7466.28	3447.51	4018.77
SKU-134	SKU-134	Uncategorised	26	2	2	3581.16	1721.54	1859.62
SKU-137	SKU-137	Uncategorised	34	2	2	6520.52	3272.50	3248.02
SKU-138	SKU-138	Uncategorised	66	6	6	6085.69	3291.82	2793.87
SKU-139	SKU-139	Uncategorised	27	3	3	2615.10	1294.38	1320.72
SKU-140	SKU-140	Uncategorised	66	5	5	9054.23	4800.83	4253.40
SKU-141	SKU-141	Uncategorised	41	3	3	3689.71	2073.42	1616.29
SKU-142	SKU-142	Uncategorised	3	1	1	678.96	280.59	398.37
SKU-143	SKU-143	Uncategorised	11	2	2	2221.94	1225.58	996.36
SKU-144	SKU-144	Uncategorised	37	3	3	4264.36	2383.79	1880.57
SKU-145	SKU-145	Uncategorised	23	5	5	2477.64	1445.76	1031.88
SKU-146	SKU-146	Uncategorised	38	2	2	4060.08	2007.16	2052.92
SKU-147	SKU-147	Uncategorised	11	1	1	1502.38	710.16	792.22
SKU-148	SKU-148	Uncategorised	24	2	2	3212.46	1562.50	1649.96
SKU-149	SKU-149	Uncategorised	16	2	2	3333.97	1347.02	1986.95
SKU-150	SKU-150	Uncategorised	6	2	2	148.97	74.86	74.11
TEST-E2E-001	TEST-E2E-001	Uncategorised	2	1	1	251.00	140.00	111.00
TEST-E2E-002	TEST-E2E-002	Uncategorised	2	1	1	251.00	140.00	111.00
\.


--
-- Data for Name: auth_group; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auth_group (id, name) FROM stdin;
\.


--
-- Data for Name: auth_group_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
\.


--
-- Data for Name: auth_permission; Type: TABLE DATA; Schema: public; Owner: postgres
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
-- Data for Name: auth_user; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auth_user (id, password, last_login, is_superuser, username, first_name, last_name, email, is_staff, is_active, date_joined) FROM stdin;
\.


--
-- Data for Name: auth_user_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auth_user_groups (id, user_id, group_id) FROM stdin;
\.


--
-- Data for Name: auth_user_user_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auth_user_user_permissions (id, user_id, permission_id) FROM stdin;
\.


--
-- Data for Name: django_admin_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
\.


--
-- Data for Name: django_content_type; Type: TABLE DATA; Schema: public; Owner: postgres
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
-- Data for Name: django_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.django_migrations (id, app, name, applied) FROM stdin;
1	contenttypes	0001_initial	2026-10-24 15:25:28.733631+00
2	auth	0001_initial	2026-10-24 15:25:28.901747+00
3	admin	0001_initial	2026-10-24 15:25:28.994064+00
4	admin	0002_logentry_remove_auto_add	2026-10-24 15:25:29.002864+00
5	admin	0003_logentry_add_action_flag_choices	2026-10-24 15:25:29.020486+00
6	contenttypes	0002_remove_content_type_name	2026-10-24 15:25:29.05108+00
7	auth	0002_alter_permission_name_max_length	2026-10-24 15:25:29.066581+00
8	auth	0003_alter_user_email_max_length	2026-10-24 15:25:29.066581+00
9	auth	0004_alter_user_username_opts	2026-10-24 15:25:29.095359+00
10	auth	0005_alter_user_last_login_null	2026-10-24 15:25:29.12109+00
11	auth	0006_require_contenttypes_0002	2026-10-24 15:25:29.12109+00
12	auth	0007_alter_validators_add_error_messages	2026-10-24 15:25:29.142383+00
13	auth	0008_alter_user_username_max_length	2026-10-24 15:25:29.175721+00
14	auth	0009_alter_user_last_name_max_length	2026-10-24 15:25:29.191703+00
15	auth	0010_alter_group_name_max_length	2026-10-24 15:25:29.218045+00
16	auth	0011_update_proxy_permissions	2026-10-24 15:25:29.233311+00
17	auth	0012_alter_user_first_name_max_length	2026-10-24 15:25:29.256236+00
18	ingestion	0001_initial	2026-10-24 15:25:29.268933+00
19	ingestion	0002_rejectedrecord_salerecord	2026-10-24 15:25:29.385469+00
20	sessions	0001_initial	2026-10-24 15:25:29.409439+00
21	ingestion	0003_product_salerecord_product	2026-10-24 15:38:23.698064+00
22	ingestion	0004_ingestionrun_validation_errors	2026-10-26 14:57:17.289722+00
\.


--
-- Data for Name: django_session; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
\.


--
-- Data for Name: ingestion_ingestionrun; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ingestion_ingestionrun (id, original_filename, raw_file, status, rows_read, rows_valid, rows_rejected, error_message, created_at, completed_at, validation_errors) FROM stdin;
9babf604-c5b9-4f2c-9e9d-a53dfccb72d7	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\9babf604-c5b9-4f2c-9e9d-a53dfccb72d7.csv	PENDING	0	0	0		2026-10-24 15:58:12.522705+00	\N	[]
f52f7297-004a-465d-8688-4962b07f33e0	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\f52f7297-004a-465d-8688-4962b07f33e0.csv	PENDING	0	0	0		2026-10-24 16:03:37.269418+00	\N	[]
f5b0b277-d687-4f24-ab4f-857afa270d4a	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\f5b0b277-d687-4f24-ab4f-857afa270d4a.csv	PENDING	0	0	0		2026-10-24 16:05:50.090366+00	\N	[]
92959120-2f75-4819-8268-4acb01395f13	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\92959120-2f75-4819-8268-4acb01395f13.csv	PENDING	0	0	0		2026-10-24 16:07:02.218271+00	\N	[]
6feb3a1f-43b9-4f09-8c8b-73ae98f3d849	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\6feb3a1f-43b9-4f09-8c8b-73ae98f3d849.csv	PENDING	0	0	0		2026-10-24 16:08:06.381923+00	\N	[]
2e7945cd-75c1-4003-8efb-d1a58d9a56c2	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\2e7945cd-75c1-4003-8efb-d1a58d9a56c2.csv	SUCCEEDED	6	5	1		2026-10-24 16:13:35.831755+00	2026-10-24 16:13:35.877678+00	[]
784384cf-104a-4065-a6ee-82fa1b75e153	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\784384cf-104a-4065-a6ee-82fa1b75e153.csv	SUCCEEDED	6	5	1		2026-10-24 16:14:23.721591+00	2026-10-24 16:14:23.747651+00	[]
a328a53d-b146-4d81-9978-5f9215eac05e	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\data\\raw\\a328a53d-b146-4d81-9978-5f9215eac05e.csv	SUCCEEDED	6	5	1		2026-10-24 16:17:52.882667+00	2026-10-24 16:17:52.947734+00	[]
4f645380-e123-4d57-8a36-44433a914f59	sample.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\4f645380-e123-4d57-8a36-44433a914f59.csv	SUCCEEDED	15	15	0		2026-10-26 09:34:47.439464+00	2026-10-26 09:34:47.716793+00	[]
d6011439-d4c4-49e4-8806-719e598b8b66	sample.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\d6011439-d4c4-49e4-8806-719e598b8b66.csv	SUCCEEDED	15	15	0		2026-10-26 09:36:12.998114+00	2026-10-26 09:36:13.160853+00	[]
c0692c4a-cd78-4c12-9f5b-9debfb554431	sample.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\c0692c4a-cd78-4c12-9f5b-9debfb554431.csv	SUCCEEDED	15	15	0		2026-10-26 10:00:06.833529+00	2026-10-26 10:00:07.029908+00	[]
7fc724ae-4362-4880-b293-6a121498c64a	large_sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\7fc724ae-4362-4880-b293-6a121498c64a.csv	SUCCEEDED	20	19	1		2026-10-26 10:05:23.094073+00	2026-10-26 10:05:23.207346+00	[]
8c577820-05d9-498a-ab0f-2e37dc217319	large_sample_sales (2).csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\8c577820-05d9-498a-ab0f-2e37dc217319.csv	SUCCEEDED	16	16	0		2026-10-26 11:32:10.039553+00	2026-10-26 11:32:10.146906+00	[]
dbb49ffa-2145-4d13-a7a3-d72938176cfe	large_sample_sales (1).csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\dbb49ffa-2145-4d13-a7a3-d72938176cfe.csv	SUCCEEDED	100	100	0		2026-10-26 12:46:26.601566+00	2026-10-26 12:46:26.746546+00	[]
19d8dfc3-e5c6-42f9-8ea3-95de9fc75325	large_sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\19d8dfc3-e5c6-42f9-8ea3-95de9fc75325.csv	SUCCEEDED	20	19	1		2026-10-26 13:58:14.802907+00	2026-10-26 13:58:15.235413+00	[]
ad0c57c8-186f-4c68-bf4a-bec46d051cda	large_sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\ad0c57c8-186f-4c68-bf4a-bec46d051cda.csv	SUCCEEDED	20	19	1		2026-10-26 14:15:47.498591+00	2026-10-26 14:15:47.539099+00	[]
3c1acd82-b219-4c6b-be73-86d823f63a2e	large_sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\3c1acd82-b219-4c6b-be73-86d823f63a2e.csv	SUCCEEDED	20	19	1		2026-10-26 14:15:53.87991+00	2026-10-26 14:15:54.001243+00	[]
2e2e0ce5-c0ae-47f4-a943-ad97b57bb9fb	large_sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\2e2e0ce5-c0ae-47f4-a943-ad97b57bb9fb.csv	SUCCEEDED	20	19	1		2026-10-26 14:15:57.423776+00	2026-10-26 14:15:57.475895+00	[]
df9f335e-60cc-42be-ae69-2340bdb71ffb	large_sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\df9f335e-60cc-42be-ae69-2340bdb71ffb.csv	SUCCEEDED	20	19	1		2026-10-26 14:15:58.541167+00	2026-10-26 14:15:58.63561+00	[]
099cd742-19ad-41fb-a4e6-63707c1fc9c2	large_sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\099cd742-19ad-41fb-a4e6-63707c1fc9c2.csv	SUCCEEDED	20	19	1		2026-10-26 14:16:34.073442+00	2026-10-26 14:16:34.128018+00	[]
a7670989-e25a-4d1a-a041-bd50c9b49cd7	large_sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\a7670989-e25a-4d1a-a041-bd50c9b49cd7.csv	SUCCEEDED	20	18	2		2026-10-26 15:10:34.101343+00	2026-10-26 15:10:34.204819+00	[{"row": 2, "reason": "Quantity must be a positive integer"}, {"row": 3, "reason": "Quantity must be a positive integer"}]
f9d226e0-5465-462c-8999-4712a117f6b5	large_sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\f9d226e0-5465-462c-8999-4712a117f6b5.csv	SUCCEEDED	20	17	3		2026-10-26 15:12:17.883212+00	2026-10-26 15:12:18.015863+00	[{"row": 2, "reason": "Quantity must be a positive integer"}, {"row": 3, "reason": "Quantity must be a positive integer"}, {"row": 12, "reason": "Quantity must be a positive integer"}]
8e4d5215-d706-46ad-9d9c-3d56ac4f7319	sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\8e4d5215-d706-46ad-9d9c-3d56ac4f7319.csv	SUCCEEDED	6	5	1		2026-10-27 09:21:05.737684+00	2026-10-27 09:21:05.767727+00	[{"row": 4, "reason": "Duplicate transaction_id and SKU in file"}]
873f9ccd-adc9-49ec-b3d8-148f740af242	large_sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\873f9ccd-adc9-49ec-b3d8-148f740af242.csv	SUCCEEDED	20	16	4		2026-10-26 18:38:13.881165+00	2026-10-26 18:38:13.93465+00	[{"row": 2, "reason": "Quantity must be a positive integer"}, {"row": 3, "reason": "Quantity must be a positive integer"}, {"row": 12, "reason": "Quantity must be a positive integer"}, {"row": 14, "reason": "Quantity must be a positive integer"}]
b5c36828-bbbe-4a45-8d2e-487074070769	large_sample_sales.csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\b5c36828-bbbe-4a45-8d2e-487074070769.csv	SUCCEEDED	20	15	5		2026-10-27 09:12:26.9491+00	2026-10-27 09:12:27.181985+00	[{"row": 2, "reason": "Quantity must be a positive integer"}, {"row": 3, "reason": "Quantity must be a positive integer"}, {"row": 12, "reason": "Quantity must be a positive integer"}, {"row": 13, "reason": "Quantity must be a positive integer"}, {"row": 14, "reason": "Quantity must be a positive integer"}]
a40c457e-cee1-4f09-94bc-f81c8477e3b5	large_sample_sales (3).csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\a40c457e-cee1-4f09-94bc-f81c8477e3b5.csv	SUCCEEDED	12	12	0		2026-10-26 20:29:40.837749+00	2026-10-26 20:29:40.946963+00	[]
cb8f2982-fa57-4967-88f6-0c29714700ce	large_sample_sales (3).csv	C:\\Users\\brian\\Downloads\\stock-pulse\\backend\\data\\raw\\cb8f2982-fa57-4967-88f6-0c29714700ce.csv	SUCCEEDED	12	11	1		2026-10-26 20:31:46.232357+00	2026-10-26 20:31:46.390072+00	[{"row": 10, "reason": "Quantity must be a positive integer"}]
\.


--
-- Data for Name: ingestion_product; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ingestion_product (id, sku, name, category, active, created_at, updated_at) FROM stdin;
26	SKU-003	SKU-003	Uncategorised	t	2026-10-24 16:13:35.873154+00	2026-10-24 16:13:35.873154+00
27	SKU-002	SKU-002	Uncategorised	t	2026-10-24 16:13:35.873154+00	2026-10-24 16:13:35.873154+00
28	SKU-004	SKU-004	Uncategorised	t	2026-10-24 16:13:35.873154+00	2026-10-24 16:13:35.873154+00
29	SKU-001	SKU-001	Uncategorised	t	2026-10-24 16:13:35.873154+00	2026-10-24 16:13:35.873154+00
30	SKU-005	SKU-005	Uncategorised	t	2026-10-24 16:13:35.873154+00	2026-10-24 16:13:35.873154+00
31	SKU-108	SKU-108	Uncategorised	t	2026-10-26 09:34:47.661688+00	2026-10-26 09:34:47.66172+00
32	SKU-103	SKU-103	Uncategorised	t	2026-10-26 09:34:47.661759+00	2026-10-26 09:34:47.661773+00
33	SKU-101	SKU-101	Uncategorised	t	2026-10-26 09:34:47.661807+00	2026-10-26 09:34:47.66182+00
34	SKU-105	SKU-105	Uncategorised	t	2026-10-26 09:34:47.661854+00	2026-10-26 09:34:47.661868+00
35	SKU-109	SKU-109	Uncategorised	t	2026-10-26 09:34:47.661907+00	2026-10-26 09:34:47.661921+00
36	SKU-110	SKU-110	Uncategorised	t	2026-10-26 09:34:47.661954+00	2026-10-26 09:34:47.661968+00
37	SKU-106	SKU-106	Uncategorised	t	2026-10-26 09:34:47.662+00	2026-10-26 09:34:47.662013+00
38	SKU-104	SKU-104	Uncategorised	t	2026-10-26 09:34:47.662047+00	2026-10-26 09:34:47.66206+00
39	SKU-107	SKU-107	Uncategorised	t	2026-10-26 09:34:47.662093+00	2026-10-26 09:34:47.662106+00
40	SKU-102	SKU-102	Uncategorised	t	2026-10-26 09:34:47.66214+00	2026-10-26 09:34:47.662154+00
41	SKU-113	SKU-113	Uncategorised	t	2026-10-26 10:05:23.183673+00	2026-10-26 10:05:23.183689+00
42	SKU-139	SKU-139	Uncategorised	t	2026-10-26 10:05:23.183706+00	2026-10-26 10:05:23.183711+00
43	SKU-112	SKU-112	Uncategorised	t	2026-10-26 10:05:23.183724+00	2026-10-26 10:05:23.18373+00
44	SKU-120	SKU-120	Uncategorised	t	2026-10-26 10:05:23.183742+00	2026-10-26 10:05:23.183748+00
45	SKU-138	SKU-138	Uncategorised	t	2026-10-26 10:05:23.18376+00	2026-10-26 10:05:23.183765+00
46	SKU-118	SKU-118	Uncategorised	t	2026-10-26 10:05:23.183777+00	2026-10-26 10:05:23.183783+00
47	SKU-122	SKU-122	Uncategorised	t	2026-10-26 10:05:23.183794+00	2026-10-26 10:05:23.183799+00
48	SKU-121	SKU-121	Uncategorised	t	2026-10-26 10:05:23.183811+00	2026-10-26 10:05:23.183816+00
49	SKU-140	SKU-140	Uncategorised	t	2026-10-26 10:05:23.183828+00	2026-10-26 10:05:23.183833+00
50	SKU-117	SKU-117	Uncategorised	t	2026-10-26 10:05:23.183845+00	2026-10-26 10:05:23.18385+00
51	SKU-125	SKU-125	Uncategorised	t	2026-10-26 10:05:23.183862+00	2026-10-26 10:05:23.183867+00
52	SKU-129	SKU-129	Uncategorised	t	2026-10-26 10:05:23.183879+00	2026-10-26 10:05:23.183883+00
53	SKU-141	SKU-141	Uncategorised	t	2026-10-26 11:32:10.118841+00	2026-10-26 11:32:10.118865+00
54	SKU-145	SKU-145	Uncategorised	t	2026-10-26 11:32:10.118893+00	2026-10-26 11:32:10.118903+00
55	SKU-131	SKU-131	Uncategorised	t	2026-10-26 11:32:10.118926+00	2026-10-26 11:32:10.118935+00
56	SKU-130	SKU-130	Uncategorised	t	2026-10-26 11:32:10.118956+00	2026-10-26 11:32:10.118965+00
57	SKU-128	SKU-128	Uncategorised	t	2026-10-26 11:32:10.118986+00	2026-10-26 11:32:10.118995+00
58	SKU-137	SKU-137	Uncategorised	t	2026-10-26 11:32:10.119057+00	2026-10-26 11:32:10.119078+00
59	SKU-148	SKU-148	Uncategorised	t	2026-10-26 11:32:10.119099+00	2026-10-26 11:32:10.119108+00
60	SKU-150	SKU-150	Uncategorised	t	2026-10-26 11:32:10.119129+00	2026-10-26 11:32:10.119139+00
61	SKU-111	SKU-111	Uncategorised	t	2026-10-26 12:46:26.716403+00	2026-10-26 12:46:26.716418+00
62	SKU-124	SKU-124	Uncategorised	t	2026-10-26 12:46:26.716433+00	2026-10-26 12:46:26.716439+00
63	SKU-146	SKU-146	Uncategorised	t	2026-10-26 12:46:26.716451+00	2026-10-26 12:46:26.716457+00
64	SKU-147	SKU-147	Uncategorised	t	2026-10-26 12:46:26.716469+00	2026-10-26 12:46:26.716473+00
65	SKU-116	SKU-116	Uncategorised	t	2026-10-26 12:46:26.716485+00	2026-10-26 12:46:26.716489+00
66	SKU-142	SKU-142	Uncategorised	t	2026-10-26 12:46:26.716501+00	2026-10-26 12:46:26.716505+00
67	SKU-149	SKU-149	Uncategorised	t	2026-10-26 12:46:26.716517+00	2026-10-26 12:46:26.716521+00
68	SKU-143	SKU-143	Uncategorised	t	2026-10-26 12:46:26.716533+00	2026-10-26 12:46:26.716538+00
69	SKU-115	SKU-115	Uncategorised	t	2026-10-26 12:46:26.716549+00	2026-10-26 12:46:26.716553+00
70	SKU-127	SKU-127	Uncategorised	t	2026-10-26 12:46:26.716565+00	2026-10-26 12:46:26.716569+00
71	SKU-123	SKU-123	Uncategorised	t	2026-10-26 12:46:26.71658+00	2026-10-26 12:46:26.716585+00
72	SKU-119	SKU-119	Uncategorised	t	2026-10-26 12:46:26.716596+00	2026-10-26 12:46:26.716633+00
73	SKU-100	SKU-100	Uncategorised	t	2026-10-26 12:46:26.716643+00	2026-10-26 12:46:26.716647+00
74	SKU-133	SKU-133	Uncategorised	t	2026-10-26 12:46:26.716656+00	2026-10-26 12:46:26.716659+00
75	SKU-114	SKU-114	Uncategorised	t	2026-10-26 12:46:26.716668+00	2026-10-26 12:46:26.716671+00
76	SKU-144	SKU-144	Uncategorised	t	2026-10-26 12:46:26.716687+00	2026-10-26 12:46:26.716691+00
77	SKU-126	SKU-126	Uncategorised	t	2026-10-26 12:46:26.7167+00	2026-10-26 12:46:26.716703+00
78	SKU-134	SKU-134	Uncategorised	t	2026-10-26 20:29:40.920824+00	2026-10-26 20:29:40.920855+00
\.


--
-- Data for Name: ingestion_rejectedrecord; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ingestion_rejectedrecord (id, source_row_number, raw_data, reason, created_at, ingestion_run_id) FROM stdin;
6	4	{"sku": "SKU-001", "sold_at": "2026-10-20 10:30:00", "quantity": "3", "unit_cost": "15.0", "unit_price": "25.0", "transaction_id": "TXN-1001"}	Duplicate transaction_id and SKU in file	2026-10-24 16:13:35.850893+00	2e7945cd-75c1-4003-8efb-d1a58d9a56c2
7	4	{"sku": "SKU-001", "sold_at": "2026-10-20 10:30:00", "quantity": "3", "unit_cost": "15.0", "unit_price": "25.0", "transaction_id": "TXN-1001"}	Duplicate transaction_id and SKU in file	2026-10-24 16:14:23.736591+00	784384cf-104a-4065-a6ee-82fa1b75e153
8	4	{"sku": "SKU-001", "sold_at": "2026-10-20 10:30:00", "quantity": "3", "unit_cost": "15.0", "unit_price": "100.0", "transaction_id": "TXN-1001"}	Duplicate transaction_id and SKU in file	2026-10-24 16:17:52.922476+00	a328a53d-b146-4d81-9978-5f9215eac05e
9	3	{"sku": "SKU-120", "sold_at": "2026-10-29 08:09:00", "quantity": "-7", "unit_cost": "16.35", "unit_price": "35.34", "transaction_id": "TXN-3002"}	Quantity must be a positive integer	2026-10-26 10:05:23.143934+00	7fc724ae-4362-4880-b293-6a121498c64a
10	3	{"sku": "SKU-120", "sold_at": "2026-10-29 08:09:00", "quantity": "-7", "unit_cost": "16.35", "unit_price": "35.34", "transaction_id": "TXN-3002"}	Quantity must be a positive integer	2026-10-26 13:58:14.988473+00	19d8dfc3-e5c6-42f9-8ea3-95de9fc75325
11	3	{"sku": "SKU-120", "sold_at": "2026-10-29 08:09:00", "quantity": "-7", "unit_cost": "16.35", "unit_price": "35.34", "transaction_id": "TXN-3002"}	Quantity must be a positive integer	2026-10-26 14:15:47.525945+00	ad0c57c8-186f-4c68-bf4a-bec46d051cda
12	3	{"sku": "SKU-120", "sold_at": "2026-10-29 08:09:00", "quantity": "-7", "unit_cost": "16.35", "unit_price": "35.34", "transaction_id": "TXN-3002"}	Quantity must be a positive integer	2026-10-26 14:15:53.960601+00	3c1acd82-b219-4c6b-be73-86d823f63a2e
13	3	{"sku": "SKU-120", "sold_at": "2026-10-29 08:09:00", "quantity": "-7", "unit_cost": "16.35", "unit_price": "35.34", "transaction_id": "TXN-3002"}	Quantity must be a positive integer	2026-10-26 14:15:57.463523+00	2e2e0ce5-c0ae-47f4-a943-ad97b57bb9fb
14	3	{"sku": "SKU-120", "sold_at": "2026-10-29 08:09:00", "quantity": "-7", "unit_cost": "16.35", "unit_price": "35.34", "transaction_id": "TXN-3002"}	Quantity must be a positive integer	2026-10-26 14:15:58.593244+00	df9f335e-60cc-42be-ae69-2340bdb71ffb
15	3	{"sku": "SKU-120", "sold_at": "2026-10-29 08:09:00", "quantity": "-7", "unit_cost": "16.35", "unit_price": "35.34", "transaction_id": "TXN-3002"}	Quantity must be a positive integer	2026-10-26 14:16:34.112319+00	099cd742-19ad-41fb-a4e6-63707c1fc9c2
16	2	{"sku": "SKU-118", "sold_at": "28/10/2026 14:30", "quantity": "-79", "unit_cost": "25.94", "unit_price": "59.15", "transaction_id": "TXN-3001"}	Quantity must be a positive integer	2026-10-26 15:10:34.173546+00	a7670989-e25a-4d1a-a041-bd50c9b49cd7
17	3	{"sku": "SKU-120", "sold_at": "29/10/2026 08:09", "quantity": "-7", "unit_cost": "16.35", "unit_price": "35.34", "transaction_id": "TXN-3002"}	Quantity must be a positive integer	2026-10-26 15:10:34.173585+00	a7670989-e25a-4d1a-a041-bd50c9b49cd7
18	2	{"sku": "SKU-118", "sold_at": "28/10/2026 14:30", "quantity": "-79", "unit_cost": "25.94", "unit_price": "59.15", "transaction_id": "TXN-3001"}	Quantity must be a positive integer	2026-10-26 15:12:17.983934+00	f9d226e0-5465-462c-8999-4712a117f6b5
19	3	{"sku": "SKU-120", "sold_at": "29/10/2026 08:09", "quantity": "-7", "unit_cost": "16.35", "unit_price": "35.34", "transaction_id": "TXN-3002"}	Quantity must be a positive integer	2026-10-26 15:12:17.984016+00	f9d226e0-5465-462c-8999-4712a117f6b5
20	12	{"sku": "SKU-138", "sold_at": "30/10/2026 15:10", "quantity": "-78", "unit_cost": "104.27", "unit_price": "152.83", "transaction_id": "TXN-3011"}	Quantity must be a positive integer	2026-10-26 15:12:17.984078+00	f9d226e0-5465-462c-8999-4712a117f6b5
21	2	{"sku": "SKU-118", "sold_at": "28/10/2026 14:30", "quantity": "-79", "unit_cost": "25.94", "unit_price": "59.15", "transaction_id": "TXN-3001"}	Quantity must be a positive integer	2026-10-26 18:38:13.916517+00	873f9ccd-adc9-49ec-b3d8-148f740af242
22	3	{"sku": "SKU-120", "sold_at": "29/10/2026 08:09", "quantity": "-7", "unit_cost": "16.35", "unit_price": "35.34", "transaction_id": "TXN-3002"}	Quantity must be a positive integer	2026-10-26 18:38:13.916547+00	873f9ccd-adc9-49ec-b3d8-148f740af242
23	12	{"sku": "SKU-138", "sold_at": "30/10/2026 15:10", "quantity": "-78", "unit_cost": "104.27", "unit_price": "152.83", "transaction_id": "TXN-3011"}	Quantity must be a positive integer	2026-10-26 18:38:13.916567+00	873f9ccd-adc9-49ec-b3d8-148f740af242
24	14	{"sku": "SKU-118", "sold_at": "27/10/2026 16:54", "quantity": "-2", "unit_cost": "104.53", "unit_price": "223.47", "transaction_id": "TXN-3013"}	Quantity must be a positive integer	2026-10-26 18:38:13.916587+00	873f9ccd-adc9-49ec-b3d8-148f740af242
25	10	{"sku": "5", "sold_at": "29/10/2026 08:51", "quantity": "-4", "unit_cost": "108.4", "unit_price": "246.59", "transaction_id": "TXN-3009"}	Quantity must be a positive integer	2026-10-26 20:31:46.277793+00	cb8f2982-fa57-4967-88f6-0c29714700ce
26	2	{"sku": "SKU-118", "sold_at": "28/10/2026 14:30", "quantity": "-79", "unit_cost": "25.94", "unit_price": "59.15", "transaction_id": "TXN-30090"}	Quantity must be a positive integer	2026-10-27 09:12:27.122504+00	b5c36828-bbbe-4a45-8d2e-487074070769
27	3	{"sku": "SKU-120", "sold_at": "29/10/2026 08:09", "quantity": "-7", "unit_cost": "16.35", "unit_price": "35.34", "transaction_id": "TXN-3002"}	Quantity must be a positive integer	2026-10-27 09:12:27.122577+00	b5c36828-bbbe-4a45-8d2e-487074070769
28	12	{"sku": "SKU-138", "sold_at": "30/10/2026 15:10", "quantity": "-78", "unit_cost": "104.27", "unit_price": "152.83", "transaction_id": "TXN-3011"}	Quantity must be a positive integer	2026-10-27 09:12:27.122635+00	b5c36828-bbbe-4a45-8d2e-487074070769
29	13	{"sku": "SKU-102", "sold_at": "29/10/2026 16:08", "quantity": "-5", "unit_cost": "89.63", "unit_price": "167.43", "transaction_id": "TXN-3012"}	Quantity must be a positive integer	2026-10-27 09:12:27.122689+00	b5c36828-bbbe-4a45-8d2e-487074070769
30	14	{"sku": "SKU-118", "sold_at": "27/10/2026 16:54", "quantity": "-2", "unit_cost": "104.53", "unit_price": "223.47", "transaction_id": "TXN-3013"}	Quantity must be a positive integer	2026-10-27 09:12:27.122742+00	b5c36828-bbbe-4a45-8d2e-487074070769
31	4	{"sku": "SKU-001", "sold_at": "2026-10-20 10:30:00", "quantity": "3", "unit_cost": "15.0", "unit_price": "100.0", "transaction_id": "TXN-1001"}	Duplicate transaction_id and SKU in file	2026-10-27 09:21:05.753688+00	8e4d5215-d706-46ad-9d9c-3d56ac4f7319
\.


--
-- Data for Name: ingestion_salerecord; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ingestion_salerecord (id, transaction_id, sold_at, sku, quantity, unit_price, unit_cost, created_at, source_run_id, product_id) FROM stdin;
1	TXN-1001	2026-10-20 10:30:00+00	SKU-001	3	25.00	15.00	2026-10-24 16:13:35.877678+00	2e7945cd-75c1-4003-8efb-d1a58d9a56c2	29
2	TXN-1002	2026-10-20 11:15:00+00	SKU-002	2	40.00	22.00	2026-10-24 16:13:35.877678+00	2e7945cd-75c1-4003-8efb-d1a58d9a56c2	27
3	TXN-1004	2026-10-20 13:30:00+00	SKU-003	4	12.50	7.00	2026-10-24 16:13:35.877678+00	2e7945cd-75c1-4003-8efb-d1a58d9a56c2	26
4	TXN-1005	2026-10-20 14:10:00+00	SKU-004	2	60.00	35.00	2026-10-24 16:13:35.877678+00	2e7945cd-75c1-4003-8efb-d1a58d9a56c2	28
5	TXN-1006	2026-10-20 14:10:00+00	SKU-005	2	68.00	25.00	2026-10-24 16:13:35.877678+00	2e7945cd-75c1-4003-8efb-d1a58d9a56c2	30
6	TXN-2001	2026-10-25 09:15:22+00	SKU-101	5	45.99	28.50	2026-10-26 09:34:47.702105+00	4f645380-e123-4d57-8a36-44433a914f59	33
7	TXN-2002	2026-10-25 10:30:45+00	SKU-102	1	120.00	75.00	2026-10-26 09:34:47.702205+00	4f645380-e123-4d57-8a36-44433a914f59	40
8	TXN-2003	2026-10-25 11:45:10+00	SKU-103	10	15.50	9.25	2026-10-26 09:34:47.702291+00	4f645380-e123-4d57-8a36-44433a914f59	32
9	TXN-2004	2026-10-25 13:20:33+00	SKU-101	2	45.99	28.50	2026-10-26 09:34:47.702376+00	4f645380-e123-4d57-8a36-44433a914f59	33
10	TXN-2005	2026-10-25 14:05:18+00	SKU-104	7	8.99	4.50	2026-10-26 09:34:47.702463+00	4f645380-e123-4d57-8a36-44433a914f59	38
11	TXN-2006	2026-10-26 08:00:05+00	SKU-105	3	200.00	150.00	2026-10-26 09:34:47.702556+00	4f645380-e123-4d57-8a36-44433a914f59	34
12	TXN-2007	2026-10-26 09:30:50+00	SKU-102	4	120.00	75.00	2026-10-26 09:34:47.70265+00	4f645380-e123-4d57-8a36-44433a914f59	40
13	TXN-2008	2026-10-26 11:15:27+00	SKU-106	1	55.00	30.00	2026-10-26 09:34:47.702745+00	4f645380-e123-4d57-8a36-44433a914f59	37
14	TXN-2009	2026-10-26 12:45:41+00	SKU-103	15	15.50	9.25	2026-10-26 09:34:47.702831+00	4f645380-e123-4d57-8a36-44433a914f59	32
15	TXN-2010	2026-10-26 15:30:12+00	SKU-107	6	32.75	18.00	2026-10-26 09:34:47.702944+00	4f645380-e123-4d57-8a36-44433a914f59	39
16	TXN-2011	2026-10-26 16:10:00+00	SKU-108	2	89.99	50.00	2026-10-26 09:34:47.703057+00	4f645380-e123-4d57-8a36-44433a914f59	31
17	TXN-2012	2026-10-27 09:05:33+00	SKU-104	12	8.99	4.50	2026-10-26 09:34:47.70316+00	4f645380-e123-4d57-8a36-44433a914f59	38
18	TXN-2013	2026-10-27 10:22:15+00	SKU-109	1	350.00	210.00	2026-10-26 09:34:47.70325+00	4f645380-e123-4d57-8a36-44433a914f59	35
19	TXN-2014	2026-10-27 11:40:50+00	SKU-105	5	200.00	150.00	2026-10-26 09:34:47.703353+00	4f645380-e123-4d57-8a36-44433a914f59	34
20	TXN-2015	2026-10-27 14:15:08+00	SKU-110	8	22.50	12.75	2026-10-26 09:34:47.703453+00	4f645380-e123-4d57-8a36-44433a914f59	36
21	TXN-3001	2026-10-28 14:30:00+00	SKU-118	17	59.15	25.94	2026-10-26 10:05:23.197407+00	7fc724ae-4362-4880-b293-6a121498c64a	46
22	TXN-3003	2026-10-26 09:59:00+00	SKU-112	14	62.61	38.26	2026-10-26 10:05:23.197538+00	7fc724ae-4362-4880-b293-6a121498c64a	43
23	TXN-3004	2026-10-30 09:32:00+00	SKU-112	16	246.85	113.54	2026-10-26 10:05:23.197627+00	7fc724ae-4362-4880-b293-6a121498c64a	43
24	TXN-3005	2026-10-25 17:48:00+00	SKU-120	12	219.75	142.80	2026-10-26 10:05:23.197715+00	7fc724ae-4362-4880-b293-6a121498c64a	44
25	TXN-3006	2026-10-27 12:49:00+00	SKU-110	1	86.95	35.26	2026-10-26 10:05:23.197815+00	7fc724ae-4362-4880-b293-6a121498c64a	36
26	TXN-3007	2026-10-30 11:06:00+00	SKU-139	10	82.46	48.39	2026-10-26 10:05:23.197906+00	7fc724ae-4362-4880-b293-6a121498c64a	42
27	TXN-3008	2026-10-30 12:52:00+00	SKU-138	16	49.25	25.31	2026-10-26 10:05:23.19799+00	7fc724ae-4362-4880-b293-6a121498c64a	45
28	TXN-3009	2026-10-29 08:59:00+00	SKU-129	15	157.34	101.54	2026-10-26 10:05:23.198109+00	7fc724ae-4362-4880-b293-6a121498c64a	52
29	TXN-3010	2026-10-27 17:03:00+00	SKU-138	5	177.30	120.92	2026-10-26 10:05:23.198194+00	7fc724ae-4362-4880-b293-6a121498c64a	45
30	TXN-3011	2026-10-30 15:10:00+00	SKU-138	1	152.83	104.27	2026-10-26 10:05:23.198279+00	7fc724ae-4362-4880-b293-6a121498c64a	45
31	TXN-3012	2026-10-29 16:08:00+00	SKU-102	15	167.43	89.63	2026-10-26 10:05:23.198363+00	7fc724ae-4362-4880-b293-6a121498c64a	40
32	TXN-3013	2026-10-27 16:54:00+00	SKU-118	7	223.47	104.53	2026-10-26 10:05:23.198452+00	7fc724ae-4362-4880-b293-6a121498c64a	46
33	TXN-3014	2026-10-30 11:57:00+00	SKU-117	2	60.15	38.67	2026-10-26 10:05:23.198536+00	7fc724ae-4362-4880-b293-6a121498c64a	50
34	TXN-3015	2026-10-27 13:52:00+00	SKU-121	12	75.49	38.43	2026-10-26 10:05:23.198654+00	7fc724ae-4362-4880-b293-6a121498c64a	48
35	TXN-3016	2026-10-30 08:29:00+00	SKU-122	9	157.89	75.34	2026-10-26 10:05:23.198741+00	7fc724ae-4362-4880-b293-6a121498c64a	47
36	TXN-3017	2026-10-27 11:17:00+00	SKU-140	20	163.76	104.66	2026-10-26 10:05:23.198822+00	7fc724ae-4362-4880-b293-6a121498c64a	49
37	TXN-3018	2026-10-28 14:45:00+00	SKU-125	20	30.99	17.58	2026-10-26 10:05:23.198906+00	7fc724ae-4362-4880-b293-6a121498c64a	51
38	TXN-3019	2026-10-29 16:26:00+00	SKU-113	3	56.38	28.15	2026-10-26 10:05:23.198989+00	7fc724ae-4362-4880-b293-6a121498c64a	41
39	TXN-3020	2026-10-27 11:37:00+00	SKU-107	4	38.70	24.63	2026-10-26 10:05:23.199071+00	7fc724ae-4362-4880-b293-6a121498c64a	39
40	TXN-3001	2026-09-28 09:57:00+00	SKU-150	5	24.18	11.81	2026-10-26 11:32:10.13722+00	8c577820-05d9-498a-ab0f-2e37dc217319	60
41	TXN-3002	2026-09-25 16:47:00+00	SKU-131	12	57.18	37.52	2026-10-26 11:32:10.137286+00	8c577820-05d9-498a-ab0f-2e37dc217319	55
42	TXN-3003	2026-09-28 15:47:00+00	SKU-121	9	57.22	27.68	2026-10-26 11:32:10.137341+00	8c577820-05d9-498a-ab0f-2e37dc217319	48
43	TXN-3004	2026-09-27 15:43:00+00	SKU-141	16	25.55	11.65	2026-10-26 11:32:10.137395+00	8c577820-05d9-498a-ab0f-2e37dc217319	53
44	TXN-3005	2026-09-25 10:19:00+00	SKU-139	14	123.50	55.83	2026-10-26 11:32:10.13747+00	8c577820-05d9-498a-ab0f-2e37dc217319	42
45	TXN-3006	2026-09-26 14:00:00+00	SKU-121	11	121.48	83.45	2026-10-26 11:32:10.137553+00	8c577820-05d9-498a-ab0f-2e37dc217319	48
46	TXN-3007	2026-09-30 09:51:00+00	SKU-130	9	156.57	74.68	2026-10-26 11:32:10.137794+00	8c577820-05d9-498a-ab0f-2e37dc217319	56
47	TXN-3008	2026-09-30 17:52:00+00	SKU-128	4	108.31	52.55	2026-10-26 11:32:10.137831+00	8c577820-05d9-498a-ab0f-2e37dc217319	57
48	TXN-3009	2026-09-29 13:34:00+00	SKU-121	19	123.36	72.16	2026-10-26 11:32:10.137862+00	8c577820-05d9-498a-ab0f-2e37dc217319	48
49	TXN-3010	2026-09-27 16:33:00+00	SKU-112	8	146.24	71.55	2026-10-26 11:32:10.137893+00	8c577820-05d9-498a-ab0f-2e37dc217319	43
50	TXN-3011	2026-09-30 16:51:00+00	SKU-145	10	81.85	46.88	2026-10-26 11:32:10.137924+00	8c577820-05d9-498a-ab0f-2e37dc217319	54
51	TXN-3012	2026-09-28 09:12:00+00	SKU-108	20	65.37	44.58	2026-10-26 11:32:10.137954+00	8c577820-05d9-498a-ab0f-2e37dc217319	31
52	TXN-3013	2026-09-28 13:03:00+00	SKU-138	20	152.93	77.97	2026-10-26 11:32:10.137986+00	8c577820-05d9-498a-ab0f-2e37dc217319	45
53	TXN-3014	2026-09-25 16:27:00+00	SKU-108	15	147.37	93.39	2026-10-26 11:32:10.138086+00	8c577820-05d9-498a-ab0f-2e37dc217319	31
54	TXN-3015	2026-09-26 13:00:00+00	SKU-137	17	153.07	93.58	2026-10-26 11:32:10.138137+00	8c577820-05d9-498a-ab0f-2e37dc217319	58
55	TXN-3016	2026-09-28 12:58:00+00	SKU-148	14	113.54	55.20	2026-10-26 11:32:10.138188+00	8c577820-05d9-498a-ab0f-2e37dc217319	59
56	TXN-3001	2026-10-29 18:57:00+00	SKU-124	9	96.37	59.08	2026-10-26 12:46:26.73094+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	62
57	TXN-3002	2026-10-30 17:16:00+00	SKU-116	5	126.57	69.74	2026-10-26 12:46:26.73098+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	65
58	TXN-3004	2026-10-28 09:53:00+00	SKU-149	15	214.22	86.15	2026-10-26 12:46:26.731008+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	67
59	TXN-3005	2026-10-29 16:55:00+00	SKU-121	19	102.56	62.42	2026-10-26 12:46:26.731034+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	48
60	TXN-3006	2026-10-26 08:29:00+00	SKU-122	5	18.44	12.76	2026-10-26 12:46:26.731058+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	47
61	TXN-3008	2026-10-30 16:55:00+00	SKU-131	5	147.07	98.75	2026-10-26 12:46:26.731084+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	55
62	TXN-3009	2026-10-28 14:20:00+00	SKU-149	1	120.67	54.77	2026-10-26 12:46:26.731109+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	67
63	TXN-3010	2026-10-26 17:10:00+00	SKU-123	16	12.75	5.41	2026-10-26 12:46:26.731134+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	71
64	TXN-3011	2026-10-29 09:24:00+00	SKU-144	16	98.47	42.44	2026-10-26 12:46:26.731159+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	76
65	TXN-3012	2026-10-28 12:30:00+00	SKU-130	19	58.97	30.21	2026-10-26 12:46:26.731183+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	56
66	TXN-3013	2026-10-30 18:23:00+00	SKU-139	3	20.50	9.62	2026-10-26 12:46:26.731208+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	42
67	TXN-3014	2026-10-25 12:07:00+00	SKU-145	5	118.71	72.67	2026-10-26 12:46:26.731232+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	54
68	TXN-3015	2026-10-28 14:52:00+00	SKU-107	7	67.78	39.94	2026-10-26 12:46:26.731256+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	39
69	TXN-3016	2026-10-28 08:57:00+00	SKU-141	19	98.57	62.78	2026-10-26 12:46:26.731281+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	53
70	TXN-3017	2026-10-25 16:02:00+00	SKU-110	10	218.12	103.84	2026-10-26 12:46:26.731308+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	36
71	TXN-3019	2026-10-26 12:10:00+00	SKU-117	9	59.05	24.55	2026-10-26 12:46:26.731332+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	50
72	TXN-3020	2026-10-28 11:40:00+00	SKU-106	3	138.20	74.22	2026-10-26 12:46:26.731357+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	37
73	TXN-3021	2026-10-26 13:02:00+00	SKU-112	7	118.38	51.33	2026-10-26 12:46:26.731382+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	43
74	TXN-3022	2026-10-28 16:37:00+00	SKU-121	3	192.99	128.99	2026-10-26 12:46:26.731407+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	48
75	TXN-3023	2026-10-28 17:39:00+00	SKU-104	16	112.80	78.92	2026-10-26 12:46:26.731431+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	38
76	TXN-3024	2026-10-30 17:41:00+00	SKU-146	18	15.56	8.42	2026-10-26 12:46:26.731455+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	63
77	TXN-3025	2026-10-29 08:34:00+00	SKU-143	9	214.92	119.96	2026-10-26 12:46:26.731478+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	68
78	TXN-3026	2026-10-30 10:14:00+00	SKU-111	5	92.38	40.74	2026-10-26 12:46:26.731503+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	61
79	TXN-3027	2026-10-28 14:04:00+00	SKU-115	4	100.82	47.58	2026-10-26 12:46:26.731527+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	69
80	TXN-3028	2026-10-30 18:24:00+00	SKU-116	20	100.74	61.02	2026-10-26 12:46:26.731551+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	65
81	TXN-3029	2026-10-28 11:50:00+00	SKU-124	19	240.22	157.30	2026-10-26 12:46:26.731575+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	62
82	TXN-3030	2026-10-27 10:04:00+00	SKU-133	18	168.72	75.31	2026-10-26 12:46:26.7316+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	74
83	TXN-3031	2026-10-25 12:39:00+00	SKU-122	10	202.99	99.54	2026-10-26 12:46:26.731625+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	47
84	TXN-3032	2026-10-27 08:59:00+00	SKU-125	8	159.18	89.86	2026-10-26 12:46:26.73165+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	51
85	TXN-3033	2026-10-27 12:47:00+00	SKU-148	10	162.29	78.97	2026-10-26 12:46:26.731674+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	59
86	TXN-3034	2026-10-26 16:42:00+00	SKU-111	5	77.72	45.41	2026-10-26 12:46:26.731698+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	61
87	TXN-3035	2026-10-27 12:38:00+00	SKU-101	11	56.48	26.20	2026-10-26 12:46:26.731721+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	33
88	TXN-3036	2026-10-30 10:34:00+00	SKU-101	11	126.10	71.10	2026-10-26 12:46:26.731745+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	33
89	TXN-3037	2026-10-25 09:25:00+00	SKU-147	11	136.58	64.56	2026-10-26 12:46:26.731768+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	64
90	TXN-3038	2026-10-25 09:30:00+00	SKU-111	13	217.63	134.95	2026-10-26 12:46:26.731793+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	61
91	TXN-3039	2026-10-30 11:01:00+00	SKU-103	16	87.44	45.66	2026-10-26 12:46:26.731817+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	32
92	TXN-3040	2026-10-30 11:36:00+00	SKU-145	2	125.12	67.96	2026-10-26 12:46:26.731841+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	54
93	TXN-3041	2026-10-27 08:15:00+00	SKU-104	19	201.24	112.03	2026-10-26 12:46:26.731865+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	38
94	TXN-3042	2026-10-25 09:34:00+00	SKU-140	12	194.10	79.04	2026-10-26 12:46:26.731889+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	49
95	TXN-3043	2026-10-29 11:14:00+00	SKU-150	1	28.07	15.81	2026-10-26 12:46:26.731913+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	60
96	TXN-3044	2026-10-25 09:06:00+00	SKU-133	3	211.16	123.97	2026-10-26 12:46:26.731937+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	74
97	TXN-3045	2026-10-30 16:28:00+00	SKU-107	6	146.45	99.33	2026-10-26 12:46:26.731961+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	39
98	TXN-3046	2026-10-25 11:15:00+00	SKU-125	17	221.18	121.39	2026-10-26 12:46:26.731985+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	51
99	TXN-3047	2026-10-25 15:52:00+00	SKU-117	4	56.85	38.13	2026-10-26 12:46:26.732009+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	50
100	TXN-3048	2026-10-29 18:42:00+00	SKU-145	1	18.90	8.24	2026-10-26 12:46:26.732032+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	54
101	TXN-3049	2026-10-26 17:40:00+00	SKU-119	4	134.38	76.49	2026-10-26 12:46:26.732056+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	72
102	TXN-3050	2026-10-30 12:28:00+00	SKU-133	2	33.97	16.75	2026-10-26 12:46:26.73208+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	74
103	TXN-3051	2026-10-30 18:54:00+00	SKU-140	9	129.13	66.60	2026-10-26 12:46:26.732104+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	49
104	TXN-3052	2026-10-30 18:36:00+00	SKU-121	5	72.19	33.79	2026-10-26 12:46:26.732129+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	48
105	TXN-3053	2026-10-27 09:51:00+00	SKU-120	5	83.59	45.10	2026-10-26 12:46:26.732154+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	44
106	TXN-3054	2026-10-29 18:40:00+00	SKU-140	11	162.38	78.73	2026-10-26 12:46:26.732178+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	49
107	TXN-3055	2026-10-28 12:13:00+00	SKU-146	20	189.00	92.78	2026-10-26 12:46:26.732202+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	63
108	TXN-3056	2026-10-30 11:24:00+00	SKU-128	13	193.93	82.18	2026-10-26 12:46:26.732227+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	57
109	TXN-3057	2026-10-29 14:45:00+00	SKU-103	6	80.54	54.14	2026-10-26 12:46:26.732251+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	32
110	TXN-3058	2026-10-28 09:13:00+00	SKU-102	18	39.92	19.44	2026-10-26 12:46:26.732275+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	40
111	TXN-3059	2026-10-29 18:38:00+00	SKU-110	19	118.79	56.96	2026-10-26 12:46:26.732299+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	36
112	TXN-3060	2026-10-30 13:21:00+00	SKU-144	12	53.37	35.81	2026-10-26 12:46:26.732322+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	76
113	TXN-3061	2026-10-27 14:28:00+00	SKU-110	1	131.89	56.09	2026-10-26 12:46:26.732346+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	36
114	TXN-3062	2026-10-25 10:03:00+00	SKU-133	19	17.75	9.75	2026-10-26 12:46:26.73237+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	74
115	TXN-3063	2026-10-26 10:36:00+00	SKU-142	3	226.32	93.53	2026-10-26 12:46:26.732393+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	66
116	TXN-3064	2026-10-29 08:11:00+00	SKU-125	15	110.37	52.60	2026-10-26 12:46:26.732417+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	51
117	TXN-3065	2026-10-29 08:23:00+00	SKU-104	3	97.34	49.45	2026-10-26 12:46:26.732441+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	38
118	TXN-3066	2026-10-28 17:35:00+00	SKU-109	6	63.96	30.13	2026-10-26 12:46:26.732466+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	35
119	TXN-3067	2026-10-25 12:05:00+00	SKU-113	1	166.28	68.06	2026-10-26 12:46:26.73249+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	41
120	TXN-3068	2026-10-27 17:59:00+00	SKU-145	5	159.29	93.89	2026-10-26 12:46:26.732514+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	54
121	TXN-3069	2026-10-26 15:07:00+00	SKU-116	4	118.06	78.77	2026-10-26 12:46:26.732538+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	65
122	TXN-3070	2026-10-26 14:15:00+00	SKU-107	11	43.06	26.09	2026-10-26 12:46:26.732561+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	39
123	TXN-3071	2026-10-29 11:32:00+00	SKU-118	19	145.81	95.62	2026-10-26 12:46:26.732585+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	46
124	TXN-3072	2026-10-26 10:09:00+00	SKU-122	10	70.47	47.88	2026-10-26 12:46:26.732609+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	47
125	TXN-3073	2026-10-27 10:54:00+00	SKU-110	11	246.12	105.85	2026-10-26 12:46:26.732658+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	36
126	TXN-3074	2026-10-30 17:01:00+00	SKU-110	7	62.38	40.89	2026-10-26 12:46:26.732731+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	36
127	TXN-3075	2026-10-28 18:08:00+00	SKU-100	6	12.83	5.43	2026-10-26 12:46:26.732787+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	73
128	TXN-3076	2026-10-27 16:15:00+00	SKU-133	17	199.45	88.31	2026-10-26 12:46:26.732827+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	74
129	TXN-3077	2026-10-30 13:23:00+00	SKU-112	8	103.52	47.03	2026-10-26 12:46:26.732867+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	43
130	TXN-3078	2026-10-30 14:56:00+00	SKU-126	19	12.58	8.65	2026-10-26 12:46:26.732908+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	77
131	TXN-3079	2026-10-30 08:30:00+00	SKU-100	4	222.52	110.46	2026-10-26 12:46:26.732949+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	73
132	TXN-3080	2026-10-28 09:34:00+00	SKU-140	14	35.82	20.98	2026-10-26 12:46:26.73299+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	49
133	TXN-3081	2026-10-25 13:01:00+00	SKU-144	9	227.60	141.67	2026-10-26 12:46:26.733032+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	76
134	TXN-3082	2026-10-26 16:08:00+00	SKU-138	7	23.30	10.68	2026-10-26 12:46:26.733072+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	45
135	TXN-3083	2026-10-28 08:01:00+00	SKU-118	16	53.09	30.58	2026-10-26 12:46:26.733112+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	46
136	TXN-3084	2026-10-29 09:40:00+00	SKU-143	2	143.83	72.97	2026-10-26 12:46:26.733153+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	68
137	TXN-3085	2026-10-25 17:20:00+00	SKU-113	15	117.20	63.46	2026-10-26 12:46:26.733193+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	41
138	TXN-3086	2026-10-29 17:37:00+00	SKU-127	13	6.63	2.70	2026-10-26 12:46:26.733233+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	70
139	TXN-3087	2026-10-26 09:30:00+00	SKU-112	19	85.27	49.52	2026-10-26 12:46:26.73331+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	43
140	TXN-3088	2026-10-26 12:15:00+00	SKU-122	6	144.28	76.60	2026-10-26 12:46:26.733365+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	47
141	TXN-3089	2026-10-26 10:30:00+00	SKU-124	6	51.59	33.69	2026-10-26 12:46:26.733406+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	62
142	TXN-3090	2026-10-25 09:06:00+00	SKU-114	19	153.50	81.09	2026-10-26 12:46:26.733447+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	75
143	TXN-3091	2026-10-25 18:43:00+00	SKU-125	7	70.33	28.82	2026-10-26 12:46:26.733487+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	51
144	TXN-3092	2026-10-28 17:33:00+00	SKU-101	5	162.04	94.94	2026-10-26 12:46:26.733527+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	33
145	TXN-3093	2026-10-28 13:11:00+00	SKU-110	18	161.07	102.83	2026-10-26 12:46:26.733567+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	36
146	TXN-3094	2026-10-29 11:16:00+00	SKU-106	9	169.84	85.86	2026-10-26 12:46:26.733621+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	37
147	TXN-3095	2026-10-30 15:09:00+00	SKU-141	6	234.68	115.70	2026-10-26 12:46:26.733664+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	53
148	TXN-3096	2026-10-27 11:49:00+00	SKU-129	6	73.89	49.45	2026-10-26 12:46:26.733705+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	52
149	TXN-3097	2026-10-30 15:28:00+00	SKU-126	20	62.16	27.22	2026-10-26 12:46:26.733749+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	77
150	TXN-3098	2026-10-25 12:22:00+00	SKU-122	11	60.16	26.59	2026-10-26 12:46:26.73379+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	47
151	TXN-3099	2026-10-25 17:35:00+00	SKU-120	14	148.71	64.49	2026-10-26 12:46:26.733834+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	44
152	TXN-3100	2026-10-30 18:44:00+00	SKU-114	4	49.92	31.36	2026-10-26 12:46:26.733876+00	dbb49ffa-2145-4d13-a7a3-d72938176cfe	75
153	TXN-3001	2026-10-30 10:13:00+00	SKU-134	14	169.32	76.39	2026-10-26 20:29:40.93348+00	a40c457e-cee1-4f09-94bc-f81c8477e3b5	78
154	TXN-3002	2026-10-28 12:05:00+00	SKU-106	18	35.58	21.66	2026-10-26 20:29:40.933588+00	a40c457e-cee1-4f09-94bc-f81c8477e3b5	37
155	TXN-3003	2026-10-25 08:09:00+00	SKU-123	17	6.81	2.78	2026-10-26 20:29:40.933707+00	a40c457e-cee1-4f09-94bc-f81c8477e3b5	71
156	TXN-3004	2026-10-30 18:20:00+00	SKU-129	8	132.46	56.75	2026-10-26 20:29:40.933808+00	a40c457e-cee1-4f09-94bc-f81c8477e3b5	52
157	TXN-3005	2026-10-28 08:01:00+00	SKU-137	17	230.49	98.92	2026-10-26 20:29:40.933924+00	a40c457e-cee1-4f09-94bc-f81c8477e3b5	58
158	TXN-3006	2026-10-25 15:35:00+00	SKU-118	20	23.56	9.99	2026-10-26 20:29:40.934025+00	a40c457e-cee1-4f09-94bc-f81c8477e3b5	46
159	TXN-3007	2026-10-27 09:27:00+00	SKU-109	7	187.89	105.83	2026-10-26 20:29:40.934134+00	a40c457e-cee1-4f09-94bc-f81c8477e3b5	35
160	TXN-3008	2026-10-25 12:27:00+00	SKU-134	12	100.89	54.34	2026-10-26 20:29:40.934248+00	a40c457e-cee1-4f09-94bc-f81c8477e3b5	78
161	TXN-3009	2026-10-29 08:51:00+00	SKU-105	9	246.59	108.40	2026-10-26 20:29:40.934372+00	a40c457e-cee1-4f09-94bc-f81c8477e3b5	34
162	TXN-3010	2026-10-29 15:25:00+00	SKU-128	2	226.85	96.51	2026-10-26 20:29:40.93457+00	a40c457e-cee1-4f09-94bc-f81c8477e3b5	57
163	TXN-3011	2026-10-26 08:35:00+00	SKU-123	18	139.34	89.32	2026-10-26 20:29:40.934651+00	a40c457e-cee1-4f09-94bc-f81c8477e3b5	71
164	TXN-3012	2026-10-27 14:50:00+00	SKU-138	17	60.98	31.99	2026-10-26 20:29:40.93474+00	a40c457e-cee1-4f09-94bc-f81c8477e3b5	45
\.


--
-- Data for Name: kafka_rejected_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.kafka_rejected_events (rejection_id, event_id, raw_payload, reason, rejected_at) FROM stdin;
1	9660f341-c4c6-4ac6-b039-609ed683da5a	{"sku": "SKU-001", "sold_at": "2026-10-25T11:49:26.496199+00:00", "event_id": "9660f341-c4c6-4ac6-b039-609ed683da5a", "quantity": 2, "unit_cost": 15.0, "unit_price": 25.0, "transaction_id": "TXN-KAFKA-001"}	Duplicate sale: transaction_id and SKU already exist, or this event_id has already been processed	2026-10-25 11:49:26.620597+00
2	8e53e984-a121-4ca6-9b72-643add70300a	{"sku": "SKU-002", "sold_at": "2026-10-25T11:49:26.496199+00:00", "event_id": "8e53e984-a121-4ca6-9b72-643add70300a", "quantity": 3, "unit_cost": 28.0, "unit_price": 40.0, "transaction_id": "TXN-KAFKA-002"}	Duplicate sale: transaction_id and SKU already exist, or this event_id has already been processed	2026-10-25 11:49:26.725179+00
3	d129211c-96a5-4583-93b1-61f792481a05	{"sku": "SKU-001", "sold_at": "2026-10-25T11:52:58.255564+00:00", "event_id": "d129211c-96a5-4583-93b1-61f792481a05", "quantity": 2, "unit_cost": 15.0, "unit_price": 25.0, "transaction_id": "TXN-KAFKA-001"}	Duplicate sale: transaction_id and SKU already exist, or this event_id has already been processed	2026-10-25 11:52:58.447055+00
4	5354b5a9-115b-4b9f-881b-25157541f7ab	{"sku": "SKU-003", "sold_at": "2026-10-25T11:52:58.256088+00:00", "event_id": "5354b5a9-115b-4b9f-881b-25157541f7ab", "quantity": -3, "unit_cost": 28.0, "unit_price": 40.0, "transaction_id": "TXN-KAFKA-003"}	Quantity must be a positive integer	2026-10-25 11:52:58.584949+00
5	2c9e9541-b943-4095-8de4-dd65ec53c2c3	{"sku": "SKU-002", "sold_at": "2026-10-25T11:52:58.256088+00:00", "event_id": "2c9e9541-b943-4095-8de4-dd65ec53c2c3", "quantity": 3, "unit_cost": 28.0, "unit_price": 40.0, "transaction_id": "TXN-KAFKA-002"}	Duplicate sale: transaction_id and SKU already exist, or this event_id has already been processed	2026-10-25 11:52:58.636904+00
6	5354b5a9-115b-4b9f-881b-25157541f7ab	"{\\"event_id\\": \\"5354b5a9-115b-4b9f-881b-25157541f7ab\\", \\"transaction_id\\": \\"TXN-KAFKA-003\\", \\"sold_at\\": \\"2026-10-25T11:52:58.256088+00:00\\", \\"sku\\": \\"SKU-003\\", \\"quantity\\": -3, \\"unit_price\\": 40.0, \\"unit_cost\\": 28.0}"	Validation failed: Quantity must be a positive integer	2026-10-25 12:14:27.563864+00
7	\N	"{\\"transaction_id\\": "	Invalid JSON: Expecting value: line 1 column 20 (char 19)	2026-10-25 12:14:27.83941+00
8	not-a-valid-event	"{\\"event_id\\": \\"not-a-valid-event\\", \\"transaction_id\\": \\"TXN-BAD-001\\"}"	Validation failed: Missing fields: ['quantity', 'sku', 'sold_at', 'unit_cost', 'unit_price']	2026-10-25 12:14:28.27093+00
9	f9307c52-b9df-48c7-85c6-58e6f7640001	"{\\"event_id\\": \\"f9307c52-b9df-48c7-85c6-58e6f7640001\\", \\"transaction_id\\": \\"TXN-KAFKA-001\\", \\"sold_at\\": \\"2026-10-25T10:00:00+00:00\\", \\"sku\\": \\"SKU-001\\", \\"quantity\\": 2, \\"unit_price\\": 25.0, \\"unit_cost\\": 15.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-25 12:14:28.437408+00
10	3a802587-8327-4f0e-9c7c-6a8cd010e5c4	"{\\"event_id\\": \\"3a802587-8327-4f0e-9c7c-6a8cd010e5c4\\", \\"transaction_id\\": \\"TXN-KAFKA-001\\", \\"sold_at\\": \\"2026-10-25T11:08:29.623664+00:00\\", \\"sku\\": \\"SKU-001\\", \\"quantity\\": 2, \\"unit_price\\": 25.0, \\"unit_cost\\": 15.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-25 12:14:28.511584+00
11	9551bd23-2b66-44e0-9947-c6ccca57218f	"{\\"event_id\\": \\"9551bd23-2b66-44e0-9947-c6ccca57218f\\", \\"transaction_id\\": \\"TXN-KAFKA-002\\", \\"sold_at\\": \\"2026-10-25T11:08:29.623735+00:00\\", \\"sku\\": \\"SKU-002\\", \\"quantity\\": 3, \\"unit_price\\": 40.0, \\"unit_cost\\": 28.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-25 12:14:28.66293+00
12	cc957298-c54c-4136-8518-c86c6b85be5e	"{\\"event_id\\": \\"cc957298-c54c-4136-8518-c86c6b85be5e\\", \\"transaction_id\\": \\"TXN-KAFKA-001\\", \\"sold_at\\": \\"2026-10-25T11:38:05.549245+00:00\\", \\"sku\\": \\"SKU-001\\", \\"quantity\\": 2, \\"unit_price\\": 25.0, \\"unit_cost\\": 15.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-25 12:14:28.851868+00
13	afe11923-92c4-4bec-ab4a-06ff9a9150d8	"{\\"event_id\\": \\"afe11923-92c4-4bec-ab4a-06ff9a9150d8\\", \\"transaction_id\\": \\"TXN-KAFKA-002\\", \\"sold_at\\": \\"2026-10-25T11:38:05.549245+00:00\\", \\"sku\\": \\"SKU-002\\", \\"quantity\\": 3, \\"unit_price\\": 40.0, \\"unit_cost\\": 28.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-25 12:14:29.016246+00
14	82765150-372c-4f9a-b71f-f38dab97be74	"{\\"event_id\\": \\"82765150-372c-4f9a-b71f-f38dab97be74\\", \\"transaction_id\\": \\"TXN-KAFKA-001\\", \\"sold_at\\": \\"2026-10-25T11:38:56.336999+00:00\\", \\"sku\\": \\"SKU-001\\", \\"quantity\\": 2, \\"unit_price\\": 25.0, \\"unit_cost\\": 15.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-25 12:14:29.160549+00
15	b60bff56-6f42-4b7b-9189-3ffbe429912e	"{\\"event_id\\": \\"b60bff56-6f42-4b7b-9189-3ffbe429912e\\", \\"transaction_id\\": \\"TXN-KAFKA-002\\", \\"sold_at\\": \\"2026-10-25T11:38:56.336999+00:00\\", \\"sku\\": \\"SKU-002\\", \\"quantity\\": 3, \\"unit_price\\": 40.0, \\"unit_cost\\": 28.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-25 12:14:29.293884+00
16	9660f341-c4c6-4ac6-b039-609ed683da5a	"{\\"event_id\\": \\"9660f341-c4c6-4ac6-b039-609ed683da5a\\", \\"transaction_id\\": \\"TXN-KAFKA-001\\", \\"sold_at\\": \\"2026-10-25T11:49:26.496199+00:00\\", \\"sku\\": \\"SKU-001\\", \\"quantity\\": 2, \\"unit_price\\": 25.0, \\"unit_cost\\": 15.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-25 12:14:29.418352+00
17	8e53e984-a121-4ca6-9b72-643add70300a	"{\\"event_id\\": \\"8e53e984-a121-4ca6-9b72-643add70300a\\", \\"transaction_id\\": \\"TXN-KAFKA-002\\", \\"sold_at\\": \\"2026-10-25T11:49:26.496199+00:00\\", \\"sku\\": \\"SKU-002\\", \\"quantity\\": 3, \\"unit_price\\": 40.0, \\"unit_cost\\": 28.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-25 12:14:29.625499+00
18	d129211c-96a5-4583-93b1-61f792481a05	"{\\"event_id\\": \\"d129211c-96a5-4583-93b1-61f792481a05\\", \\"transaction_id\\": \\"TXN-KAFKA-001\\", \\"sold_at\\": \\"2026-10-25T11:52:58.255564+00:00\\", \\"sku\\": \\"SKU-001\\", \\"quantity\\": 2, \\"unit_price\\": 25.0, \\"unit_cost\\": 15.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-25 12:14:29.813022+00
19	2c9e9541-b943-4095-8de4-dd65ec53c2c3	"{\\"event_id\\": \\"2c9e9541-b943-4095-8de4-dd65ec53c2c3\\", \\"transaction_id\\": \\"TXN-KAFKA-002\\", \\"sold_at\\": \\"2026-10-25T11:52:58.256088+00:00\\", \\"sku\\": \\"SKU-002\\", \\"quantity\\": 3, \\"unit_price\\": 40.0, \\"unit_cost\\": 28.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-25 12:14:30.193698+00
20	\N	"{\\"transaction_id\\": "	Invalid JSON: Expecting value: line 1 column 20 (char 19)	2026-10-26 19:29:59.467338+00
21	not-a-valid-event	"{\\"event_id\\": \\"not-a-valid-event\\", \\"transaction_id\\": \\"TXN-BAD-001\\"}"	Validation failed: Missing fields: ['quantity', 'sku', 'sold_at', 'unit_cost', 'unit_price']	2026-10-26 19:30:00.273504+00
22	f9307c52-b9df-48c7-85c6-58e6f7640001	"{\\"event_id\\": \\"f9307c52-b9df-48c7-85c6-58e6f7640001\\", \\"transaction_id\\": \\"TXN-KAFKA-001\\", \\"sold_at\\": \\"2026-10-25T10:00:00+00:00\\", \\"sku\\": \\"SKU-001\\", \\"quantity\\": 2, \\"unit_price\\": 25.0, \\"unit_cost\\": 15.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-26 19:30:00.448038+00
23	\N	"{\\"transaction_id\\": "	Invalid JSON: Expecting value: line 1 column 20 (char 19)	2026-10-26 20:00:30.325688+00
24	not-a-valid-event	"{\\"event_id\\": \\"not-a-valid-event\\", \\"transaction_id\\": \\"TXN-BAD-001\\"}"	Validation failed: Missing fields: ['quantity', 'sku', 'sold_at', 'unit_cost', 'unit_price']	2026-10-26 20:00:31.066376+00
25	f9307c52-b9df-48c7-85c6-58e6f7640001	"{\\"event_id\\": \\"f9307c52-b9df-48c7-85c6-58e6f7640001\\", \\"transaction_id\\": \\"TXN-KAFKA-001\\", \\"sold_at\\": \\"2026-10-25T10:00:00+00:00\\", \\"sku\\": \\"SKU-001\\", \\"quantity\\": 2, \\"unit_price\\": 25.0, \\"unit_cost\\": 15.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-26 20:00:31.558769+00
26	2b63d232-83c4-49ec-b6e8-90c62beb902e	"{\\"event_id\\": \\"2b63d232-83c4-49ec-b6e8-90c62beb902e\\", \\"transaction_id\\": \\"SP-E2E-20261026-2055\\", \\"sold_at\\": \\"2026-10-26T21:07:04.112741+00:00\\", \\"sku\\": \\"TEST-E2E-001\\", \\"quantity\\": 2, \\"unit_price\\": 125.5, \\"unit_cost\\": 70.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-26 21:08:33.643547+00
27	f00b642c-b3b8-459c-9291-30c95e162fc6	"{\\"event_id\\": \\"f00b642c-b3b8-459c-9291-30c95e162fc6\\", \\"transaction_id\\": \\"TXN-KAFKA-001\\", \\"sold_at\\": \\"2026-10-27T08:51:03.143603+00:00\\", \\"sku\\": \\"SKU-001\\", \\"quantity\\": 2, \\"unit_price\\": 25.0, \\"unit_cost\\": 15.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-27 08:51:03.376048+00
28	612f5e26-04e5-4b20-a80b-09590577a33b	"{\\"event_id\\": \\"612f5e26-04e5-4b20-a80b-09590577a33b\\", \\"transaction_id\\": \\"TXN-KAFKA-003\\", \\"sold_at\\": \\"2026-10-27T08:51:03.143714+00:00\\", \\"sku\\": \\"SKU-003\\", \\"quantity\\": -3, \\"unit_price\\": 40.0, \\"unit_cost\\": 28.0}"	Validation failed: Quantity must be a positive integer	2026-10-27 08:51:03.682992+00
29	b15a8aaf-09a6-4e1d-bbd6-979d3be74842	"{\\"event_id\\": \\"b15a8aaf-09a6-4e1d-bbd6-979d3be74842\\", \\"transaction_id\\": \\"TXN-KAFKA-002\\", \\"sold_at\\": \\"2026-10-27T08:51:03.143677+00:00\\", \\"sku\\": \\"SKU-002\\", \\"quantity\\": 3, \\"unit_price\\": 40.0, \\"unit_cost\\": 28.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-27 08:51:03.741488+00
30	6cde450f-acc5-48d7-83b8-3bd12b178b3a	"{\\"event_id\\": \\"6cde450f-acc5-48d7-83b8-3bd12b178b3a\\", \\"transaction_id\\": \\"TXN-KAFKA-001\\", \\"sold_at\\": \\"2026-10-27T08:51:33.932953+00:00\\", \\"sku\\": \\"SKU-001\\", \\"quantity\\": 2, \\"unit_price\\": 25.0, \\"unit_cost\\": 15.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-27 08:51:34.222351+00
31	6de95353-3ee7-4382-92bc-a67d1d2caf84	"{\\"event_id\\": \\"6de95353-3ee7-4382-92bc-a67d1d2caf84\\", \\"transaction_id\\": \\"TXN-KAFKA-002\\", \\"sold_at\\": \\"2026-10-27T08:51:33.933036+00:00\\", \\"sku\\": \\"SKU-002\\", \\"quantity\\": 3, \\"unit_price\\": 40.0, \\"unit_cost\\": 28.0}"	Duplicate event: event_id or transaction_id + SKU already exists	2026-10-27 08:51:34.280924+00
32	edcb21c8-7162-49af-be10-6cd5dbb8c33f	"{\\"event_id\\": \\"edcb21c8-7162-49af-be10-6cd5dbb8c33f\\", \\"transaction_id\\": \\"TXN-KAFKA-003\\", \\"sold_at\\": \\"2026-10-27T08:51:33.933072+00:00\\", \\"sku\\": \\"SKU-003\\", \\"quantity\\": -3, \\"unit_price\\": 40.0, \\"unit_cost\\": 28.0}"	Validation failed: Quantity must be a positive integer	2026-10-27 08:51:34.371475+00
\.


--
-- Data for Name: kafka_sales_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.kafka_sales_events (event_id, transaction_id, sold_at, sku, quantity, unit_price, unit_cost, raw_payload, ingested_at) FROM stdin;
3a802587-8327-4f0e-9c7c-6a8cd010e5c4	TXN-KAFKA-001	2026-10-25 11:08:29.623664+00	SKU-001	2	25.00	15.00	{"sku": "SKU-001", "sold_at": "2026-10-25T11:08:29.623664+00:00", "event_id": "3a802587-8327-4f0e-9c7c-6a8cd010e5c4", "quantity": 2, "unit_cost": 15.0, "unit_price": 25.0, "transaction_id": "TXN-KAFKA-001"}	2026-10-25 11:37:54.956122+00
9551bd23-2b66-44e0-9947-c6ccca57218f	TXN-KAFKA-002	2026-10-25 11:08:29.623735+00	SKU-002	3	40.00	28.00	{"sku": "SKU-002", "sold_at": "2026-10-25T11:08:29.623735+00:00", "event_id": "9551bd23-2b66-44e0-9947-c6ccca57218f", "quantity": 3, "unit_cost": 28.0, "unit_price": 40.0, "transaction_id": "TXN-KAFKA-002"}	2026-10-25 11:37:55.067022+00
8b294bb7-b3a6-4d5f-9dba-cd5509a9fa76	SP-E2E-20261026-2055	2026-10-26 21:05:13.889454+00	TEST-E2E-001	2	125.50	70.00	{"sku": "TEST-E2E-001", "sold_at": "2026-10-26T21:05:13.889454+00:00", "event_id": "8b294bb7-b3a6-4d5f-9dba-cd5509a9fa76", "quantity": 2, "unit_cost": 70.0, "unit_price": 125.5, "transaction_id": "SP-E2E-20261026-2055"}	2026-10-26 21:08:33.564204+00
37e4534f-9e87-44d8-9a34-6e478fcd77a4	SP-E2E-20261027-UNIQUE-001	2026-10-26 21:13:33.376005+00	TEST-E2E-002	2	125.50	70.00	{"sku": "TEST-E2E-002", "sold_at": "2026-10-26T21:13:33.376005+00:00", "event_id": "37e4534f-9e87-44d8-9a34-6e478fcd77a4", "quantity": 2, "unit_cost": 70.0, "unit_price": 125.5, "transaction_id": "SP-E2E-20261027-UNIQUE-001"}	2026-10-26 21:13:33.564038+00
\.


--
-- Name: auth_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);


--
-- Name: auth_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auth_permission_id_seq', 40, true);


--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auth_user_groups_id_seq', 1, false);


--
-- Name: auth_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auth_user_id_seq', 1, false);


--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auth_user_user_permissions_id_seq', 1, false);


--
-- Name: django_admin_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);


--
-- Name: django_content_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.django_content_type_id_seq', 10, true);


--
-- Name: django_migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.django_migrations_id_seq', 22, true);


--
-- Name: ingestion_product_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ingestion_product_id_seq', 78, true);


--
-- Name: ingestion_rejectedrecord_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ingestion_rejectedrecord_id_seq', 31, true);


--
-- Name: ingestion_salerecord_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ingestion_salerecord_id_seq', 164, true);


--
-- Name: kafka_rejected_events_rejection_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.kafka_rejected_events_rejection_id_seq', 32, true);


--
-- Name: auth_group auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- Name: auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);


--
-- Name: auth_group_permissions auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_group auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- Name: auth_permission auth_permission_content_type_id_codename_01ab375a_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);


--
-- Name: auth_permission auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups auth_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups auth_user_groups_user_id_group_id_94350c0c_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_group_id_94350c0c_uniq UNIQUE (user_id, group_id);


--
-- Name: auth_user auth_user_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_user
    ADD CONSTRAINT auth_user_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions auth_user_user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_permission_id_14a6b632_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_permission_id_14a6b632_uniq UNIQUE (user_id, permission_id);


--
-- Name: auth_user auth_user_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_user
    ADD CONSTRAINT auth_user_username_key UNIQUE (username);


--
-- Name: django_admin_log django_admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- Name: django_content_type django_content_type_app_label_model_76bd3d3b_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);


--
-- Name: django_content_type django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- Name: django_migrations django_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- Name: django_session django_session_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- Name: ingestion_ingestionrun ingestion_ingestionrun_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingestion_ingestionrun
    ADD CONSTRAINT ingestion_ingestionrun_pkey PRIMARY KEY (id);


--
-- Name: ingestion_product ingestion_product_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingestion_product
    ADD CONSTRAINT ingestion_product_pkey PRIMARY KEY (id);


--
-- Name: ingestion_product ingestion_product_sku_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingestion_product
    ADD CONSTRAINT ingestion_product_sku_key UNIQUE (sku);


--
-- Name: ingestion_rejectedrecord ingestion_rejectedrecord_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingestion_rejectedrecord
    ADD CONSTRAINT ingestion_rejectedrecord_pkey PRIMARY KEY (id);


--
-- Name: ingestion_salerecord ingestion_salerecord_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingestion_salerecord
    ADD CONSTRAINT ingestion_salerecord_pkey PRIMARY KEY (id);


--
-- Name: kafka_rejected_events kafka_rejected_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kafka_rejected_events
    ADD CONSTRAINT kafka_rejected_events_pkey PRIMARY KEY (rejection_id);


--
-- Name: kafka_sales_events kafka_sales_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kafka_sales_events
    ADD CONSTRAINT kafka_sales_events_pkey PRIMARY KEY (event_id);


--
-- Name: ingestion_salerecord uniq_sale_transaction_sku; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingestion_salerecord
    ADD CONSTRAINT uniq_sale_transaction_sku UNIQUE (transaction_id, sku);


--
-- Name: kafka_sales_events uq_kafka_sales_transaction_sku; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kafka_sales_events
    ADD CONSTRAINT uq_kafka_sales_transaction_sku UNIQUE (transaction_id, sku);


--
-- Name: auth_group_name_a6ea08ec_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);


--
-- Name: auth_group_permissions_group_id_b120cbf9; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);


--
-- Name: auth_group_permissions_permission_id_84c5c92e; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);


--
-- Name: auth_permission_content_type_id_2f476e4b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);


--
-- Name: auth_user_groups_group_id_97559544; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_groups_group_id_97559544 ON public.auth_user_groups USING btree (group_id);


--
-- Name: auth_user_groups_user_id_6a12ed8b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_groups_user_id_6a12ed8b ON public.auth_user_groups USING btree (user_id);


--
-- Name: auth_user_user_permissions_permission_id_1fbb5f2c; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_user_permissions_permission_id_1fbb5f2c ON public.auth_user_user_permissions USING btree (permission_id);


--
-- Name: auth_user_user_permissions_user_id_a95ead1b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_user_permissions_user_id_a95ead1b ON public.auth_user_user_permissions USING btree (user_id);


--
-- Name: auth_user_username_6821ab7c_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_user_username_6821ab7c_like ON public.auth_user USING btree (username varchar_pattern_ops);


--
-- Name: django_admin_log_content_type_id_c4bce8eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);


--
-- Name: django_admin_log_user_id_c564eba6; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);


--
-- Name: django_session_expire_date_a5c62663; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);


--
-- Name: django_session_session_key_c0390e0f_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);


--
-- Name: idx_kafka_sales_sku_sold_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_kafka_sales_sku_sold_at ON public.kafka_sales_events USING btree (sku, sold_at);


--
-- Name: idx_kafka_sales_sold_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_kafka_sales_sold_at ON public.kafka_sales_events USING btree (sold_at);


--
-- Name: ingestion_product_sku_1a923e5d_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ingestion_product_sku_1a923e5d_like ON public.ingestion_product USING btree (sku varchar_pattern_ops);


--
-- Name: ingestion_rejectedrecord_ingestion_run_id_427d9e54; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ingestion_rejectedrecord_ingestion_run_id_427d9e54 ON public.ingestion_rejectedrecord USING btree (ingestion_run_id);


--
-- Name: ingestion_salerecord_product_id_b9089e13; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ingestion_salerecord_product_id_b9089e13 ON public.ingestion_salerecord USING btree (product_id);


--
-- Name: ingestion_salerecord_source_run_id_74dd04e2; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ingestion_salerecord_source_run_id_74dd04e2 ON public.ingestion_salerecord USING btree (source_run_id);


--
-- Name: reject_run_row_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX reject_run_row_idx ON public.ingestion_rejectedrecord USING btree (ingestion_run_id, source_row_number);


--
-- Name: sale_sku_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_sku_date_idx ON public.ingestion_salerecord USING btree (sku, sold_at);


--
-- Name: sale_sold_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_sold_at_idx ON public.ingestion_salerecord USING btree (sold_at);


--
-- Name: auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups auth_user_groups_group_id_97559544_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_group_id_97559544_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups auth_user_groups_user_id_6a12ed8b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_6a12ed8b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log django_admin_log_user_id_c564eba6_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: ingestion_rejectedrecord ingestion_rejectedre_ingestion_run_id_427d9e54_fk_ingestion; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingestion_rejectedrecord
    ADD CONSTRAINT ingestion_rejectedre_ingestion_run_id_427d9e54_fk_ingestion FOREIGN KEY (ingestion_run_id) REFERENCES public.ingestion_ingestionrun(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: ingestion_salerecord ingestion_salerecord_product_id_b9089e13_fk_ingestion; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingestion_salerecord
    ADD CONSTRAINT ingestion_salerecord_product_id_b9089e13_fk_ingestion FOREIGN KEY (product_id) REFERENCES public.ingestion_product(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: ingestion_salerecord ingestion_salerecord_source_run_id_74dd04e2_fk_ingestion; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingestion_salerecord
    ADD CONSTRAINT ingestion_salerecord_source_run_id_74dd04e2_fk_ingestion FOREIGN KEY (source_run_id) REFERENCES public.ingestion_ingestionrun(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


--
-- PostgreSQL database dump complete
--

\unrestrict nbXFQYgO6GtOPNf2htgKflKLJjczJfvVkkQPeI91Y3mdxaqQwzoB3pJyNWgNYEm

