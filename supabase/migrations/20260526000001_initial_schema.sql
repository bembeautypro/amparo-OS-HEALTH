-- =============================================================
-- Amparo — Family Health Hub
-- Migration: initial schema
-- =============================================================

-- ---------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------
-- ENUM types
-- ---------------------------------------------------------------
-- FIX: usar ENUMs em vez de text+CHECK para tipos fixos garante
-- integridade, autocompletar nas ferramentas e renaming controlado.

create type family_member_role   as enum ('admin', 'editor', 'viewer', 'caregiver', 'doctor');
create type family_member_status as enum ('invited', 'active', 'removed');
create type blood_type_enum      as enum ('A+','A-','B+','B-','AB+','AB-','O+','O-','unknown');
create type condition_status     as enum ('active', 'inactive', 'unknown');
create type allergy_severity     as enum ('low', 'medium', 'high', 'critical');
create type medication_status    as enum ('active', 'paused', 'ended');
create type medication_log_status as enum ('taken', 'missed', 'skipped');
create type appointment_type     as enum ('consultation', 'exam', 'return', 'procedure', 'therapy', 'vaccine', 'other');
create type appointment_status   as enum ('scheduled', 'confirmed', 'done', 'cancelled', 'rescheduled');
create type clinical_event_type  as enum (
  'consultation', 'exam', 'hospitalization', 'surgery', 'symptom',
  'fall_accident', 'medication_change', 'diagnosis', 'return',
  'crisis', 'vaccine', 'family_note', 'other'
);
create type event_severity       as enum ('low', 'medium', 'high', 'critical');
create type document_type        as enum (
  'prescription', 'exam', 'report', 'medical_request',
  'insurance_card', 'id_document', 'discharge', 'vaccine', 'other'
);
create type invitation_status    as enum ('pending', 'accepted', 'expired', 'cancelled');

