-- =============================================================
-- Amparo — Family Health Hub
-- Migration V2: schema completo com soft delete, RLS e funções auxiliares
-- Versão: PRD V2
-- =============================================================

-- ---------------------------------------------------------------
-- EXTENSIONS
-- ---------------------------------------------------------------
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------
-- TRIGGER updated_at (reutilizado em todas as tabelas)
-- ---------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- ---------------------------------------------------------------
-- PROFILES
-- ---------------------------------------------------------------
create table profiles (
  id               uuid primary key references auth.users(id) on delete cascade,
  full_name        text,
  phone            text,
  photo_url        text,
  onboarding_step  int  default 0,
  -- 0=conta criada, 1=família criada, 2=paciente criado, 3=completo
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create trigger profiles_updated_at before update on profiles
  for each row execute function set_updated_at();
alter table profiles enable row level security;
create policy "users can read own profile"   on profiles for select using (id = auth.uid());
create policy "users can insert own profile" on profiles for insert with check (id = auth.uid());
create policy "users can update own profile" on profiles for update using (id = auth.uid());

-- Trigger: cria profile automaticamente ao criar usuário no Auth
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id, full_name)
  values (new.id, new.raw_user_meta_data->>'full_name');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ---------------------------------------------------------------
-- FAMILIES
-- ---------------------------------------------------------------
create table families (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create trigger families_updated_at before update on families
  for each row execute function set_updated_at();
alter table families enable row level security;

-- ---------------------------------------------------------------
-- FAMILY_MEMBERS
-- ---------------------------------------------------------------
create table family_members (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references families(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  role        text not null check (role in ('admin', 'editor', 'viewer', 'caregiver')),
  status      text not null check (status in ('invited', 'active', 'removed')),
  invited_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (family_id, user_id)
);
create index idx_family_members_family_id on family_members(family_id);
create index idx_family_members_user_id   on family_members(user_id);
create trigger family_members_updated_at before update on family_members
  for each row execute function set_updated_at();
alter table family_members enable row level security;

-- ---------------------------------------------------------------
-- INVITATIONS
-- ---------------------------------------------------------------
create table invitations (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references families(id) on delete cascade,
  token       text unique not null default encode(gen_random_bytes(32), 'hex'),
  email       text,
  role        text not null check (role in ('admin', 'editor', 'viewer', 'caregiver')),
  invited_by  uuid references auth.users(id) on delete set null,
  status      text not null check (status in ('pending', 'accepted', 'expired')),
  expires_at  timestamptz not null,
  created_at  timestamptz not null default now()
);
create index idx_invitations_token     on invitations(token);
create index idx_invitations_family_id on invitations(family_id);
alter table invitations enable row level security;

-- ---------------------------------------------------------------
-- PATIENTS
-- ---------------------------------------------------------------
create table patients (
  id                      uuid primary key default gen_random_uuid(),
  family_id               uuid not null references families(id) on delete restrict,
  name                    text not null,
  photo_url               text,
  birth_date              date,
  blood_type              text check (blood_type in ('A+','A-','B+','B-','AB+','AB-','O+','O-','unknown')),
  height                  numeric,
  weight                  numeric,
  -- sem campo de IMC: nunca calcular ou exibir automaticamente
  health_insurance_name   text,
  health_insurance_number text,
  preferred_hospital      text,
  notes                   text,
  created_by              uuid references auth.users(id) on delete set null,
  deleted_at              timestamptz,
  deleted_by              uuid references auth.users(id),
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);
create index idx_patients_family_id  on patients(family_id);
create index idx_patients_deleted_at on patients(deleted_at);
create trigger patients_updated_at before update on patients
  for each row execute function set_updated_at();
alter table patients enable row level security;

-- ---------------------------------------------------------------
-- PATIENT_CONDITIONS
-- ---------------------------------------------------------------
create table patient_conditions (
  id           uuid primary key default gen_random_uuid(),
  patient_id   uuid not null references patients(id) on delete cascade,
  name         text not null,
  description  text,
  diagnosed_at date,
  status       text check (status in ('active', 'inactive', 'unknown')),
  deleted_at   timestamptz,
  deleted_by   uuid references auth.users(id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index idx_patient_conditions_patient_id on patient_conditions(patient_id);
create index idx_patient_conditions_deleted_at on patient_conditions(deleted_at);
alter table patient_conditions enable row level security;

-- ---------------------------------------------------------------
-- PATIENT_ALLERGIES
-- ---------------------------------------------------------------
create table patient_allergies (
  id         uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  allergy    text not null,
  severity   text check (severity in ('low', 'medium', 'high', 'critical')),
  notes      text,
  deleted_at timestamptz,
  deleted_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create index idx_patient_allergies_patient_id on patient_allergies(patient_id);
create index idx_patient_allergies_deleted_at on patient_allergies(deleted_at);
alter table patient_allergies enable row level security;

-- ---------------------------------------------------------------
-- EMERGENCY_CONTACTS
-- ---------------------------------------------------------------
create table emergency_contacts (
  id           uuid primary key default gen_random_uuid(),
  patient_id   uuid not null references patients(id) on delete cascade,
  name         text not null,
  relationship text,
  phone        text,
  email        text,
  priority     int  default 1,
  -- reordenação via botões ↑↓, nunca drag-and-drop
  deleted_at   timestamptz,
  deleted_by   uuid references auth.users(id),
  created_at   timestamptz not null default now()
);
create index idx_emergency_contacts_patient_id on emergency_contacts(patient_id);
create index idx_emergency_contacts_deleted_at on emergency_contacts(deleted_at);
alter table emergency_contacts enable row level security;

-- ---------------------------------------------------------------
-- MEDICATIONS
-- ---------------------------------------------------------------
create table medications (
  id           uuid primary key default gen_random_uuid(),
  patient_id   uuid not null references patients(id) on delete cascade,
  name         text not null,
  generic_name text,
  dosage       text,
  frequency    text,
  schedule     jsonb,
  -- formato obrigatório: { "times": ["08:00", "14:00"] } — nunca usar outro formato ou chave
  start_date   date,
  end_date     date,
  prescribed_by text,
  status       text not null check (status in ('active', 'paused', 'ended')),
  notes        text,
  file_path    text,
  -- path interno Supabase Storage; URL assinada gerada na aplicação, nunca armazenar file_url
  deleted_at   timestamptz,
  deleted_by   uuid references auth.users(id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index idx_medications_patient_id on medications(patient_id);
create index idx_medications_status     on medications(status);
create index idx_medications_deleted_at on medications(deleted_at);
create trigger medications_updated_at before update on medications
  for each row execute function set_updated_at();
alter table medications enable row level security;

-- ---------------------------------------------------------------
-- MEDICATION_LOGS (P1 — tabela criada agora, funcionalidade em P1)
-- ---------------------------------------------------------------
create table medication_logs (
  id            uuid primary key default gen_random_uuid(),
  medication_id uuid not null references medications(id) on delete cascade,
  -- sem patient_id: obtido via medications.patient_id
  taken_at      timestamptz,
  scheduled_for timestamptz,
  -- quando deveria ter sido tomado (base para calcular 'missed')
  status        text check (status in ('taken', 'missed', 'skipped')),
  logged_by     uuid references auth.users(id) on delete set null,
  notes         text,
  created_at    timestamptz not null default now()
);
create index idx_medication_logs_medication_id on medication_logs(medication_id);
create index idx_medication_logs_scheduled_for on medication_logs(scheduled_for);
alter table medication_logs enable row level security;

-- ---------------------------------------------------------------
-- APPOINTMENTS
-- ---------------------------------------------------------------
create table appointments (
  id                    uuid primary key default gen_random_uuid(),
  patient_id            uuid not null references patients(id) on delete cascade,
  parent_appointment_id uuid references appointments(id) on delete set null,
  -- retorno vinculado à consulta original; profundidade máxima: 1 nível
  type                  text not null check (type in (
    'consultation', 'exam', 'return', 'procedure', 'therapy', 'vaccine', 'other'
  )),
  title                 text not null,
  scheduled_at          timestamptz not null,
  location              text,
  address               text,
  map_url               text,
  doctor_name           text,
  specialty             text,
  responsible_user_id   uuid references auth.users(id) on delete set null,
  status                text not null check (status in (
    'scheduled', 'confirmed', 'done', 'cancelled', 'rescheduled'
  )),
  notes                 text,
  deleted_at            timestamptz,
  deleted_by            uuid references auth.users(id),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index idx_appointments_patient_id   on appointments(patient_id);
create index idx_appointments_scheduled_at on appointments(scheduled_at);
create index idx_appointments_status       on appointments(status);
create index idx_appointments_deleted_at   on appointments(deleted_at);
create trigger appointments_updated_at before update on appointments
  for each row execute function set_updated_at();
alter table appointments enable row level security;

-- ---------------------------------------------------------------
-- CLINICAL_EVENTS
-- ---------------------------------------------------------------
create table clinical_events (
  id             uuid primary key default gen_random_uuid(),
  patient_id     uuid not null references patients(id) on delete cascade,
  appointment_id uuid references appointments(id) on delete set null,
  -- preenchido quando evento gerado automaticamente ao marcar consulta como realizada;
  -- evita duplicatas em clique duplo
  event_date     date not null,
  type           text not null check (type in (
    'consultation', 'exam', 'hospitalization', 'surgery', 'symptom',
    'fall_accident', 'medication_change', 'diagnosis', 'return',
    'crisis', 'vaccine', 'family_note'
  )),
  title          text not null,
  description    text,
  severity       text check (severity in ('low', 'medium', 'high', 'critical')),
  created_by     uuid references auth.users(id) on delete set null,
  deleted_at     timestamptz,
  deleted_by     uuid references auth.users(id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index idx_clinical_events_patient_id   on clinical_events(patient_id);
create index idx_clinical_events_event_date   on clinical_events(event_date);
create index idx_clinical_events_deleted_at   on clinical_events(deleted_at);
create trigger clinical_events_updated_at before update on clinical_events
  for each row execute function set_updated_at();
alter table clinical_events enable row level security;

-- ---------------------------------------------------------------
-- DOCUMENTS
-- ---------------------------------------------------------------
create table documents (
  id                uuid primary key default gen_random_uuid(),
  patient_id        uuid not null references patients(id) on delete cascade,
  uploaded_by       uuid references auth.users(id) on delete set null,
  title             text not null,
  type              text not null check (type in (
    'prescription', 'exam', 'report', 'medical_request', 'insurance_card',
    'id_document', 'discharge', 'vaccine', 'medication_photo', 'other'
  )),
  file_path         text not null,
  -- path interno Supabase Storage; URL assinada gerada na aplicação
  file_mime_type    text,
  file_size_bytes   bigint,
  document_date     date,
  expiry_date       date,
  institution       text,
  doctor_name       text,
  clinical_event_id uuid references clinical_events(id) on delete set null,
  tags              text[],
  ocr_text          text,    -- P1: preenchido por OCR automático
  ai_summary        text,    -- P1: resumo gerado por IA
  search_vector     tsvector generated always as (
    to_tsvector('portuguese',
      coalesce(title,'')        || ' ' ||
      coalesce(doctor_name,'')  || ' ' ||
      coalesce(institution,'')  || ' ' ||
      coalesce(ocr_text,'')
    )
  ) stored,
  -- coluna gerada; usar search_vector nas queries, nunca recalcular tsvector inline
  deleted_at        timestamptz,
  deleted_by        uuid references auth.users(id),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index idx_documents_patient_id on documents(patient_id);
create index idx_documents_type       on documents(type);
create index idx_documents_deleted_at on documents(deleted_at);
create index idx_documents_fts        on documents using gin(search_vector);
-- índice GIN na coluna gerada — usar em todas as buscas de documentos

create trigger documents_updated_at before update on documents
  for each row execute function set_updated_at();
alter table documents enable row level security;

-- ---------------------------------------------------------------
-- EMERGENCY_LINKS
-- ---------------------------------------------------------------
create table emergency_links (
  id           uuid primary key default gen_random_uuid(),
  patient_id   uuid not null references patients(id) on delete cascade,
  token        text unique not null default encode(gen_random_bytes(32), 'hex'),
  expires_at   timestamptz,
  is_active    boolean not null default true,
  access_count int     not null default 0,
  -- access_count atualizado APENAS via Edge Function com service_role
  created_by   uuid references auth.users(id) on delete set null,
  created_at   timestamptz not null default now()
);
create index idx_emergency_links_token      on emergency_links(token);
create index idx_emergency_links_patient_id on emergency_links(patient_id);
alter table emergency_links enable row level security;

-- ---------------------------------------------------------------
-- ACCESS_LOGS
-- ---------------------------------------------------------------
create table access_logs (
  id                uuid primary key default gen_random_uuid(),
  family_id         uuid references families(id) on delete set null,
  patient_id        uuid references patients(id) on delete set null,
  user_id           uuid references auth.users(id) on delete set null,
  -- nullable: acessos anônimos via link de emergência
  emergency_link_id uuid references emergency_links(id) on delete set null,
  action            text not null,
  resource_type     text,
  resource_id       uuid,
  ip_address        text,
  -- dado pessoal LGPD: reter por no máximo 90 dias
  user_agent        text,
  created_at        timestamptz not null default now()
);
create index idx_access_logs_patient_id on access_logs(patient_id);
create index idx_access_logs_family_id  on access_logs(family_id);
create index idx_access_logs_created_at on access_logs(created_at);
-- índice em created_at obrigatório para purge LGPD:
-- delete from access_logs where created_at < now() - interval '90 days'

alter table access_logs enable row level security;

-- =============================================================
-- FUNÇÕES AUXILIARES DE RLS
-- =============================================================

-- Verifica se o usuário corrente é membro ativo da família
create or replace function is_family_member(fid uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from family_members
    where family_id = fid
      and user_id   = auth.uid()
      and status    = 'active'
  );
$$;

-- Verifica se o usuário corrente tem um dos papéis especificados na família
create or replace function has_family_role(fid uuid, roles text[])
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from family_members
    where family_id = fid
      and user_id   = auth.uid()
      and status    = 'active'
      and role      = any(roles)
  );
$$;

-- Retorna famílias onde o usuário é o ÚNICO admin (para bloquear exclusão de conta)
create or replace function get_solo_admin_families(p_user_id uuid)
returns table(family_id uuid)
language sql
security definer
stable
as $$
  select fm.family_id
  from family_members fm
  where fm.user_id = p_user_id
    and fm.role    = 'admin'
    and fm.status  = 'active'
    and fm.family_id in (
      select family_id
      from family_members
      where role   = 'admin'
        and status = 'active'
      group by family_id
      having count(*) = 1
    )
$$;

-- =============================================================
-- POLÍTICAS RLS
-- =============================================================

-- ── FAMILIES ──────────────────────────────────────────────────
create policy "members can read families" on families
  for select using (is_family_member(id));
create policy "authenticated can insert families" on families
  for insert with check (auth.uid() is not null);
create policy "admins can update families" on families
  for update using (has_family_role(id, array['admin']));

-- ── FAMILY_MEMBERS ────────────────────────────────────────────
create policy "members can read family_members" on family_members
  for select using (is_family_member(family_id));
create policy "admins can manage family_members" on family_members
  for all using (has_family_role(family_id, array['admin']));

-- ── INVITATIONS ───────────────────────────────────────────────
create policy "admins can manage invitations" on invitations
  for all using (has_family_role(family_id, array['admin']));
create policy "public can read valid invitations" on invitations
  for select using (status = 'pending' and expires_at > now());

-- ── PATIENTS ──────────────────────────────────────────────────
create policy "members can read patients" on patients
  for select using (is_family_member(family_id) and deleted_at is null);
create policy "editors can insert patients" on patients
  for insert with check (has_family_role(family_id, array['admin','editor']));
create policy "editors can update patients" on patients
  for update using (has_family_role(family_id, array['admin','editor']) and deleted_at is null);

-- ── PATIENT_CONDITIONS ────────────────────────────────────────
create policy "members can read patient_conditions" on patient_conditions
  for select using (
    patient_id in (select p.id from patients p where is_family_member(p.family_id))
    and deleted_at is null
  );
create policy "editors can insert patient_conditions" on patient_conditions
  for insert with check (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
  );
create policy "editors can update patient_conditions" on patient_conditions
  for update using (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
    and deleted_at is null
  );

-- ── PATIENT_ALLERGIES ─────────────────────────────────────────
create policy "members can read patient_allergies" on patient_allergies
  for select using (
    patient_id in (select p.id from patients p where is_family_member(p.family_id))
    and deleted_at is null
  );
create policy "editors can insert patient_allergies" on patient_allergies
  for insert with check (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
  );
create policy "editors can update patient_allergies" on patient_allergies
  for update using (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
    and deleted_at is null
  );

-- ── EMERGENCY_CONTACTS ────────────────────────────────────────
create policy "members can read emergency_contacts" on emergency_contacts
  for select using (
    patient_id in (select p.id from patients p where is_family_member(p.family_id))
    and deleted_at is null
  );
create policy "editors can insert emergency_contacts" on emergency_contacts
  for insert with check (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
  );
create policy "editors can update emergency_contacts" on emergency_contacts
  for update using (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
    and deleted_at is null
  );

-- ── MEDICATIONS ───────────────────────────────────────────────
create policy "members can read medications" on medications
  for select using (
    patient_id in (select p.id from patients p where is_family_member(p.family_id))
    and deleted_at is null
  );
create policy "editors can insert medications" on medications
  for insert with check (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
  );
create policy "editors can update medications" on medications
  for update using (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
    and deleted_at is null
  );

-- ── MEDICATION_LOGS ───────────────────────────────────────────
create policy "members can read medication_logs" on medication_logs
  for select using (
    medication_id in (
      select m.id from medications m
      join patients p on p.id = m.patient_id
      where is_family_member(p.family_id)
        and m.deleted_at is null
    )
  );
create policy "members can insert medication_logs" on medication_logs
  for insert with check (
    medication_id in (
      select m.id from medications m
      join patients p on p.id = m.patient_id
      where is_family_member(p.family_id)
    )
  );

-- ── APPOINTMENTS ──────────────────────────────────────────────
create policy "members can read appointments" on appointments
  for select using (
    patient_id in (select p.id from patients p where is_family_member(p.family_id))
    and deleted_at is null
  );
create policy "editors can insert appointments" on appointments
  for insert with check (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
  );
create policy "editors can update appointments" on appointments
  for update using (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
    and deleted_at is null
  );

-- ── CLINICAL_EVENTS ───────────────────────────────────────────
create policy "members can read clinical_events" on clinical_events
  for select using (
    patient_id in (select p.id from patients p where is_family_member(p.family_id))
    and deleted_at is null
  );
create policy "editors can insert clinical_events" on clinical_events
  for insert with check (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
  );
create policy "editors can update clinical_events" on clinical_events
  for update using (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
    and deleted_at is null
  );

-- ── DOCUMENTS ─────────────────────────────────────────────────
create policy "members can read documents" on documents
  for select using (
    patient_id in (select p.id from patients p where is_family_member(p.family_id))
    and deleted_at is null
  );
create policy "editors can insert documents" on documents
  for insert with check (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
  );
create policy "editors can update documents" on documents
  for update using (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
    and deleted_at is null
  );

-- ── EMERGENCY_LINKS ───────────────────────────────────────────
create policy "members can manage emergency_links" on emergency_links
  for all using (
    patient_id in (
      select p.id from patients p
      join family_members fm on fm.family_id = p.family_id
      where fm.user_id = auth.uid() and fm.status = 'active'
    )
  );
-- Leitura pública via token: tratada na Edge Function com service_role

-- ── ACCESS_LOGS ───────────────────────────────────────────────
-- Inserção apenas via Edge Function com service_role (sem policy de insert para authenticated)
create policy "admins can read access_logs" on access_logs
  for select using (
    family_id in (
      select family_id from family_members
      where user_id = auth.uid() and role = 'admin' and status = 'active'
    )
  );

-- =============================================================
-- STORAGE — bucket medical-documents
-- Executar no SQL Editor do Supabase APÓS criar o bucket como PRIVADO
-- =============================================================

-- create policy "members can access patient files" on storage.objects
--   for all using (
--     bucket_id = 'medical-documents'
--     and (storage.foldername(name))[2] in (
--       select p.id::text from patients p
--       join family_members fm on fm.family_id = p.family_id
--       where fm.user_id = auth.uid() and fm.status = 'active'
--     )
--   );
--
-- ⚠ Convenção de path obrigatória: patients/{patient_id}/.../{filename}
-- O [2] acima extrai patient_id da segunda pasta do path.
-- Criar o bucket como PRIVADO antes de aplicar esta política.
-- O bucket deve ser nomeado exatamente: medical-documents
