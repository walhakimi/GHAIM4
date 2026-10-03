-- =========================================================================
-- إعداد جداول قاعدة بيانات دار غيم للعطور على Supabase (Ghaim Perfumes)
-- انسخ هذا الكود والصقه في SQL Editor داخل لوحة تحكم Supabase واضغط Run
-- =========================================================================

-- 1. جدول الملفات الشخصية للمستخدمين (Profiles)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT,
  full_name TEXT,
  phone TEXT,
  city TEXT DEFAULT 'الرياض',
  district TEXT,
  address TEXT,
  membership_tier TEXT DEFAULT 'VIP',
  avatar_url TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- تفعيل حماية الصفوف (Row Level Security) لجدول profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- سياسات الوصول لجدول profiles
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles;
CREATE POLICY "Users can view own profile." 
  ON public.profiles FOR SELECT 
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert their own profile." ON public.profiles;
CREATE POLICY "Users can insert their own profile." 
  ON public.profiles FOR INSERT 
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile." ON public.profiles;
CREATE POLICY "Users can update own profile." 
  ON public.profiles FOR UPDATE 
  USING (auth.uid() = id);

-- 2. جدول الطلبات (Orders)
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE SET NULL,
  order_number TEXT NOT NULL,
  total NUMERIC NOT NULL,
  subtotal NUMERIC NOT NULL,
  discount NUMERIC DEFAULT 0,
  discount_code TEXT,
  shipping NUMERIC DEFAULT 0,
  tax NUMERIC DEFAULT 0,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  customer_info JSONB NOT NULL DEFAULT '{}'::jsonb,
  estimated_delivery TEXT,
  status TEXT DEFAULT 'confirmed',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- تفعيل حماية الصفوف لجدول orders
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- سياسات الوصول لجدول orders
DROP POLICY IF EXISTS "Users can view own orders." ON public.orders;
CREATE POLICY "Users can view own orders." 
  ON public.orders FOR SELECT 
  USING (auth.uid() = user_id OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Anyone can insert orders." ON public.orders;
CREATE POLICY "Anyone can insert orders." 
  ON public.orders FOR INSERT 
  WITH CHECK (true);

-- 3. دالة و Trigger لإنشاء ملف شخصي تلقائياً عند تسجيل أي مستخدم جديد
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, phone)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'phone'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
