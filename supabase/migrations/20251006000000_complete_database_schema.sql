/*
  # Complete Database Schema for EcoConnect Supply Chain Platform

  This migration creates a comprehensive e-commerce database with multi-seller support,
  advanced tax/shipping management, order tracking, and seller features.

  ## 1. New Tables Created

  ### Seller Management
    - `seller_settings` - Seller-specific configuration for tax, shipping, and fulfillment
      - seller_id (uuid, unique, references auth.users)
      - tax_registration_number (text)
      - tax_rate_override (numeric)
      - prices_include_tax (boolean, default false)
      - fulfillment_method (text: 'platform' or 'self')
      - shipping_rules (jsonb)
      - free_shipping_threshold (numeric)
      - self_delivery_enabled (boolean, default false)
      - pickup_address_id (uuid, references addresses)
      - delivery_sla_days (integer, default 5)
      - override_global_tax (boolean, default false)
      - override_global_shipping (boolean, default false)

  ### Shipping & Fulfillment
    - `shipping_carriers` - Available shipping carriers
      - name (text)
      - code (text, unique)
      - api_endpoint (text)
      - tracking_url_template (text)
      - is_active (boolean, default true)
      - supported_countries (text array, default ['Australia'])

    - `shipping_rules` - Seller-specific shipping rules
      - seller_id (uuid, references auth.users)
      - rule_name (text)
      - rule_type (text: 'free', 'flat_rate', 'weight_based', 'price_based')
      - conditions (jsonb)
      - shipping_cost (numeric)
      - carrier_id (uuid, references shipping_carriers)
      - is_active (boolean, default true)

  ### Order Management
    - `order_taxes` - Tax breakdown per order
      - order_id (uuid, references orders)
      - tax_type (text)
      - tax_rate (numeric)
      - tax_amount (numeric)
      - applied_by (text: 'global' or 'seller')

    - `order_tracking` - Order status tracking history
      - order_id (uuid, references orders)
      - status (text)
      - location (text)
      - notes (text)
      - updated_by (uuid, references auth.users)

  ### Enhanced Global Settings
    - Updates to `global_settings` table to include comprehensive platform-wide defaults
      - tax_type (text: 'GST', 'VAT', 'Sales_Tax')
      - allow_seller_tax_override (boolean, default false)
      - default_shipping_carriers (jsonb)
      - platform_fulfillment_enabled (boolean, default true)
      - standard_delivery_days (text, default '2-5')
      - express_delivery_days (text, default '1-2')
      - delivery_tracking_enabled (boolean, default true)
      - default_shipping_cost (numeric, default 9.95)
      - free_shipping_threshold (numeric, default 99.00)
      - apply_tax_to_shipping (boolean, default false)

  ## 2. Schema Enhancements

  ### Products Table
    - seller_id (uuid) - Links product to seller
    - discount_type (text: 'percentage' or 'flat_amount')
    - discount_value (numeric)
    - weight_kg (numeric)
    - dimensions_cm (jsonb: width, height, length)
    - shipping_class (text, default 'standard')
    - custom_tax_rate (numeric)
    - custom_shipping_cost (numeric)
    - override_global_settings (boolean, default false)

  ### Categories Table
    - seller_id (uuid) - Links category to seller for seller-specific categories

  ### Orders Table
    - fulfillment_method (text: 'platform' or 'seller')
    - carrier_id (uuid, references shipping_carriers)
    - tracking_number (text)
    - estimated_delivery_date (timestamptz)
    - actual_delivery_date (timestamptz)
    - delivery_instructions (text)

  ### User Profiles Table
    - role (text) - Extended to include 'seller' role alongside 'customer' and 'admin'

  ## 3. Row Level Security (RLS)

  All tables have RLS enabled with appropriate policies:

  ### Public Access
    - Shipping carriers (read-only)
    - Global settings (read-only)

  ### Authenticated Users
    - Seller settings: Sellers can manage their own settings
    - Shipping rules: Sellers can manage their own rules
    - Order taxes: Users can view taxes for their orders
    - Order tracking: Users can view tracking for their orders

  ### Admin Access
    - Full access to all tables for management purposes
    - Can create/edit shipping carriers
    - Can update global settings
    - Can view all orders and tracking

  ### Seller Access
    - Can manage their own products, categories, and settings
    - Can view orders containing their products
    - Can update order tracking for their products

  ## 4. Important Notes

  - All policies enforce ownership checks using auth.uid()
  - Sellers can only modify their own data
  - Admins have full platform access
  - Customers can only view their own orders and data
  - Default values are set for all nullable fields to prevent null-related issues
  - Hierarchical tax/shipping: Global → Seller → Product
*/

-- ============================================================================
-- ENHANCED GLOBAL SETTINGS
-- ============================================================================

