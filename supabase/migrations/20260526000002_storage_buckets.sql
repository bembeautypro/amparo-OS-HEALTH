-- =============================================================
-- Amparo — Storage buckets e políticas RLS
-- =============================================================
-- Três buckets privados:
--   patient-photos   → foto de perfil dos familiares cuidados
--   medication-photos → foto da embalagem/receita do medicamento
--   documents        → PDFs, exames, receitas, laudos
-- Acesso público desligado por padrão; signed URLs geradas na app.
-- =============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'patient-photos',
    'patient-photos',
    false,
    5242880, -- 5 MB
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'medication-photos',
    'medication-photos',
    false,
    5242880, -- 5 MB
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'documents',
    'documents',
    false,
    52428800, -- 50 MB
    array['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/tiff']
  );

-- ---------------------------------------------------------------
-- RLS para Storage
-- Convenção de path:  {family_id}/{patient_id}/{filename}
-- O family_id no path permite validar permissão sem JOIN extra.
-- ---------------------------------------------------------------

-- patient-photos
create policy "patient_photos_select"
  on storage.objects for select
  using (
    bucket_id = 'patient-photos'
    and (storage.foldername(name))[1] in (
      select family_id::text from family_members
      where user_id = auth.uid() and status = 'active'
    )
  );

create policy "patient_photos_insert"
  on storage.objects for insert
  with check (
    bucket_id = 'patient-photos'
    and (storage.foldername(name))[1] in (
      select family_id::text from family_members
      where user_id = auth.uid() and status = 'active'
        and role in ('admin', 'editor')
    )
  );

create policy "patient_photos_update"
  on storage.objects for update
  using (
    bucket_id = 'patient-photos'
    and (storage.foldername(name))[1] in (
      select family_id::text from family_members
      where user_id = auth.uid() and status = 'active'
        and role in ('admin', 'editor')
    )
  );

create policy "patient_photos_delete"
  on storage.objects for delete
  using (
    bucket_id = 'patient-photos'
    and (storage.foldername(name))[1] in (
      select family_id::text from family_members
      where user_id = auth.uid() and status = 'active'
        and role = 'admin'
    )
  );

-- medication-photos
create policy "medication_photos_select"
  on storage.objects for select
  using (
    bucket_id = 'medication-photos'
    and (storage.foldername(name))[1] in (
      select family_id::text from family_members
      where user_id = auth.uid() and status = 'active'
    )
  );

create policy "medication_photos_insert"
  on storage.objects for insert
  with check (
    bucket_id = 'medication-photos'
    and (storage.foldername(name))[1] in (
      select family_id::text from family_members
      where user_id = auth.uid() and status = 'active'
        and role in ('admin', 'editor')
    )
  );

create policy "medication_photos_update"
  on storage.objects for update
  using (
    bucket_id = 'medication-photos'
    and (storage.foldername(name))[1] in (
      select family_id::text from family_members
      where user_id = auth.uid() and status = 'active'
        and role in ('admin', 'editor')
    )
  );

create policy "medication_photos_delete"
  on storage.objects for delete
  using (
    bucket_id = 'medication-photos'
    and (storage.foldername(name))[1] in (
      select family_id::text from family_members
      where user_id = auth.uid() and status = 'active'
        and role = 'admin'
    )
  );

-- documents
create policy "documents_storage_select"
  on storage.objects for select
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] in (
      select family_id::text from family_members
      where user_id = auth.uid() and status = 'active'
    )
  );

create policy "documents_storage_insert"
  on storage.objects for insert
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] in (
      select family_id::text from family_members
      where user_id = auth.uid() and status = 'active'
        and role in ('admin', 'editor')
    )
  );

create policy "documents_storage_update"
  on storage.objects for update
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] in (
      select family_id::text from family_members
      where user_id = auth.uid() and status = 'active'
        and role in ('admin', 'editor')
    )
  );

create policy "documents_storage_delete"
  on storage.objects for delete
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] in (
      select family_id::text from family_members
      where user_id = auth.uid() and status = 'active'
        and role = 'admin'
    )
  );