-- ---------------------------------------------------------------
-- profiles
-- FIX: tabela nova — auth.users não armazena nome, foto, telefone.
-- Necessária para exibir "quem fez alteração" nos logs.
-- ---------------------------------------------------------------
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text,
  phone       text,
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- families
-- ---------------------------------------------------------------
create table families (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_by  uuid not null references auth.users(id) on delete restrict,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- family_members
-- FIX: adicionado unique(family_id, user_id), updated_at, invited_by
-- ---------------------------------------------------------------
create table family_members (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references families(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  role        family_member_role not null default 'viewer',
  status      family_member_status not null default 'invited',
  invited_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  unique (family_id, user_id)
);

-- ---------------------------------------------------------------
-- invitations
-- FIX: tabela nova — rastreia convites por email antes do usuário
-- criar conta, necessário para o fluxo de onboarding.
-- ---------------------------------------------------------------
create table invitations (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references families(id) on delete cascade,
  email       text not null,
  role        family_member_role not null default 'viewer',
  token       text not null unique default encode(gen_random_bytes(32), 'hex'),
  status      invitation_status not null default 'pending',
  invited_by  uuid not null references auth.users(id) on delete cascade,
  expires_at  timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- patients
-- FIX: blood_type com enum, adicionado created_by, primary_doctor
-- ---------------------------------------------------------------
create table patients (
  id                      uuid primary key default gen_random_uuid(),
  family_id               uuid not null references families(id) on delete cascade,
  created_by              uuid not null references auth.users(id) on delete restrict,
  name                    text not null,
  -- FIX: armazenar path do Storage, não URL direta (RLS + signed URLs)
  photo_path              text,
  birth_date              date,
  -- FIX: enum em vez de text livre
  blood_type              blood_type_enum,
  height_cm               numeric(5,2),
  weight_kg               numeric(5,2),
  health_insurance_name   text,
  health_insurance_number text,
  preferred_hospital      text,
  primary_doctor_name     text,
  notes                   text,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- patient_conditions
-- FIX: adicionado on delete cascade, updated_at, created_by, diagnosed_at
-- ---------------------------------------------------------------
create table patient_conditions (
  id            uuid primary key default gen_random_uuid(),
  patient_id    uuid not null references patients(id) on delete cascade,
  created_by    uuid not null references auth.users(id) on delete restrict,
  name          text not null,
  description   text,
  status        condition_status not null default 'active',
  diagnosed_at  date,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- patient_allergies
-- FIX: adicionado on delete cascade, updated_at, created_by
-- ---------------------------------------------------------------
create table patient_allergies (
  id          uuid primary key default gen_random_uuid(),
  patient_id  uuid not null references patients(id) on delete cascade,
  created_by  uuid not null references auth.users(id) on delete restrict,
  allergy     text not null,
  severity    allergy_severity not null default 'medium',
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- emergency_contacts
-- FIX: adicionado on delete cascade, updated_at, check phone/email
-- ---------------------------------------------------------------
create table emergency_contacts (
  id           uuid primary key default gen_random_uuid(),
  patient_id   uuid not null references patients(id) on delete cascade,
  name         text not null,
  relationship text,
  phone        text,
  email        text,
  -- FIX: pelo menos um contato obrigatório
  priority     int not null default 1,
  notes        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  constraint chk_contact_method check (phone is not null or email is not null)
);

-- ---------------------------------------------------------------
-- medications
-- FIX: adicionado on delete cascade, created_by, generic_name
-- ---------------------------------------------------------------
create table medications (
  id              uuid primary key default gen_random_uuid(),
  patient_id      uuid not null references patients(id) on delete cascade,
  created_by      uuid not null references auth.users(id) on delete restrict,
  name            text not null,
  generic_name    text,
  dosage          text,
  frequency       text,
  -- jsonb: [{"time": "08:00"}, {"time": "20:00"}]
  schedule        jsonb,
  start_date      date,
  end_date        date,
  prescribed_by   text,
  status          medication_status not null default 'active',
  notes           text,
  -- FIX: path do Storage
  photo_path      text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- medication_change_history
-- FIX: tabela nova — PRD exige preservar histórico de mudanças de dose
-- ---------------------------------------------------------------
create table medication_change_history (
  id             uuid primary key default gen_random_uuid(),
  medication_id  uuid not null references medications(id) on delete cascade,
  changed_by     uuid not null references auth.users(id) on delete restrict,
  field_changed  text not null,
  old_value      text,
  new_value      text,
  change_reason  text,
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- medication_logs
-- FIX: removido patient_id redundante, adicionado scheduled_for
-- ---------------------------------------------------------------
create table medication_logs (
  id             uuid primary key default gen_random_uuid(),
  medication_id  uuid not null references medications(id) on delete cascade,
  -- FIX: quando deveria ter sido tomado (base para calcular "missed")
  scheduled_for  timestamptz,
  taken_at       timestamptz,
  status         medication_log_status not null,
  logged_by      uuid references auth.users(id) on delete set null,
  notes          text,
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- appointments
-- FIX: adicionado created_by, address, map_url, parent_appointment_id
-- ---------------------------------------------------------------
create table appointments (
  id                   uuid primary key default gen_random_uuid(),
  patient_id           uuid not null references patients(id) on delete cascade,
  created_by           uuid not null references auth.users(id) on delete restrict,
  -- FIX: permite criar retorno vinculado à consulta origem
  parent_appointment_id uuid references appointments(id) on delete set null,
  type                 appointment_type not null,
  title                text not null,
  scheduled_at         timestamptz not null,
  -- FIX: separado nome do local de endereço e link de mapa
  location_name        text,
  address              text,
  map_url              text,
  doctor_name          text,
  specialty            text,
  responsible_user_id  uuid references auth.users(id) on delete set null,
  status               appointment_status not null default 'scheduled',
  notes                text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- clinical_events
-- FIX: type com enum, adicionado on delete cascade, doctor_name,
-- tags, appointment_id
-- ---------------------------------------------------------------
create table clinical_events (
  id              uuid primary key default gen_random_uuid(),
  patient_id      uuid not null references patients(id) on delete cascade,
  appointment_id  uuid references appointments(id) on delete set null,
  created_by      uuid not null references auth.users(id) on delete restrict,
  event_date      date not null,
  -- FIX: enum com tipos definidos no PRD
  type            clinical_event_type not null,
  title           text not null,
  description     text,
  severity        event_severity,
  doctor_name     text,
  tags            text[],
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- documents
-- FIX: file_path em vez de file_url, adicionados file_size,
-- expiry_date, clinical_event_id, appointment_id
-- ---------------------------------------------------------------
create table documents (
  id                uuid primary key default gen_random_uuid(),
  patient_id        uuid not null references patients(id) on delete cascade,
  uploaded_by       uuid not null references auth.users(id) on delete restrict,
  clinical_event_id uuid references clinical_events(id) on delete set null,
  appointment_id    uuid references appointments(id) on delete set null,
  title             text not null,
  type              document_type not null,
  -- FIX: path interno do Supabase Storage (gera signed URL na app)
  file_path         text not null,
  file_mime_type    text,
  -- FIX: controle de storage para billing/quotas
  file_size_bytes   bigint,
  document_date     date,
  -- FIX: PRD menciona "validade (quando aplicável)"
  expiry_date       date,
  institution       text,
  doctor_name       text,
  tags              text[],
  ocr_text          text,
  ai_summary        text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- emergency_links
-- FIX: adicionado on delete cascade, access_count, last_accessed_at
-- ---------------------------------------------------------------
create table emergency_links (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references patients(id) on delete cascade,
  created_by       uuid not null references auth.users(id) on delete restrict,
  -- FIX: token criptograficamente seguro por padrão
  token            text not null unique default encode(gen_random_bytes(32), 'hex'),
  expires_at       timestamptz,
  is_active        boolean not null default true,
  access_count     int not null default 0,
  last_accessed_at timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- access_logs
-- FIX: user_id referencia auth.users (nullable para acesso anônimo
-- via link de emergência), adicionado user_agent, emergency_link_id
-- ---------------------------------------------------------------
create table access_logs (
  id                 uuid primary key default gen_random_uuid(),
  family_id          uuid references families(id) on delete set null,
  patient_id         uuid references patients(id) on delete set null,
  -- nullable: acesso anônimo via link de emergência
  user_id            uuid references auth.users(id) on delete set null,
  -- FIX: rastrear qual link de emergência foi usado
  emergency_link_id  uuid references emergency_links(id) on delete set null,
  action             text not null,
  resource_type      text,
  resource_id        uuid,
  ip_address         text,
  -- FIX: essencial para auditoria de segurança
  user_agent         text,
  created_at         timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- ÍNDICES
-- FIX: todas as FKs mais usadas precisam de índice
-- ---------------------------------------------------------------
create index idx_family_members_family_id   on family_members(family_id);
create index idx_family_members_user_id     on family_members(user_id);
create index idx_invitations_family_id      on invitations(family_id);
create index idx_invitations_token          on invitations(token);
create index idx_patients_family_id         on patients(family_id);
create index idx_patient_conditions_patient on patient_conditions(patient_id);
create index idx_patient_allergies_patient  on patient_allergies(patient_id);
create index idx_emergency_contacts_patient on emergency_contacts(patient_id);
create index idx_medications_patient_id     on medications(patient_id);
create index idx_medications_status         on medications(status);
create index idx_medication_logs_medication on medication_logs(medication_id);
create index idx_medication_logs_scheduled  on medication_logs(scheduled_for);
create index idx_appointments_patient_id    on appointments(patient_id);
create index idx_appointments_scheduled_at  on appointments(scheduled_at);
create index idx_clinical_events_patient    on clinical_events(patient_id);
create index idx_clinical_events_date       on clinical_events(event_date);
create index idx_documents_patient_id       on documents(patient_id);
create index idx_documents_type             on documents(type);
create index idx_emergency_links_token      on emergency_links(token);
create index idx_emergency_links_patient    on emergency_links(patient_id);
create index idx_access_logs_patient        on access_logs(patient_id);
create index idx_access_logs_family         on access_logs(family_id);
create index idx_access_logs_user           on access_logs(user_id);
create index idx_access_logs_created        on access_logs(created_at desc);

-- ---------------------------------------------------------------
-- ROW LEVEL SECURITY
-- FIX: sem RLS qualquer usuário autenticado lê dados de outras famílias
-- ---------------------------------------------------------------
alter table profiles                  enable row level security;
alter table families                  enable row level security;
alter table family_members            enable row level security;
alter table invitations               enable row level security;
alter table patients                  enable row level security;
alter table patient_conditions        enable row level security;
alter table patient_allergies         enable row level security;
alter table emergency_contacts        enable row level security;
alter table medications               enable row level security;
alter table medication_change_history enable row level security;
alter table medication_logs           enable row level security;
alter table appointments              enable row level security;
alter table clinical_events           enable row level security;
alter table documents                 enable row level security;
alter table emergency_links           enable row level security;
alter table access_logs               enable row level security;

-- Helper: retorna os family_ids aos quais o usuário corrente pertence (ativo)
create or replace function auth.user_family_ids()
returns setof uuid
language sql
stable
security definer
as $$
  select family_id
  from family_members
  where user_id = auth.uid()
    and status = 'active'
$$;

-- Helper: retorna os patient_ids acessíveis ao usuário corrente
create or replace function auth.user_patient_ids()
returns setof uuid
language sql
stable
security definer
as $$
  select id from patients
  where family_id in (select auth.user_family_ids())
$$;

-- profiles: cada usuário lê e edita apenas o próprio perfil
create policy "profiles_select_own" on profiles for select using (id = auth.uid());
create policy "profiles_insert_own" on profiles for insert with check (id = auth.uid());
create policy "profiles_update_own" on profiles for update using (id = auth.uid());

-- families: membros ativos veem a família; apenas admin edita
create policy "families_select_member" on families
  for select using (id in (select auth.user_family_ids()));
create policy "families_insert_own" on families
  for insert with check (created_by = auth.uid());
create policy "families_update_admin" on families
  for update using (
    id in (
      select family_id from family_members
      where user_id = auth.uid() and role = 'admin' and status = 'active'
    )
  );

-- family_members: membros ativos veem os outros membros da família
create policy "family_members_select" on family_members
  for select using (family_id in (select auth.user_family_ids()));
create policy "family_members_insert_admin" on family_members
  for insert with check (
    family_id in (
      select family_id from family_members
      where user_id = auth.uid() and role = 'admin' and status = 'active'
    )
  );
create policy "family_members_update_admin" on family_members
  for update using (
    family_id in (
      select family_id from family_members
      where user_id = auth.uid() and role = 'admin' and status = 'active'
    )
  );

-- patients e todas as tabelas dependentes: acesso via família
create policy "patients_select" on patients
  for select using (family_id in (select auth.user_family_ids()));
create policy "patients_insert" on patients
  for insert with check (family_id in (select auth.user_family_ids()));
create policy "patients_update" on patients
  for update using (family_id in (select auth.user_family_ids()));

-- Macro para tabelas dependentes de patient_id
create policy "patient_conditions_select" on patient_conditions
  for select using (patient_id in (select auth.user_patient_ids()));
create policy "patient_conditions_insert" on patient_conditions
  for insert with check (patient_id in (select auth.user_patient_ids()));
create policy "patient_conditions_update" on patient_conditions
  for update using (patient_id in (select auth.user_patient_ids()));

create policy "patient_allergies_select" on patient_allergies
  for select using (patient_id in (select auth.user_patient_ids()));
create policy "patient_allergies_insert" on patient_allergies
  for insert with check (patient_id in (select auth.user_patient_ids()));
create policy "patient_allergies_update" on patient_allergies
  for update using (patient_id in (select auth.user_patient_ids()));

create policy "emergency_contacts_select" on emergency_contacts
  for select using (patient_id in (select auth.user_patient_ids()));
create policy "emergency_contacts_insert" on emergency_contacts
  for insert with check (patient_id in (select auth.user_patient_ids()));
create policy "emergency_contacts_update" on emergency_contacts
  for update using (patient_id in (select auth.user_patient_ids()));

create policy "medications_select" on medications
  for select using (patient_id in (select auth.user_patient_ids()));
create policy "medications_insert" on medications
  for insert with check (patient_id in (select auth.user_patient_ids()));
create policy "medications_update" on medications
  for update using (patient_id in (select auth.user_patient_ids()));

create policy "medication_logs_select" on medication_logs
  for select using (
    medication_id in (
      select id from medications where patient_id in (select auth.user_patient_ids())
    )
  );
create policy "medication_logs_insert" on medication_logs
  for insert with check (
    medication_id in (
      select id from medications where patient_id in (select auth.user_patient_ids())
    )
  );

create policy "medication_change_history_select" on medication_change_history
  for select using (
    medication_id in (
      select id from medications where patient_id in (select auth.user_patient_ids())
    )
  );
create policy "medication_change_history_insert" on medication_change_history
  for insert with check (
    medication_id in (
      select id from medications where patient_id in (select auth.user_patient_ids())
    )
  );

create policy "appointments_select" on appointments
  for select using (patient_id in (select auth.user_patient_ids()));
create policy "appointments_insert" on appointments
  for insert with check (patient_id in (select auth.user_patient_ids()));
create policy "appointments_update" on appointments
  for update using (patient_id in (select auth.user_patient_ids()));

create policy "clinical_events_select" on clinical_events
  for select using (patient_id in (select auth.user_patient_ids()));
create policy "clinical_events_insert" on clinical_events
  for insert with check (patient_id in (select auth.user_patient_ids()));
create policy "clinical_events_update" on clinical_events
  for update using (patient_id in (select auth.user_patient_ids()));

create policy "documents_select" on documents
  for select using (patient_id in (select auth.user_patient_ids()));
create policy "documents_insert" on documents
  for insert with check (patient_id in (select auth.user_patient_ids()));
create policy "documents_update" on documents
  for update using (patient_id in (select auth.user_patient_ids()));

-- emergency_links: membros da família gerenciam; token público para leitura anônima
create policy "emergency_links_select_member" on emergency_links
  for select using (patient_id in (select auth.user_patient_ids()));
create policy "emergency_links_select_public" on emergency_links
  for select using (is_active = true and (expires_at is null or expires_at > now()));
create policy "emergency_links_insert" on emergency_links
  for insert with check (patient_id in (select auth.user_patient_ids()));
create policy "emergency_links_update" on emergency_links
  for update using (patient_id in (select auth.user_patient_ids()));

-- access_logs: somente insert (auditoria imutável); admins da família leem
create policy "access_logs_insert" on access_logs
  for insert with check (true);
create policy "access_logs_select_admin" on access_logs
  for select using (
    family_id in (
      select family_id from family_members
      where user_id = auth.uid() and role = 'admin' and status = 'active'
    )
  );

-- ---------------------------------------------------------------
-- TRIGGERS: updated_at automático
-- ---------------------------------------------------------------
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at
  before update on profiles
  for each row execute function set_updated_at();

create trigger trg_families_updated_at
  before update on families
  for each row execute function set_updated_at();

create trigger trg_family_members_updated_at
  before update on family_members
  for each row execute function set_updated_at();

create trigger trg_patients_updated_at
  before update on patients
  for each row execute function set_updated_at();

create trigger trg_patient_conditions_updated_at
  before update on patient_conditions
  for each row execute function set_updated_at();

create trigger trg_patient_allergies_updated_at
  before update on patient_allergies
  for each row execute function set_updated_at();

create trigger trg_emergency_contacts_updated_at
  before update on emergency_contacts
  for each row execute function set_updated_at();

create trigger trg_medications_updated_at
  before update on medications
  for each row execute function set_updated_at();

create trigger trg_appointments_updated_at
  before update on appointments
  for each row execute function set_updated_at();

create trigger trg_clinical_events_updated_at
  before update on clinical_events
  for each row execute function set_updated_at();

create trigger trg_documents_updated_at
  before update on documents
  for each row execute function set_updated_at();

create trigger trg_emergency_links_updated_at
  before update on emergency_links
  for each row execute function set_updated_at();
