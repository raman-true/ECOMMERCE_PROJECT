-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.admin_users (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  email text NOT NULL UNIQUE,
  role text DEFAULT 'admin'::text CHECK (role = ANY (ARRAY['admin'::text, 'moderator'::text])),
  last_login timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  auth_user_id uuid,
  CONSTRAINT admin_users_pkey PRIMARY KEY (id),
  CONSTRAINT admin_users_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.apis (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY['FREE'::text, 'PRO'::text, 'DISABLED'::text])),
  global_buy_price numeric DEFAULT 0,
  global_sell_price numeric DEFAULT 0,
  default_credit_charge numeric DEFAULT 0,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  service_provider text DEFAULT 'Direct'::text,
  api_key text NOT NULL,
  key_status text NOT NULL DEFAULT 'Inactive'::text CHECK (key_status = ANY (ARRAY['Active'::text, 'Inactive'::text])),
  usage_count integer NOT NULL DEFAULT 0,
  last_used timestamp with time zone,
  case_id text,
  CONSTRAINT apis_pkey PRIMARY KEY (id)
);
CREATE TABLE public.credit_transactions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  officer_id uuid,
  officer_name text NOT NULL,
  action text NOT NULL CHECK (action = ANY (ARRAY['Renewal'::text, 'Deduction'::text, 'Top-up'::text, 'Refund'::text])),
  credits numeric NOT NULL,
  payment_mode text DEFAULT 'Department Budget'::text,
  remarks text,
  processed_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT credit_transactions_pkey PRIMARY KEY (id),
  CONSTRAINT credit_transactions_officer_id_fkey FOREIGN KEY (officer_id) REFERENCES public.officers(id)
);
CREATE TABLE public.live_requests (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  officer_id uuid,
  officer_name text NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY['OSINT'::text, 'PRO'::text])),
  query_text text NOT NULL,
  status text DEFAULT 'Processing'::text CHECK (status = ANY (ARRAY['Processing'::text, 'Success'::text, 'Failed'::text])),
  response_time_ms integer,
  created_at timestamp with time zone DEFAULT now(),
  completed_at timestamp with time zone,
  CONSTRAINT live_requests_pkey PRIMARY KEY (id),
  CONSTRAINT live_requests_officer_id_fkey FOREIGN KEY (officer_id) REFERENCES public.officers(id)
);
CREATE TABLE public.manual_requests (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  officer_id uuid NOT NULL,
  input_type text NOT NULL CHECK (input_type = ANY (ARRAY['Mobile'::text, 'Email'::text, 'PAN'::text, 'Name'::text, 'Address'::text, 'Other'::text])),
  input_value text NOT NULL,
  notes text,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])),
  admin_response text,
  credit_deducted numeric,
  approved_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  approved_at timestamp with time zone,
  CONSTRAINT manual_requests_pkey PRIMARY KEY (id),
  CONSTRAINT manual_requests_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.admin_users(id),
  CONSTRAINT manual_requests_officer_id_fkey FOREIGN KEY (officer_id) REFERENCES public.officers(id)
);
CREATE TABLE public.officer_notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  officer_id uuid NOT NULL,
  type text NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  read boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  link text,
  CONSTRAINT officer_notifications_pkey PRIMARY KEY (id),
  CONSTRAINT officer_notifications_officer_id_fkey FOREIGN KEY (officer_id) REFERENCES public.officers(id)
);
CREATE TABLE public.officer_registrations (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  email text NOT NULL UNIQUE,
  mobile text NOT NULL UNIQUE,
  station text NOT NULL,
  department text,
  rank text,
  badge_number text,
  additional_info text,
  status text DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])),
  reviewed_at timestamp with time zone,
  reviewed_by text,
  rejection_reason text,
  created_at timestamp with time zone DEFAULT now(),
  identicard_url text,
  telegram_id text,
  terms_accepted_at timestamp with time zone,
  terms_ip_address text,
  terms_user_agent text,
  terms_version text,
  agreed_to_terms boolean DEFAULT false,
  terms_agreement_pdf_url text,
  CONSTRAINT officer_registrations_pkey PRIMARY KEY (id)
);
CREATE TABLE public.officers (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  email text NOT NULL UNIQUE,
  mobile text NOT NULL UNIQUE,
  telegram_id text UNIQUE,
  status text DEFAULT 'Active'::text CHECK (status = ANY (ARRAY['Active'::text, 'Suspended'::text])),
  department text,
  rank text,
  badge_number text,
  station text,
  credits_remaining numeric DEFAULT 50,
  total_credits numeric DEFAULT 50,
  total_queries integer DEFAULT 0,
  device_fingerprint text,
  session_token text,
  last_active timestamp with time zone DEFAULT now(),
  registered_on timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  plan_id uuid,
  plan_start_date timestamp with time zone NOT NULL DEFAULT now(),
  current_session_id uuid,
  auth_user_id uuid,
  CONSTRAINT officers_pkey PRIMARY KEY (id),
  CONSTRAINT officers_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.rate_plans(id),
  CONSTRAINT officers_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.plan_apis (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  plan_id uuid,
  api_id uuid,
  enabled boolean DEFAULT false,
  credit_cost numeric DEFAULT 0,
  buy_price numeric DEFAULT 0,
  sell_price numeric DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT plan_apis_pkey PRIMARY KEY (id),
  CONSTRAINT plan_apis_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.rate_plans(id),
  CONSTRAINT plan_apis_api_id_fkey FOREIGN KEY (api_id) REFERENCES public.apis(id)
);
CREATE TABLE public.queries (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  officer_id uuid,
  officer_name text NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY['OSINT'::text, 'PRO'::text])),
  category text NOT NULL,
  input_data text NOT NULL,
  source text,
  result_summary text,
  full_result jsonb,
  credits_used numeric DEFAULT 0,
  status text DEFAULT 'Processing'::text CHECK (status = ANY (ARRAY['Processing'::text, 'Success'::text, 'Failed'::text, 'Pending'::text])),
  ip_address inet,
  user_agent text,
  created_at timestamp with time zone DEFAULT now(),
  consent_event_id uuid,
  case_id text,
  CONSTRAINT queries_pkey PRIMARY KEY (id),
  CONSTRAINT queries_officer_id_fkey FOREIGN KEY (officer_id) REFERENCES public.officers(id)
);
CREATE TABLE public.rate_plans (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  plan_name text NOT NULL,
  user_type text NOT NULL CHECK (user_type = ANY (ARRAY['Police'::text, 'Private'::text, 'Custom'::text])),
  monthly_fee numeric NOT NULL,
  default_credits numeric NOT NULL,
  renewal_required boolean DEFAULT true,
  topup_allowed boolean DEFAULT true,
  status text DEFAULT 'Active'::text CHECK (status = ANY (ARRAY['Active'::text, 'Inactive'::text])),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  validity_days integer DEFAULT 30,
  carry_forward_credits_on_renewal boolean DEFAULT false,
  CONSTRAINT rate_plans_pkey PRIMARY KEY (id)
);
CREATE TABLE public.system_settings (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  key text NOT NULL UNIQUE,
  value jsonb NOT NULL,
  description text,
  updated_by text,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT system_settings_pkey PRIMARY KEY (id)
);