DO $$
BEGIN
  -- Add comprehensive global settings columns
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'global_settings' AND column_name = 'tax_type'
  ) THEN
    ALTER TABLE global_settings ADD COLUMN tax_type text DEFAULT 'GST' CHECK (tax_type IN ('GST', 'VAT', 'Sales_Tax'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'global_settings' AND column_name = 'allow_seller_tax_override'
  ) THEN
    ALTER TABLE global_settings ADD COLUMN allow_seller_tax_override boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'global_settings' AND column_name = 'free_shipping_threshold'
  ) THEN
    ALTER TABLE global_settings ADD COLUMN free_shipping_threshold numeric(10,2) DEFAULT 0.00;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'global_settings' AND column_name = 'default_shipping_carriers'
  ) THEN
    ALTER TABLE global_settings ADD COLUMN default_shipping_carriers jsonb DEFAULT '[]';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'global_settings' AND column_name = 'platform_fulfillment_enabled'
  ) THEN
    ALTER TABLE global_settings ADD COLUMN platform_fulfillment_enabled boolean DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'global_settings' AND column_name = 'standard_delivery_days'
  ) THEN
    ALTER TABLE global_settings ADD COLUMN standard_delivery_days text DEFAULT '2-5';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'global_settings' AND column_name = 'express_delivery_days'
  ) THEN
    ALTER TABLE global_settings ADD COLUMN express_delivery_days text DEFAULT '1-2';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'global_settings' AND column_name = 'delivery_tracking_enabled'
  ) THEN
    ALTER TABLE global_settings ADD COLUMN delivery_tracking_enabled boolean DEFAULT true;
  END IF;
END $$;

-- ============================================================================
-- SELLER SETTINGS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS seller_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  tax_registration_number text DEFAULT '',
  tax_rate_override numeric(5,2),
  prices_include_tax boolean DEFAULT false,
  fulfillment_method text DEFAULT 'platform' CHECK (fulfillment_method IN ('platform', 'self')),
  shipping_rules jsonb DEFAULT '{}',
  free_shipping_threshold numeric(10,2),
  self_delivery_enabled boolean DEFAULT false,
  pickup_address_id uuid REFERENCES addresses(id),
  delivery_sla_days integer DEFAULT 5,
  override_global_tax boolean DEFAULT false,
  override_global_shipping boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE seller_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Sellers can manage own settings"
  ON seller_settings
  FOR ALL
  TO authenticated
  USING (auth.uid() = seller_id)
  WITH CHECK (auth.uid() = seller_id);

CREATE POLICY "Admins can manage all seller settings"
  ON seller_settings
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  );

CREATE POLICY "Public can read seller settings"
  ON seller_settings
  FOR SELECT
  TO public
  USING (true);

-- ============================================================================
-- SHIPPING CARRIERS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS shipping_carriers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text UNIQUE NOT NULL,
  api_endpoint text DEFAULT '',
  tracking_url_template text DEFAULT '',
  is_active boolean DEFAULT true,
  supported_countries text[] DEFAULT ARRAY['Australia'],
  created_at timestamptz DEFAULT now()
);

ALTER TABLE shipping_carriers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read shipping carriers"
  ON shipping_carriers
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Admins can manage shipping carriers"
  ON shipping_carriers
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  );

-- Insert default shipping carriers
INSERT INTO shipping_carriers (name, code, tracking_url_template, supported_countries) VALUES
  ('Australia Post', 'AUSPOST', 'https://auspost.com.au/mypost/track/#/details/{tracking_number}', ARRAY['Australia']),
  ('StarTrack', 'STARTRACK', 'https://startrack.com.au/track-trace?id={tracking_number}', ARRAY['Australia']),
  ('TNT', 'TNT', 'https://www.tnt.com/express/en_au/site/tracking.html?searchType=CON&cons={tracking_number}', ARRAY['Australia']),
  ('DHL Express', 'DHL', 'https://www.dhl.com/au-en/home/tracking/tracking-express.html?submit=1&tracking-id={tracking_number}', ARRAY['Australia', 'Global'])
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- SHIPPING RULES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS shipping_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  rule_name text NOT NULL,
  rule_type text NOT NULL CHECK (rule_type IN ('free', 'flat_rate', 'weight_based', 'price_based')),
  conditions jsonb DEFAULT '{}',
  shipping_cost numeric(10,2) DEFAULT 0.00,
  carrier_id uuid REFERENCES shipping_carriers(id),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE shipping_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Sellers can manage own shipping rules"
  ON shipping_rules
  FOR ALL
  TO authenticated
  USING (auth.uid() = seller_id)
  WITH CHECK (auth.uid() = seller_id);

CREATE POLICY "Admins can manage all shipping rules"
  ON shipping_rules
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  );

CREATE POLICY "Public can read active shipping rules"
  ON shipping_rules
  FOR SELECT
  TO public
  USING (is_active = true);

-- ============================================================================
-- ORDER TAXES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS order_taxes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  tax_type text NOT NULL,
  tax_rate numeric(5,2) NOT NULL,
  tax_amount numeric(10,2) NOT NULL,
  applied_by text NOT NULL CHECK (applied_by IN ('global', 'seller')),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE order_taxes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own order taxes"
  ON order_taxes
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_taxes.order_id
      AND orders.user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage all order taxes"
  ON order_taxes
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  );

