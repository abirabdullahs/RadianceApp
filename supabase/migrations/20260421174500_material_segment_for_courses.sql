-- Material segment:
-- Admin creates a material under a course and marks enrolled students (checked).

CREATE TABLE IF NOT EXISTS public.materials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.material_assignments (
  material_id UUID NOT NULL REFERENCES public.materials(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  is_checked BOOLEAN NOT NULL DEFAULT false,
  checked_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (material_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_materials_course_created_at
  ON public.materials(course_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_material_assignments_student
  ON public.material_assignments(student_id);

ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.material_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS materials_select ON public.materials;
CREATE POLICY materials_select
ON public.materials
FOR SELECT
USING (
  public.is_admin()
  OR EXISTS (
    SELECT 1
    FROM public.enrollments e
    WHERE e.course_id = materials.course_id
      AND e.student_id = auth.uid()
      AND e.status = 'active'
  )
);

DROP POLICY IF EXISTS materials_insert_admin ON public.materials;
CREATE POLICY materials_insert_admin
ON public.materials
FOR INSERT
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS materials_update_admin ON public.materials;
CREATE POLICY materials_update_admin
ON public.materials
FOR UPDATE
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS materials_delete_admin ON public.materials;
CREATE POLICY materials_delete_admin
ON public.materials
FOR DELETE
USING (public.is_admin());

DROP POLICY IF EXISTS material_assignments_select ON public.material_assignments;
CREATE POLICY material_assignments_select
ON public.material_assignments
FOR SELECT
USING (public.is_admin() OR student_id = auth.uid());

DROP POLICY IF EXISTS material_assignments_insert_admin ON public.material_assignments;
CREATE POLICY material_assignments_insert_admin
ON public.material_assignments
FOR INSERT
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS material_assignments_update_admin ON public.material_assignments;
CREATE POLICY material_assignments_update_admin
ON public.material_assignments
FOR UPDATE
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS material_assignments_delete_admin ON public.material_assignments;
CREATE POLICY material_assignments_delete_admin
ON public.material_assignments
FOR DELETE
USING (public.is_admin());
