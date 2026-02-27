-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================
-- USERS TABLE
-- ============================================================
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  bio TEXT DEFAULT '',
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_username_trgm ON public.users USING gin (username gin_trgm_ops);
CREATE INDEX idx_users_display_name_trgm ON public.users USING gin (display_name gin_trgm_ops);

-- ============================================================
-- POSTS TABLE
-- ============================================================
CREATE TABLE public.posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) <= 280),
  media_url TEXT,
  reply_to_id UUID REFERENCES public.posts(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  likes_count INTEGER NOT NULL DEFAULT 0,
  reposts_count INTEGER NOT NULL DEFAULT 0,
  replies_count INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_posts_user_id ON public.posts(user_id);
CREATE INDEX idx_posts_created_at ON public.posts(created_at DESC);
CREATE INDEX idx_posts_reply_to ON public.posts(reply_to_id) WHERE reply_to_id IS NOT NULL;
CREATE INDEX idx_posts_content_trgm ON public.posts USING gin (content gin_trgm_ops);

-- ============================================================
-- LIKES TABLE
-- ============================================================
CREATE TABLE public.likes (
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);

CREATE INDEX idx_likes_post_id ON public.likes(post_id);

-- ============================================================
-- REPOSTS TABLE
-- ============================================================
CREATE TABLE public.reposts (
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);

CREATE INDEX idx_reposts_post_id ON public.reposts(post_id);
CREATE INDEX idx_reposts_user_id_created ON public.reposts(user_id, created_at DESC);

-- ============================================================
-- FOLLOWERS TABLE
-- ============================================================
CREATE TABLE public.followers (
  follower_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, following_id),
  CHECK (follower_id != following_id)
);

CREATE INDEX idx_followers_following_id ON public.followers(following_id);

-- ============================================================
-- NOTIFICATIONS TABLE
-- ============================================================
CREATE TYPE public.notification_type AS ENUM ('like', 'repost', 'reply', 'follow');

CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type public.notification_type NOT NULL,
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_user_id ON public.notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON public.notifications(user_id) WHERE is_read = false;

-- ============================================================
-- TRIGGER FUNCTIONS: COUNTERS
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_like_change
  AFTER INSERT OR DELETE ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.handle_likes_count();

CREATE OR REPLACE FUNCTION public.handle_reposts_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.posts SET reposts_count = reposts_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.posts SET reposts_count = GREATEST(reposts_count - 1, 0) WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_repost_change
  AFTER INSERT OR DELETE ON public.reposts
  FOR EACH ROW EXECUTE FUNCTION public.handle_reposts_count();

CREATE OR REPLACE FUNCTION public.handle_replies_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.reply_to_id IS NOT NULL THEN
    UPDATE public.posts SET replies_count = replies_count + 1 WHERE id = NEW.reply_to_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' AND OLD.reply_to_id IS NOT NULL THEN
    UPDATE public.posts SET replies_count = GREATEST(replies_count - 1, 0) WHERE id = OLD.reply_to_id;
    RETURN OLD;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_reply_change
  AFTER INSERT OR DELETE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.handle_replies_count();

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_user_updated
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- TRIGGER FUNCTIONS: NOTIFICATIONS
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_like_notification()
RETURNS TRIGGER AS $$
DECLARE
  post_owner UUID;