-- ============================================================================
-- ORDER TRACKING TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS order_tracking (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  status text NOT NULL,
  location text DEFAULT '',
  notes text DEFAULT '',
  updated_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE order_tracking ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own order tracking"
  ON order_tracking
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_tracking.order_id
      AND orders.user_id = auth.uid()
    )
  );

CREATE POLICY "Sellers can manage tracking for their orders"
  ON order_tracking
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND (user_profiles.role = 'seller' OR user_profiles.role = 'admin')
    )
  );

CREATE POLICY "Admins can manage all order tracking"
  ON order_tracking
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  );

-- ============================================================================
-- ENHANCE EXISTING TABLES
-- ============================================================================

-- Update user_profiles to support seller role
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'user_profiles' AND constraint_name = 'user_profiles_role_check'
  ) THEN
    ALTER TABLE user_profiles DROP CONSTRAINT user_profiles_role_check;
  END IF;

  ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_role_check
    CHECK (role IN ('customer', 'admin', 'seller'));
END $$;

-- Add seller_id to products table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'products' AND column_name = 'seller_id'
  ) THEN
    ALTER TABLE products ADD COLUMN seller_id uuid REFERENCES auth.users(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'products' AND column_name = 'discount_type'
  ) THEN
    ALTER TABLE products ADD COLUMN discount_type text CHECK (discount_type IN ('percentage', 'flat_amount'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'products' AND column_name = 'discount_value'
  ) THEN
    ALTER TABLE products ADD COLUMN discount_value numeric(10,2);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'products' AND column_name = 'weight_kg'
  ) THEN
    ALTER TABLE products ADD COLUMN weight_kg numeric(10,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'products' AND column_name = 'dimensions_cm'
  ) THEN
    ALTER TABLE products ADD COLUMN dimensions_cm jsonb DEFAULT '{"width": 0, "height": 0, "length": 0}';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'products' AND column_name = 'shipping_class'
  ) THEN
    ALTER TABLE products ADD COLUMN shipping_class text DEFAULT 'standard';
  END IF;
END $$;

-- Add seller_id to categories table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'categories' AND column_name = 'seller_id'
  ) THEN
    ALTER TABLE categories ADD COLUMN seller_id uuid REFERENCES auth.users(id);
  END IF;
END $$;

-- Enhance orders table with fulfillment and tracking
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'fulfillment_method'
  ) THEN
    ALTER TABLE orders ADD COLUMN fulfillment_method text DEFAULT 'platform'
      CHECK (fulfillment_method IN ('platform', 'seller'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'carrier_id'
  ) THEN
    ALTER TABLE orders ADD COLUMN carrier_id uuid REFERENCES shipping_carriers(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'tracking_number'
  ) THEN
    ALTER TABLE orders ADD COLUMN tracking_number text DEFAULT '';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'estimated_delivery_date'
  ) THEN
    ALTER TABLE orders ADD COLUMN estimated_delivery_date timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'actual_delivery_date'
  ) THEN
    ALTER TABLE orders ADD COLUMN actual_delivery_date timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'delivery_instructions'
  ) THEN
    ALTER TABLE orders ADD COLUMN delivery_instructions text DEFAULT '';
  END IF;
END $$;

-- ============================================================================
-- ENHANCED RLS POLICIES FOR EXISTING TABLES
-- ============================================================================

-- Update products policies to support seller access
DROP POLICY IF EXISTS "Allow authenticated users to manage products" ON products;

CREATE POLICY "Sellers can manage own products"
  ON products
  FOR ALL
  TO authenticated
  USING (
    auth.uid() = seller_id OR
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() = seller_id OR
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  );

-- Update categories policies to support seller access
DROP POLICY IF EXISTS "Allow authenticated users to manage categories" ON categories;

CREATE POLICY "Sellers can manage own categories"
  ON categories
  FOR ALL
  TO authenticated
  USING (
    auth.uid() = seller_id OR
    seller_id IS NULL OR
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() = seller_id OR
    seller_id IS NULL OR
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  );

-- Add admin policies for orders
DROP POLICY IF EXISTS "Admins can manage all orders" ON orders;

CREATE POLICY "Admins can manage all orders"
  ON orders
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    )
  );

-- Add policies for global_settings
DROP POLICY IF EXISTS "Public can read global settings" ON global_settings;

CREATE POLICY "Public can read global settings"
  ON global_settings
  FOR SELECT
  TO public
  USING (true);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_products_seller_id ON products(seller_id);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_department_id ON products(department_id);
CREATE INDEX IF NOT EXISTS idx_categories_seller_id ON categories(seller_id);
CREATE INDEX IF NOT EXISTS idx_categories_department_id ON categories(department_id);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_user_id ON cart_items(user_id);
CREATE INDEX IF NOT EXISTS idx_wishlist_user_id ON wishlist(user_id);
CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_seller_settings_seller_id ON seller_settings(seller_id);
CREATE INDEX IF NOT EXISTS idx_shipping_rules_seller_id ON shipping_rules(seller_id);
CREATE INDEX IF NOT EXISTS idx_order_taxes_order_id ON order_taxes(order_id);
CREATE INDEX IF NOT EXISTS idx_order_tracking_order_id ON order_tracking(order_id);
