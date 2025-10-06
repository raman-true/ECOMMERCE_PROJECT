-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.addresses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  type text NOT NULL CHECK (type = ANY (ARRAY['billing'::text, 'shipping'::text])),
  first_name text NOT NULL,
  last_name text NOT NULL,
  company text,
  address1 text NOT NULL,
  address2 text,
  city text NOT NULL,
  state text NOT NULL,
  postcode text NOT NULL,
  country text NOT NULL DEFAULT 'Australia'::text,
  phone text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT addresses_pkey PRIMARY KEY (id),
  CONSTRAINT addresses_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.cart_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  product_id uuid,
  variant_id uuid,
  quantity integer NOT NULL DEFAULT 1 CHECK (quantity > 0),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT cart_items_pkey PRIMARY KEY (id),
  CONSTRAINT cart_items_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT cart_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT cart_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id)
);
CREATE TABLE public.categories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text DEFAULT ''::text,
  image text DEFAULT ''::text,
  product_count integer DEFAULT 0,
  department_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  seller_id uuid,
  CONSTRAINT categories_pkey PRIMARY KEY (id),
  CONSTRAINT categories_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id),
  CONSTRAINT categories_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES auth.users(id)
);
CREATE TABLE public.departments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text DEFAULT ''::text,
  image text DEFAULT ''::text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT departments_pkey PRIMARY KEY (id)
);
CREATE TABLE public.diy_articles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  excerpt text DEFAULT ''::text,
  content text DEFAULT ''::text,
  featured_image text DEFAULT ''::text,
  author text DEFAULT ''::text,
  published_at timestamp with time zone DEFAULT now(),
  category text DEFAULT ''::text,
  tags ARRAY DEFAULT '{}'::text[],
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT diy_articles_pkey PRIMARY KEY (id)
);
CREATE TABLE public.global_settings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  default_tax_rate numeric DEFAULT 0.00,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT global_settings_pkey PRIMARY KEY (id)
);
CREATE TABLE public.order_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid,
  product_id uuid,
  variant_id uuid,
  quantity integer NOT NULL DEFAULT 1 CHECK (quantity > 0),
  price numeric NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT order_items_pkey PRIMARY KEY (id),
  CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id),
  CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT order_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id)
);
CREATE TABLE public.orders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  order_number text NOT NULL UNIQUE,
  status text DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'processing'::text, 'shipped'::text, 'delivered'::text, 'cancelled'::text])),
  total numeric NOT NULL,
  shipping_address_id uuid,
  billing_address_id uuid,
  delivery_method text DEFAULT 'shipping'::text CHECK (delivery_method = ANY (ARRAY['shipping'::text, 'click-collect'::text])),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT orders_pkey PRIMARY KEY (id),
  CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT orders_shipping_address_id_fkey FOREIGN KEY (shipping_address_id) REFERENCES public.addresses(id),
  CONSTRAINT orders_billing_address_id_fkey FOREIGN KEY (billing_address_id) REFERENCES public.addresses(id)
);
CREATE TABLE public.product_variants (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid,
  name text NOT NULL,
  price numeric NOT NULL,
  stock integer DEFAULT 0,
  attributes jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT product_variants_pkey PRIMARY KEY (id),
  CONSTRAINT product_variants_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id)
);
CREATE TABLE public.products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text DEFAULT ''::text,
  price numeric NOT NULL,
  original_price numeric,
  images ARRAY DEFAULT '{}'::text[],
  category_id uuid,
  department_id uuid,
  brand text DEFAULT ''::text,
  rating numeric DEFAULT 0 CHECK (rating >= 0::numeric AND rating <= 5::numeric),
  review_count integer DEFAULT 0,
  stock integer DEFAULT 0,
  specifications jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  seller_id uuid,
  discount_type text,
  discount_value numeric,
  is_taxable boolean DEFAULT true,
  is_shipping_exempt boolean DEFAULT false,
  CONSTRAINT products_pkey PRIMARY KEY (id),
  CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id),
  CONSTRAINT products_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id),
  CONSTRAINT products_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES public.user_profiles(id)
);
CREATE TABLE public.seller_settings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  seller_id uuid UNIQUE,
  tax_rate numeric DEFAULT 0.00,
  freight_rules jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT seller_settings_pkey PRIMARY KEY (id),
  CONSTRAINT seller_settings_seller_id_fkey FOREIGN KEY (seller_id) REFERENCES auth.users(id)
);
CREATE TABLE public.services (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text DEFAULT ''::text,
  image text DEFAULT ''::text,
  price numeric NOT NULL,
  duration text DEFAULT ''::text,
  category text DEFAULT ''::text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT services_pkey PRIMARY KEY (id)
);
CREATE TABLE public.user_profiles (
  id uuid NOT NULL,
  first_name text DEFAULT ''::text,
  last_name text DEFAULT ''::text,
  role text DEFAULT 'customer'::text CHECK (role = ANY (ARRAY['customer'::text, 'admin'::text, 'seller'::text])),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_profiles_pkey PRIMARY KEY (id),
  CONSTRAINT user_profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.wishlist (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  product_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT wishlist_pkey PRIMARY KEY (id),
  CONSTRAINT wishlist_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT wishlist_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id)
);