BEGIN
  SELECT user_id INTO post_owner FROM public.posts WHERE id = NEW.post_id;
  IF post_owner IS NOT NULL AND post_owner != NEW.user_id THEN
    INSERT INTO public.notifications (user_id, actor_id, type, post_id)
    VALUES (post_owner, NEW.user_id, 'like', NEW.post_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_like_notification
  AFTER INSERT ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_like_notification();

CREATE OR REPLACE FUNCTION public.handle_new_repost_notification()
RETURNS TRIGGER AS $$
DECLARE
  post_owner UUID;
BEGIN
  SELECT user_id INTO post_owner FROM public.posts WHERE id = NEW.post_id;
  IF post_owner IS NOT NULL AND post_owner != NEW.user_id THEN
    INSERT INTO public.notifications (user_id, actor_id, type, post_id)
    VALUES (post_owner, NEW.user_id, 'repost', NEW.post_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_repost_notification
  AFTER INSERT ON public.reposts
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_repost_notification();

CREATE OR REPLACE FUNCTION public.handle_new_reply_notification()
RETURNS TRIGGER AS $$
DECLARE
  parent_owner UUID;
BEGIN
  IF NEW.reply_to_id IS NOT NULL THEN
    SELECT user_id INTO parent_owner FROM public.posts WHERE id = NEW.reply_to_id;
    IF parent_owner IS NOT NULL AND parent_owner != NEW.user_id THEN
      INSERT INTO public.notifications (user_id, actor_id, type, post_id)
      VALUES (parent_owner, NEW.user_id, 'reply', NEW.id);
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_reply_notification
  AFTER INSERT ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_reply_notification();

CREATE OR REPLACE FUNCTION public.handle_new_follow_notification()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.notifications (user_id, actor_id, type)
  VALUES (NEW.following_id, NEW.follower_id, 'follow');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_follow_notification
  AFTER INSERT ON public.followers
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_follow_notification();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reposts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.followers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- USERS policies
CREATE POLICY "Users are viewable by everyone"
  ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile"
  ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile"
  ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

-- POSTS policies
CREATE POLICY "Posts are viewable by everyone"
  ON public.posts FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create posts"
  ON public.posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own posts"
  ON public.posts FOR DELETE USING (auth.uid() = user_id);

-- LIKES policies
CREATE POLICY "Likes are viewable by everyone"
  ON public.likes FOR SELECT USING (true);
CREATE POLICY "Users can like posts"
  ON public.likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike posts"
  ON public.likes FOR DELETE USING (auth.uid() = user_id);

-- REPOSTS policies
CREATE POLICY "Reposts are viewable by everyone"
  ON public.reposts FOR SELECT USING (true);
CREATE POLICY "Users can repost"
  ON public.reposts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove repost"
  ON public.reposts FOR DELETE USING (auth.uid() = user_id);

-- FOLLOWERS policies
CREATE POLICY "Followers are viewable by everyone"
  ON public.followers FOR SELECT USING (true);
CREATE POLICY "Users can follow others"
  ON public.followers FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "Users can unfollow"
  ON public.followers FOR DELETE USING (auth.uid() = follower_id);

-- NOTIFICATIONS policies
CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- ============================================================
-- REALTIME
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);
INSERT INTO storage.buckets (id, name, public) VALUES ('post-media', 'post-media', true);

-- Storage policies: avatars
CREATE POLICY "Avatar images are publicly accessible"
  ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Users can upload their own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can update their own avatar"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can delete their own avatar"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Storage policies: post-media
CREATE POLICY "Post media is publicly accessible"
  ON storage.objects FOR SELECT USING (bucket_id = 'post-media');
CREATE POLICY "Users can upload post media"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'post-media' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can delete own post media"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'post-media' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ============================================================
-- FEED FUNCTION (RPC)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_feed(
  requesting_user_id UUID,
  cursor_timestamp TIMESTAMPTZ DEFAULT now(),
  page_size INTEGER DEFAULT 20
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  content TEXT,
  media_url TEXT,
  reply_to_id UUID,
  created_at TIMESTAMPTZ,
  likes_count INTEGER,
  reposts_count INTEGER,
  replies_count INTEGER,
  username TEXT,
  display_name TEXT,
  avatar_url TEXT,
  is_liked BOOLEAN,
  is_reposted BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.user_id,
    p.content,
    p.media_url,
    p.reply_to_id,
    p.created_at,
    p.likes_count,
    p.reposts_count,
    p.replies_count,
    u.username,
    u.display_name,
    u.avatar_url,
    EXISTS(SELECT 1 FROM public.likes l WHERE l.post_id = p.id AND l.user_id = requesting_user_id) AS is_liked,
    EXISTS(SELECT 1 FROM public.reposts r WHERE r.post_id = p.id AND r.user_id = requesting_user_id) AS is_reposted
  FROM public.posts p
  JOIN public.users u ON p.user_id = u.id
  WHERE p.reply_to_id IS NULL
    AND p.created_at < cursor_timestamp
    AND (
      p.user_id = requesting_user_id
      OR p.user_id IN (SELECT following_id FROM public.followers WHERE follower_id = requesting_user_id)
    )
  ORDER BY p.created_at DESC
  LIMIT page_size;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
