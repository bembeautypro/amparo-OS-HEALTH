# Prompts de Construção — Amparo
## Sequência para Lovable

> **Como usar:** Execute cada prompt em ordem. Não pule etapas.
> Cada prompt assume que o anterior foi executado com sucesso.
> Revise e teste o resultado antes de avançar.

---

## PROMPT 0 — Contexto Permanente do Projeto

> Cole este bloco no campo de contexto/instruções do projeto no Lovable (fica ativo em todos os chats).

```
Estou construindo o Amparo — um Family Health Hub SaaS mobile-first.

Produto: Central operacional de saúde familiar para filhos adultos organizarem a saúde de pais idosos.
Não é app de remédio. Não é prontuário médico. É coordenação familiar de saúde.

Stack obrigatória:
- Frontend: Lovable Cloud (TanStack Start + React + Tailwind)
- Roteamento: TanStack Start file-based em src/routes/ (NUNCA src/pages/)
- Banco: Supabase Postgres
- Auth: Supabase Auth
- Storage: Supabase Storage
- Permissões: Row Level Security (RLS) em todas as tabelas clínicas
- Server Functions: TanStack createServerFn com supabaseAdmin (service_role) — equivalente às Edge Functions neste stack
- Deploy: Cloudflare Workers (gerenciado pelo Lovable Cloud)

Princípios inegociáveis:
1. Mobile-first. Usuário típico: adulto 30-60 anos, celular, sob estresse.
2. RLS em toda tabela com dado clínico. Nunca depender de filtro só no frontend.
3. Dados clínicos usam soft delete (deleted_at), nunca deleção física.
4. file_path no banco (nunca file_url). URL assinada gerada na aplicação.
5. Busca de documentos sempre server-side via coluna gerada search_vector. Nunca carregar tudo no client.
6. Log de emergência via Server Function (createServerFn + supabaseAdmin). Nunca UPDATE direto do client público.
7. Ações em cards via botão ⋮ com bottom sheet. Nunca swipe-to-reveal.
8. Upload mobile: câmera + galeria. Drag & drop só no desktop.
9. Nunca aceitar HEIC no upload — usar apenas JPEG, PNG e PDF.
10. Schema obrigatório do campo schedule em medications: { "times": ["08:00", "14:00"] } — nunca usar outro formato ou chave diferente.
11. Nunca verificar existência de e-mail no frontend para decidir branch de convite — exibir sempre os dois botões.

Variáveis de ambiente:
- VITE_SUPABASE_URL: provisionada automaticamente pelo Lovable Cloud
- VITE_SUPABASE_PUBLISHABLE_KEY: nome correto da anon key no Lovable Cloud (não VITE_SUPABASE_ANON_KEY)
- SUPABASE_SERVICE_ROLE_KEY: configurar nos Environment Secrets do projeto Lovable (nunca expor no client)
  — usar dentro de createServerFn handlers, nunca no module scope

Nota: o client Supabase gerado pelo Lovable (src/integrations/supabase/client.ts) já lê VITE_SUPABASE_PUBLISHABLE_KEY automaticamente. Não sobrescrever esse arquivo.

Dependências a instalar no projeto:
- qrcode.react (geração de QR Code na Central de Emergência)
- react-pdf (visualização de PDF com fallback window.open)

Pré-requisitos:
- Extensão pgcrypto ativada (inclua no início da migration: CREATE EXTENSION IF NOT EXISTS pgcrypto;)
- Bucket medical-documents criado como PRIVADO via migration SQL ou SQL Editor do Supabase
- Lovable Cloud gerencia a região e o projeto Supabase — não é necessário acessar o dashboard do Supabase manualmente

Bottom nav fixa: Home | Medicamentos | Agenda | Documentos | Família
Perfil: avatar no header.
FAB: bottom 72px (acima da nav).
Botão Emergência: no card do familiar no dashboard. Ícone ⚡ discreto no header das outras telas.
```

---

## PROMPT 1 — Fundação: Banco de Dados e Autenticação

```
Crie a fundação completa do Amparo: banco de dados, autenticação e estrutura do projeto.

## 1. Migration completa do banco (Supabase)

Execute esta migration na ordem exata:

-- TRIGGER de updated_at (reutilizado em todas as tabelas)
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- PROFILES
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  photo_url text,
  onboarding_step int default 0,  -- 0=conta criada, 1=família criada, 2=paciente criado, 3=completo
  created_at timestamp default now(),
  updated_at timestamp default now()
);
create trigger profiles_updated_at before update on profiles
  for each row execute function set_updated_at();
alter table profiles enable row level security;
create policy "users can read own profile" on profiles for select
  using (id = auth.uid());
create policy "users can update own profile" on profiles for update
  using (id = auth.uid());
create policy "users can insert own profile" on profiles for insert
  with check (id = auth.uid());

-- FAMILIES
create table families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamp default now(),
  updated_at timestamp default now()
);
create trigger families_updated_at before update on families
  for each row execute function set_updated_at();
alter table families enable row level security;

-- FAMILY_MEMBERS
create table family_members (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'editor', 'viewer', 'caregiver')),
  status text not null check (status in ('invited', 'active', 'removed')),
  invited_by uuid references auth.users(id) on delete set null,
  created_at timestamp default now(),
  updated_at timestamp default now(),
  unique (family_id, user_id)
);
create index idx_family_members_family_id on family_members(family_id);
create index idx_family_members_user_id on family_members(user_id);
create trigger family_members_updated_at before update on family_members
  for each row execute function set_updated_at();
alter table family_members enable row level security;

-- INVITATIONS
create table invitations (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id) on delete cascade,
  token text unique not null default encode(gen_random_bytes(32), 'hex'),
  email text,
  role text not null check (role in ('admin', 'editor', 'viewer', 'caregiver')),
  invited_by uuid references auth.users(id) on delete set null,
  status text not null check (status in ('pending', 'accepted', 'expired')),
  expires_at timestamp not null,
  created_at timestamp default now()
);
create index idx_invitations_token on invitations(token);
alter table invitations enable row level security;

-- PATIENTS
create table patients (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id) on delete restrict,
  name text not null,
  photo_url text,
  birth_date date,
  blood_type text check (blood_type in ('A+','A-','B+','B-','AB+','AB-','O+','O-','unknown')),
  height numeric,
  weight numeric,
  health_insurance_name text,
  health_insurance_number text,
  preferred_hospital text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  deleted_at timestamp,
  deleted_by uuid references auth.users(id),
  created_at timestamp default now(),
  updated_at timestamp default now()
);
create index idx_patients_family_id on patients(family_id);
create index idx_patients_deleted_at on patients(deleted_at);
create trigger patients_updated_at before update on patients
  for each row execute function set_updated_at();
alter table patients enable row level security;

-- PATIENT_CONDITIONS
create table patient_conditions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id) on delete cascade,
  name text not null,
  description text,
  diagnosed_at date,
  status text check (status in ('active', 'inactive', 'unknown')),
  deleted_at timestamp,
  deleted_by uuid references auth.users(id),
  created_at timestamp default now(),
  updated_at timestamp default now()
);
create index idx_patient_conditions_patient_id on patient_conditions(patient_id);
create index idx_patient_conditions_deleted_at on patient_conditions(deleted_at);
alter table patient_conditions enable row level security;

-- PATIENT_ALLERGIES
create table patient_allergies (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id) on delete cascade,
  allergy text not null,
  severity text check (severity in ('low', 'medium', 'high', 'critical')),
  notes text,
  deleted_at timestamp,
  deleted_by uuid references auth.users(id),
  created_at timestamp default now()
);
create index idx_patient_allergies_patient_id on patient_allergies(patient_id);
create index idx_patient_allergies_deleted_at on patient_allergies(deleted_at);
alter table patient_allergies enable row level security;

-- EMERGENCY_CONTACTS
create table emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id) on delete cascade,
  name text not null,
  relationship text,
  phone text,
  email text,
  priority int default 1,
  deleted_at timestamp,
  deleted_by uuid references auth.users(id),
  created_at timestamp default now()
);
create index idx_emergency_contacts_patient_id on emergency_contacts(patient_id);
create index idx_emergency_contacts_deleted_at on emergency_contacts(deleted_at);
alter table emergency_contacts enable row level security;

-- MEDICATIONS
create table medications (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id) on delete cascade,
  name text not null,
  generic_name text,
  dosage text,
  frequency text,
  schedule jsonb,  -- schema obrigatório: { "times": ["08:00", "14:00"] } — nunca usar outro formato
  start_date date,
  end_date date,
  prescribed_by text,
  status text not null check (status in ('active', 'paused', 'ended')),
  notes text,
  file_path text,
  deleted_at timestamp,
  deleted_by uuid references auth.users(id),
  created_at timestamp default now(),
  updated_at timestamp default now()
);
create index idx_medications_patient_id on medications(patient_id);
create index idx_medications_status on medications(status);
create index idx_medications_deleted_at on medications(deleted_at);
create trigger medications_updated_at before update on medications
  for each row execute function set_updated_at();
alter table medications enable row level security;

-- APPOINTMENTS
create table appointments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id) on delete cascade,
  parent_appointment_id uuid references appointments(id) on delete set null,
  type text not null check (type in ('consultation','exam','return','procedure','therapy','vaccine','other')),
  title text not null,
  scheduled_at timestamp not null,
  location text,
  address text,
  map_url text,
  doctor_name text,
  specialty text,
  responsible_user_id uuid references auth.users(id) on delete set null,
  status text not null check (status in ('scheduled','confirmed','done','cancelled','rescheduled')),
  notes text,
  deleted_at timestamp,
  deleted_by uuid references auth.users(id),
  created_at timestamp default now(),
  updated_at timestamp default now()
);
create index idx_appointments_patient_id on appointments(patient_id);
create index idx_appointments_scheduled_at on appointments(scheduled_at);
create index idx_appointments_status on appointments(status);
create index idx_appointments_deleted_at on appointments(deleted_at);
create trigger appointments_updated_at before update on appointments
  for each row execute function set_updated_at();
alter table appointments enable row level security;

-- CLINICAL_EVENTS
create table clinical_events (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id) on delete cascade,
  appointment_id uuid references appointments(id) on delete set null,
  event_date date not null,
  type text not null check (type in (
    'consultation','exam','hospitalization','surgery','symptom',
    'fall_accident','medication_change','diagnosis','return',
    'crisis','vaccine','family_note'
  )),
  title text not null,
  description text,
  severity text check (severity in ('low','medium','high','critical')),
  created_by uuid references auth.users(id) on delete set null,
  deleted_at timestamp,
  deleted_by uuid references auth.users(id),
  created_at timestamp default now(),
  updated_at timestamp default now()
);
create index idx_clinical_events_patient_id on clinical_events(patient_id);
create index idx_clinical_events_event_date on clinical_events(event_date);
create index idx_clinical_events_deleted_at on clinical_events(deleted_at);
create trigger clinical_events_updated_at before update on clinical_events
  for each row execute function set_updated_at();
alter table clinical_events enable row level security;

-- DOCUMENTS
create table documents (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id) on delete cascade,
  uploaded_by uuid references auth.users(id) on delete set null,
  title text not null,
  type text not null check (type in (
    'prescription','exam','report','medical_request','insurance_card',
    'id_document','discharge','vaccine','medication_photo','other'
  )),
  file_path text not null,
  file_mime_type text,
  file_size_bytes bigint,
  document_date date,
  expiry_date date,
  institution text,
  doctor_name text,
  clinical_event_id uuid references clinical_events(id) on delete set null,
  tags text[],
  ocr_text text,
  ai_summary text,
  search_vector tsvector generated always as (
    to_tsvector('portuguese',
      coalesce(title,'') || ' ' ||
      coalesce(doctor_name,'') || ' ' ||
      coalesce(institution,'') || ' ' ||
      coalesce(ocr_text,'')
    )
  ) stored,
  deleted_at timestamp,
  deleted_by uuid references auth.users(id),
  created_at timestamp default now(),
  updated_at timestamp default now()
);
create index idx_documents_patient_id on documents(patient_id);
create index idx_documents_type on documents(type);
create index idx_documents_deleted_at on documents(deleted_at);
create index idx_documents_fts on documents using gin(search_vector);
create trigger documents_updated_at before update on documents
  for each row execute function set_updated_at();
alter table documents enable row level security;

-- EMERGENCY_LINKS
create table emergency_links (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(id) on delete cascade,
  token text unique not null default encode(gen_random_bytes(32), 'hex'),
  expires_at timestamp,
  is_active boolean default true,
  access_count int default 0,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamp default now()
);
create index idx_emergency_links_token on emergency_links(token);
alter table emergency_links enable row level security;

-- ACCESS_LOGS
create table access_logs (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id) on delete set null,
  patient_id uuid references patients(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  emergency_link_id uuid references emergency_links(id) on delete set null,
  action text not null,
  resource_type text,
  resource_id uuid,
  ip_address text,
  user_agent text,
  created_at timestamp default now()
);
create index idx_access_logs_patient_id on access_logs(patient_id);
create index idx_access_logs_created_at on access_logs(created_at);
alter table access_logs enable row level security;

## 2. RLS — Políticas base (aplique após as tabelas)

-- Função auxiliar: verifica se user é membro ativo da família
create or replace function is_family_member(fid uuid)
returns boolean as $$
  select exists (
    select 1 from family_members
    where family_id = fid
    and user_id = auth.uid()
    and status = 'active'
  );
$$ language sql security definer;

-- Função auxiliar: verifica role mínimo do membro
create or replace function has_family_role(fid uuid, roles text[])
returns boolean as $$
  select exists (
    select 1 from family_members
    where family_id = fid
    and user_id = auth.uid()
    and status = 'active'
    and role = any(roles)
  );
$$ language sql security definer;

-- FAMILIES: membro vê família, admin edita
create policy "members can read families" on families for select
  using (is_family_member(id));
create policy "admins can update families" on families for update
  using (has_family_role(id, array['admin']));
create policy "authenticated can insert families" on families for insert
  with check (auth.uid() is not null);

-- FAMILY_MEMBERS: membro vê outros membros da família
create policy "members can read family_members" on family_members for select
  using (is_family_member(family_id));
create policy "admins can manage family_members" on family_members for all
  using (has_family_role(family_id, array['admin']));

-- PATIENTS: membro lê, editor/admin edita, deleted_at IS NULL obrigatório
create policy "members can read patients" on patients for select
  using (is_family_member(family_id) and deleted_at is null);
create policy "editors can insert patients" on patients for insert
  with check (has_family_role(family_id, array['admin','editor']));
create policy "editors can update patients" on patients for update
  using (has_family_role(family_id, array['admin','editor']) and deleted_at is null);

-- MEDICATIONS
create policy "members can read medications" on medications for select
  using (
    patient_id in (select p.id from patients p where is_family_member(p.family_id))
    and deleted_at is null
  );
create policy "editors can insert medications" on medications for insert
  with check (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
  );
create policy "editors can update medications" on medications for update
  using (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
    and deleted_at is null
  );

-- APPOINTMENTS
create policy "members can read appointments" on appointments for select
  using (
    patient_id in (select p.id from patients p where is_family_member(p.family_id))
    and deleted_at is null
  );
create policy "editors can insert appointments" on appointments for insert
  with check (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
  );
create policy "editors can update appointments" on appointments for update
  using (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
    and deleted_at is null
  );

-- CLINICAL_EVENTS
create policy "members can read clinical_events" on clinical_events for select
  using (
    patient_id in (select p.id from patients p where is_family_member(p.family_id))
    and deleted_at is null
  );
create policy "editors can insert clinical_events" on clinical_events for insert
  with check (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
  );
create policy "editors can update clinical_events" on clinical_events for update
  using (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
    and deleted_at is null
  );

-- DOCUMENTS
create policy "members can read documents" on documents for select
  using (
    patient_id in (select p.id from patients p where is_family_member(p.family_id))
    and deleted_at is null
  );
create policy "editors can insert documents" on documents for insert
  with check (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
  );
create policy "editors can update documents" on documents for update
  using (
    patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor']))
    and deleted_at is null
  );

-- PATIENT_CONDITIONS, PATIENT_ALLERGIES, EMERGENCY_CONTACTS
-- Mesma lógica via join com patients → family_members
create policy "members can read patient_conditions" on patient_conditions for select
  using (patient_id in (select p.id from patients p where is_family_member(p.family_id)) and deleted_at is null);
create policy "editors can insert patient_conditions" on patient_conditions for insert
  with check (patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor'])));
create policy "editors can update patient_conditions" on patient_conditions for update
  using (patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor'])) and deleted_at is null);

create policy "members can read patient_allergies" on patient_allergies for select
  using (patient_id in (select p.id from patients p where is_family_member(p.family_id)) and deleted_at is null);
create policy "editors can insert patient_allergies" on patient_allergies for insert
  with check (patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor'])));
create policy "editors can update patient_allergies" on patient_allergies for update
  using (patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor'])) and deleted_at is null);

create policy "members can read emergency_contacts" on emergency_contacts for select
  using (patient_id in (select p.id from patients p where is_family_member(p.family_id)) and deleted_at is null);
create policy "editors can insert emergency_contacts" on emergency_contacts for insert
  with check (patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor'])));
create policy "editors can update emergency_contacts" on emergency_contacts for update
  using (patient_id in (select p.id from patients p where has_family_role(p.family_id, array['admin','editor'])) and deleted_at is null);

-- STORAGE — bucket medical-documents (executar no SQL Editor do Supabase após criar bucket como PRIVADO)
-- create policy "members can access patient files" on storage.objects
--   for all using (
--     bucket_id = 'medical-documents'
--     and (storage.foldername(name))[2] in (
--       select p.id::text from patients p
--       join family_members fm on fm.family_id = p.family_id
--       where fm.user_id = auth.uid() and fm.status = 'active'
--     )
--   );

-- Função RPC para verificar único admin (usada no Prompt 11 para bloquear exclusão de conta)
create or replace function get_solo_admin_families(p_user_id uuid)
returns table(family_id uuid) as $$
  select fm.family_id
  from family_members fm
  where fm.user_id = p_user_id
    and fm.role = 'admin'
    and fm.status = 'active'
    and fm.family_id in (
      select family_id from family_members
      where role = 'admin' and status = 'active'
      group by family_id
      having count(*) = 1
    )
$$ language sql security definer;

-- EMERGENCY_LINKS: membro cria, leitura pública via token (tratada na Edge Function)
create policy "members can manage emergency_links" on emergency_links for all
  using (
    patient_id in (
      select p.id from patients p
      join family_members fm on fm.family_id = p.family_id
      where fm.user_id = auth.uid() and fm.status = 'active'
    )
  );

-- ACCESS_LOGS: apenas service_role pode inserir (via Edge Function)

## 3. Autenticação

Configure Supabase Auth com:
- E-mail/senha habilitado
- Confirmar e-mail obrigatório
- Criar trigger para inserir em profiles automaticamente ao signup:

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

## 4. Estrutura de pastas do projeto

IMPORTANTE: Lovable Cloud usa TanStack Start com roteamento file-based em src/routes/.
NUNCA usar src/pages/ — quebraria o build e os links tipados.

Organize o projeto com:
/src
  /components
    /ui          -- shadcn/ui base
    /layout      -- BottomNav, Header, FAB
    /patients    -- cards e formulários de familiar
    /medications -- lista, card, bottom sheet de ações
    /appointments -- lista, formulário, fluxo de realizado
    /documents   -- upload, viewer, busca
    /emergency   -- página pública, botão, QR code
    /family      -- membros, convites, permissões
  /routes
    /auth        -- login.tsx, registro.tsx, recuperacao.tsx
    /onboarding  -- familia.tsx, familiar.tsx, emergencia.tsx
    index.tsx    -- dashboard (home)
    e.$token.tsx -- página pública de emergência (sem autenticação)
    convite.$token.tsx -- aceite de convite
  /hooks         -- useFamily, usePatient, useDocuments etc.
  /lib
    supabase-admin.ts  -- createClient com service_role (só em server functions)
    storage.ts         -- helpers de signed URL
    /utils
  /functions             -- server functions com createServerFn
    emergency.functions.ts   -- logEmergencyAccess
    onboarding.functions.ts  -- createFamilyWithAdmin (resolve deadlock de RLS)

## 5. Resultado esperado deste prompt

Ao concluir:
- Migration executada sem erros no Supabase
- RLS ativo em todas as tabelas
- Trigger de profiles funcionando
- Estrutura de pastas criada com src/routes/ (não src/pages/)
- Cliente Supabase configurado (usar o client gerado em src/integrations/supabase/client.ts)
- supabaseAdmin criado em src/lib/supabase-admin.ts (só usado dentro de server function handlers)
- Rotas base definidas com convenção dot-separated do TanStack (ex: auth/login.tsx, onboarding/familia.tsx)

Não crie nenhuma UI ainda. Apenas fundação.
```

---

## PROMPT 2 — Onboarding (5 passos)

```
Crie o fluxo completo de onboarding do Amparo com 5 passos.

## Regras gerais
- Mobile-first. Padding lateral mínimo 20px. Botões com altura mínima 52px.
- Passos 1, 2 e 3 são obrigatórios.
- Passo 4 é completamente opcional — botão "Preencher depois" sempre visível e igual em hierarquia ao botão principal.
- Mostrar barra de progresso no topo (ex: "Passo 2 de 5").
- Não bloquear o usuário por campos incompletos no passo 4.

## Passo 1 — Boas-vindas (tela, sem formulário)

Visual:
- Logo + ícone do Amparo
- Título grande: "A saúde da sua família em um só lugar."
- Subtítulo: "Organize remédios, exames, consultas e informações de emergência de quem você cuida."
- CTA principal: "Começar organização" → vai para registro
- Link discreto abaixo: "Já tenho conta → Entrar"

## Passo 2 — Criar conta

Campos:
- Nome completo
- E-mail
- Senha (com confirmação)

Ao criar conta:
- Inserir em auth.users via Supabase Auth
- Trigger cria profile automaticamente (onboarding_step = 0)
- Redirecionar para Passo 3

## Passo 3 — Criar família (obrigatório)

Título: "Crie sua família"
Campos:
- Nome da família (ex: "Família Silva")
- Seu papel: radio buttons horizontais
  - Filho(a) / Cônjuge / Cuidador(a) / Outro

Ao salvar — OBRIGATÓRIO usar Server Function (não client direto):

A política RLS de family_members exige que o usuário já seja admin para inserir registros,
mas o próprio INSERT do primeiro admin é quem cria essa condição — deadlock.
Para resolver, criar src/functions/onboarding.functions.ts com createServerFn usando supabaseAdmin:

    export const createFamilyWithAdmin = createServerFn()
      .validator((data: { userId: string; familyName: string }) => data)
      .handler(async ({ data: { userId, familyName } }) => {
        const supabaseAdmin = getAdminClient()
        const { data: family } = await supabaseAdmin
          .from('families')
          .insert({ name: familyName, created_by: userId })
          .select('id')
          .single()
        await supabaseAdmin.from('family_members').insert({
          family_id: family!.id, user_id: userId, role: 'admin', status: 'active',
        })
        await supabaseAdmin
          .from('profiles')
          .update({ onboarding_step: 1 })
          .eq('id', userId)
        return family
      })

- INSERT em families com created_by = auth.uid() (via server function)
- INSERT em family_members com role = 'admin', status = 'active' (via server function — bypassa RLS)
- UPDATE profiles SET onboarding_step = 1 (via server function)
- Redirecionar para Passo 4

## Passo 4 — Adicionar familiar cuidado (obrigatório)

Título: "Quem você quer organizar primeiro?"
Campos:
- Nome completo (obrigatório)
- Foto (opcional — botão "Adicionar foto" com câmera/galeria)
- Data de nascimento (date picker mobile-friendly)
- Grau de parentesco: select
  - Pai / Mãe / Avô / Avó / Cônjuge / Irmão(ã) / Outro

Ao salvar:
- INSERT em patients com family_id e created_by
- UPDATE profiles SET onboarding_step = 2 WHERE id = auth.uid()
- Redirecionar para Passo 5

## Passo 5 — Dados críticos de emergência (opcional)

Título: "Preencha o essencial para emergências"
Subtítulo: "Essas informações ficam acessíveis em segundos durante uma emergência."
Botão no topo direito: "Preencher depois →" (sem hierarquia inferior ao botão principal)

Dividido em blocos visuais separados por linha + título:

━━ Para emergências ━━
- Tipo sanguíneo: select (A+, A-, B+, B-, AB+, AB-, O+, O-, Não sei)
- Alergias: campo de tags (adicionar múltiplas)

━━ Condições médicas ━━
- Campo de texto livre para adicionar condições (tags)

━━ Convênio ━━
- Nome do convênio
- Número da carteirinha

━━ Contato de emergência ━━
- Nome / Parentesco / Telefone (com máscara)

## Passo 6 — Primeira ação (tela final do onboarding)

Título: "O que você quer organizar agora?"

4 cards grandes com ícone + texto:
- 💊 Adicionar medicamento → /medicamentos/novo
- 📄 Subir receita ou exame → /documentos/novo
- 📅 Criar consulta → /agenda/nova
- 🆘 Criar resumo de emergência → /emergencia

Abaixo: link "Ir para o início →" → /dashboard

## Requisito crítico
Ao finalizar o onboarding, o usuário deve ter:
- Conta criada / Família criada (com ele como admin) / Pelo menos 1 paciente
- UPDATE profiles SET onboarding_step = 3 ao completar o Passo 5 ou ao clicar "Preencher depois"
- Redirecionamento para dashboard ou primeira ação escolhida

## Lógica de retomada (ao fazer login)
Se profiles.onboarding_step:
- 0 → /onboarding/familia (Passo 3)
- 1 → /onboarding/familiar (Passo 4)
- 2 → /onboarding/emergencia (Passo 5)
- >= 3 → /dashboard
```

---

## PROMPT 3 — Dashboard (Home)

```
Crie a tela de Dashboard (Home) do Amparo.

## Layout geral
- Header fixo: logo à esquerda + avatar do usuário à direita (acessa perfil)
- Ícone ⚡ discreto no header (acessa emergência do paciente ativo)
- Seletor de paciente sticky logo abaixo do header (quando família tem mais de 1 paciente)
- Scroll vertical com os blocos abaixo
- Bottom nav fixa: Home | Medicamentos | Agenda | Documentos | Família
- FAB (+) fixo, bottom: 72px, right: 16px (acima da nav)
- FAB abre bottom sheet com ações rápidas:
  - Adicionar medicamento / Registrar consulta / Subir documento / Adicionar evento clínico

## Seletor de paciente (sticky)
- Aparece apenas quando há mais de 1 paciente na família
- Tabs horizontais com foto miniatura + nome de cada paciente
- Sticky abaixo do header, nunca dentro dos cards
- Trocar de paciente atualiza todos os blocos abaixo

## Bloco 1 — Card do familiar
- Foto circular grande + nome + idade
- Alertas críticos (badge vermelho se: alergia crítica cadastrada, medicamento sem horário, perfil incompleto)
- Botão primário vermelho: "🆘 Emergência" (abre página de emergência)
- Botão secundário: "Ver perfil completo"

## Bloco 2 — Próximos compromissos
- Mostrar: hoje + próximos 7 dias
- Cada item: tipo (ícone) + título + data/hora + responsável (avatar)
- Estado vazio: "Nenhum compromisso agendado — Agendar consulta +"
- Máximo 3 itens visíveis + "Ver todos →"

## Bloco 3 — Medicamentos ativos
- Lista dos medicamentos com status = 'active' e deleted_at IS NULL
- Cada item: nome + dosagem + horários do dia
- Máximo 4 itens + "Ver todos →"
- Estado vazio: "Nenhum medicamento cadastrado — Adicionar +"

## Bloco 4 — Pendências
- Aparece apenas se houver pendências
- Exemplos: perfil de emergência incompleto, consulta sem responsável, medicamento sem horário
- Visual: fundo amarelo suave, ícone de aviso

## Bloco 5 — Linha do tempo recente
- Últimos 3 clinical_events com deleted_at IS NULL
- Cada item: data + ícone do tipo + título + gravidade (badge)
- "Ver histórico completo →"

## Bloco 6 — Documentos recentes
- Últimos 3 documentos com deleted_at IS NULL
- Cada item: ícone do tipo + título + data
- "Ver todos os documentos →"

## Regras técnicas
- Todos os dados carregados com skeleton loading (nunca tela em branco)
- Queries filtradas por patient_id do paciente ativo
- Filtro de deleted_at IS NULL em todas as queries
- Sem IMC calculado ou exibido em nenhum lugar
```

---

## PROMPT 4 — Módulo de Medicamentos

```
Crie o módulo completo de Medicamentos do Amparo.

## Tela principal — Lista de medicamentos (/medicamentos)

Tabs: "Ativos" | "Pausados" | "Encerrados"
Card de medicamento: nome + nome genérico + dosagem + frequência + próximo horário + badge de status + botão ⋮

## Ações via botão ⋮ (bottom sheet — NUNCA swipe)
- ✏️ Editar / ⏸ Pausar ou ▶️ Reativar / ✅ Encerrar uso / 🗑 Remover (soft delete + confirmação)

Confirmação de remoção:
- Modal: "Remover [nome]? Este medicamento será arquivado."
- Ao confirmar: set deleted_at = now(), deleted_by = auth.uid()

## Formulário — Adicionar/Editar medicamento

Campos:
- Nome do medicamento (obrigatório)
- Nome genérico (opcional)
- Dosagem (ex: "500mg")
- Frequência: select (1x ao dia / 2x ao dia / 3x ao dia / 4x ao dia / A cada 6h / A cada 8h / A cada 12h / Conforme necessário / Outro)
- Horários: aparece se frequência não for "Conforme necessário" ou "Outro"
  - Time pickers para cada horário de acordo com a frequência selecionada
  - Ao salvar, construir o campo schedule SEMPRE no formato: { "times": ["08:00", "14:00"] }
  - Nunca usar outro formato, outra chave ou estrutura diferente para o campo schedule
- Data de início / Data de término prevista (opcional) / Médico que prescreveu / Observações
- Foto da caixa ou receita (opcional):
  - Mobile: botão "Tirar foto" + "Escolher da galeria" (aceitar apenas JPEG, PNG e PDF — NÃO aceitar HEIC)
  - Desktop: área de drag & drop + seleção de arquivo (aceitar apenas JPEG, PNG e PDF)
  - Upload para Supabase Storage, salvar file_path no banco

## Regras técnicas
- Queries com WHERE deleted_at IS NULL
- Soft delete obrigatório (nunca DELETE físico)
- Foto salva em Storage path: patients/{patient_id}/medications/{medication_id}/{filename}
- URL da foto gerada via createSignedUrl, nunca armazenada no banco
- Sem swipe-to-reveal em nenhuma interação
- Campo schedule salvo SEMPRE como { "times": ["HH:MM", ...] } — validar antes do INSERT/UPDATE
```

---

## PROMPT 5 — Módulo de Agenda

```
Crie o módulo completo de Agenda do Amparo.

## Tela principal — Lista de compromissos (/agenda)

Tabs: "Próximos" | "Realizados" | "Cancelados"
Card: ícone do tipo + título + data/hora + local + avatar do responsável + badge de status + botão ⋮

## Ações via botão ⋮ (bottom sheet)
- ✅ Marcar como realizado (fluxo em 2 etapas — ver abaixo)
- ✏️ Editar
- 📋 Criar retorno — exibir APENAS se parent_appointment_id IS NULL (profundidade máxima: 1 nível)
- 🗑 Remover (soft delete + confirmação)

## Fluxo "Marcar como realizado" — 2 etapas obrigatórias

Etapa 1 — Modal simples:
- "Confirmar que esta consulta foi realizada?"
- Ao confirmar:
  1. UPDATE appointments SET status = 'done'
  2. Verificar se já existe clinical_event com appointment_id = :id (evitar duplicata)
  3. Se não existir: INSERT em clinical_events com appointment_id preenchido, type = 'consultation'

Etapa 2 — Banner não-bloqueante (aparece após fechar o modal):
- Texto: "Quer registrar as orientações desta consulta?"
- Botões: "Agora" → formulário de evento clínico | "Depois" → fecha banner
- Some automaticamente após 8 segundos

## Formulário — Adicionar/Editar compromisso

Campos:
- Tipo com ícones: 🩺 Consulta / 🔬 Exame / 🔁 Retorno / 🏥 Procedimento / 🤸 Fisioterapia / 💉 Vacinação / 📋 Outro
- Título (obrigatório) / Data e hora / Local / Endereço / Link de mapa
- Médico/profissional / Especialidade
- Responsável por acompanhar: select com membros ativos da família
- Status: select (agendado / confirmado / cancelado / remarcado) — NÃO incluir na criação; novos compromissos sempre começam como 'scheduled'
- Observações

Se tipo = 'return' e vier de "Criar retorno": preencher parent_appointment_id automaticamente

## Regras técnicas
- Soft delete obrigatório
- Verificar existência de clinical_event antes de criar ao marcar como realizado
- Botão "Criar retorno" visível apenas em appointments com parent_appointment_id IS NULL
```

---

## PROMPT 6 — Módulo de Histórico Clínico

```
Crie o módulo de Histórico Clínico do Amparo.

## Tela principal — Linha do tempo (/historico)

- Filtros como chips horizontais: tipo + gravidade
- FAB (+) para adicionar evento
- Lista cronológica decrescente com deleted_at IS NULL
- Barra de busca com debounce 300ms; buscar via ILIKE em title e description (clinical_events não tem search_vector — usar .or('title.ilike.%query%,description.ilike.%query%'))

Card de evento:
- Linha vertical colorida à esquerda (cor por gravidade: cinza/azul/laranja/vermelho)
- Data + ícone do tipo + título + badge de gravidade + quem registrou
- Botão ⋮ → Editar | Arquivar (soft delete)

## Formulário — Adicionar evento clínico

Campos:
- Tipo: select com 12 opções em pt-BR — usar EXATAMENTE os valores do CHECK constraint do banco:
  - 'consultation' → Consulta
  - 'exam' → Exame
  - 'hospitalization' → Internação
  - 'surgery' → Cirurgia
  - 'symptom' → Sintoma
  - 'fall_accident' → Queda ou acidente
  - 'medication_change' → Alteração de medicamento
  - 'diagnosis' → Diagnóstico
  - 'return' → Retorno médico  ← NÃO usar 'followup' (erro comum)
  - 'crisis' → Crise
  - 'vaccine' → Vacina
  - 'family_note' → Observação familiar
- Data do evento / Título (obrigatório) / Descrição
- Gravidade: radio buttons coloridos ⚪ Baixa | 🔵 Média | 🟠 Alta | 🔴 Crítica
- Tags (campo livre, múltiplas) / Médico relacionado

## Regras técnicas
- Queries com WHERE deleted_at IS NULL ORDER BY event_date DESC
- Soft delete obrigatório (dados históricos de saúde)
- Filtros aplicados server-side
- Tipo validado via CHECK constraint no banco
```

---

## PROMPT 7 — Módulo de Documentos

```
Crie o módulo completo de Documentos do Amparo.

## Tela principal — Biblioteca de documentos (/documentos)

- Barra de busca no topo (server-side com debounce 300ms)
- Filtros: chips por tipo
- Lista/grid de documentos com deleted_at IS NULL
- FAB (+) para adicionar
- Botão ⋮ por documento → Ver | Editar metadados | Compartilhar | Arquivar (soft delete)

## Busca — regra crítica
- Busca SEMPRE server-side via full-text search do Postgres
- Usar a coluna gerada search_vector — não recalcular tsvector inline:

    SELECT * FROM documents
    WHERE patient_id = :patient_id
      AND deleted_at IS NULL
      AND search_vector @@ plainto_tsquery('portuguese', :query)
    ORDER BY document_date DESC NULLS LAST
    LIMIT 20;

- NUNCA carregar todos os documentos no client para buscar localmente

## Upload de documentos

No mobile (viewport < 768px):
- Dois botões grandes:
  - 📷 "Tirar foto" → input type="file" accept="image/jpeg,image/png" capture="environment"
  - 🖼 "Escolher da galeria" → input type="file" accept="image/jpeg,image/png,application/pdf"
- NÃO aceitar HEIC — se o usuário tentar, exibir: "Formato não suportado. Tire uma foto pelo botão da câmera ou converta para JPG antes de subir."
- Sem área de drag & drop

No desktop (viewport >= 768px):
- Área de drag & drop + botão "Selecionar arquivo"
- Aceita apenas: JPEG, PNG e PDF (NÃO aceitar HEIC)

Após seleção:
- Preview da imagem ou ícone de PDF
- Formulário de metadados aparece
- Compressão de imagem client-side antes do upload (max 1920px, qualidade 85%)
- Upload para: patients/{patient_id}/documents/{uuid}/{filename}
- Salvar file_path no banco (nunca a URL direta)

## Formulário de metadados

Campos obrigatórios: Título + Tipo
Campos opcionais (colapsados inicialmente):
- Data do documento / Médico / Instituição / Validade / Tags / Observações
- Vincular a evento clínico: select opcional

## Visualização de documento

- Gerar URL assinada via createSignedUrl (expiração: 3600s)
- PDF: react-pdf → se falhar, botão "Abrir PDF" via window.open(signedUrl)
- Imagem: tag img com a URL assinada
- Nunca usar iframe simples para PDF

## Regras técnicas
- file_path salvo no banco, nunca file_url
- Queries com WHERE deleted_at IS NULL
- Soft delete obrigatório (documentos médicos não são deletados fisicamente)
- Compressão de imagem client-side antes do upload
```

---

## PROMPT 8 — Central de Emergência

```
Crie a Central de Emergência do Amparo — o módulo mais crítico do produto.

## A. Botão de emergência no dashboard

No card do familiar no dashboard:
- Botão vermelho grande: "🆘 Emergência" → navega para /emergencia/{patient_id}

No header das outras telas (Medicamentos, Agenda, Documentos, Histórico):
- Ícone ⚡ discreto (sem texto) no canto direito
- NÃO criar dois botões vermelhos grandes. Apenas 1 (no card). O ⚡ é discreto.

## B. Página de emergência — versão autenticada (/emergencia/{patient_id})

- Card de preview dos dados (mesma ordem da página pública)
- Se nenhum link ativo: botão "Gerar link de emergência"
- Se link ativo:
  - URL truncada + botão "Copiar link"
  - Botão "Compartilhar" (Web Share API)
  - QR Code gerado client-side (qrcode.react)
  - Botão "Salvar QR Code" (download)
  - Badge de expiração / Botão "Desativar link"

Gerar link:
- INSERT em emergency_links (token gerado pelo banco via DEFAULT, expires_at = now() + 7 days)
- URL pública: https://app.amparo.com.br/e/{token}

## C. Página pública de emergência (/e/{token}) — sem autenticação

Regras de carregamento:
1. Buscar emergency_link pelo token
2. Validar: is_active = true AND (expires_at IS NULL OR expires_at > now())
3. Se inválido: tela "Este link não está mais disponível"
4. Se válido: chamar Server Function (ver abaixo) para registrar acesso e obter dados
5. Renderizar com os dados retornados pela Server Function

ORDEM OBRIGATÓRIA das seções:

--- Seção 1: Identificação ---
Foto circular grande + Nome completo + Idade calculada + Tipo sanguíneo (badge grande)

--- Seção 2: ALERGIAS (destaque máximo) ---
Fundo vermelho/laranja claro
Título: "⚠ ALERGIAS" em vermelho escuro, negrito, caixa alta
Lista com badge de severidade: Crítica=vermelho | Alta=laranja | Média=amarelo | Baixa=cinza
Se sem alergias: "Nenhuma alergia cadastrada" em verde

--- Seção 3: Medicamentos ativos ---
"💊 Medicamentos em uso" — nome + dosagem + frequência
Apenas status = 'active' e deleted_at IS NULL

--- Seção 4: Condições médicas ---
"📋 Condições de saúde" — patient_conditions com status = 'active'

--- Seção 5: Convênio e hospital ---
Nome do convênio + número da carteirinha + hospital de preferência

--- Seção 6: Contatos de emergência ---
Lista ordenada por priority — nome + parentesco + telefone + botão "Ligar" (tel: link)

--- Seção 7: Documentos essenciais ---
Últimos 5 documentos: título + tipo + data + botão "Ver" (signed URL da Edge Function)

Design: sem navegação, apenas logo discreto no topo
Disclaimer no rodapé: "Esta página é somente informativa e não substitui orientação médica profissional."
Alto contraste, fonte grande (mínimo 16px)

Performance e cache:
- Skeleton loading em todas as seções
- Após carregamento: salvar seções críticas (identificação, alergias, medicamentos) no localStorage
- Se offline: mostrar banner "⚠ Você está offline. Estas informações podem não estar atualizadas." + dados do cache
- Cache válido por 24 horas

## D. Server Function — log de acesso (src/functions/emergency.functions.ts)

IMPORTANTE: Lovable Cloud não usa Supabase Edge Functions. O equivalente é createServerFn do TanStack Start.
Roda no mesmo Cloudflare Worker do app — sem CORS, sem deploy separado.

Criar o arquivo src/functions/emergency.functions.ts:

    import { createServerFn } from '@tanstack/react-start'
    import { createClient } from '@supabase/supabase-js'

    // supabaseAdmin só pode ser instanciado dentro do handler (env injetado por request no Workers)
    function getAdminClient() {
      return createClient(
        process.env.VITE_SUPABASE_URL!,
        process.env.SUPABASE_SERVICE_ROLE_KEY!
      )
    }

    export const logEmergencyAccess = createServerFn()
      .validator((data: { token: string; ip_address: string; user_agent: string }) => data)
      .handler(async ({ data: { token, ip_address, user_agent } }) => {
        const supabaseAdmin = getAdminClient()

        // 1. Buscar e validar emergency_link pelo token
        const { data: link } = await supabaseAdmin
          .from('emergency_links')
          .select('id, patient_id, is_active, expires_at')
          .eq('token', token)
          .single()

        if (!link || !link.is_active || (link.expires_at && new Date(link.expires_at) < new Date())) {
          throw new Error('LINK_INVALID')
        }

        // 2. INSERT em access_logs
        await supabaseAdmin.from('access_logs').insert({
          emergency_link_id: link.id,
          patient_id: link.patient_id,
          action: 'emergency_view',
          resource_type: 'emergency_link',
          resource_id: link.id,
          ip_address,
          user_agent,
        })

        // 3. UPDATE access_count
        await supabaseAdmin
          .from('emergency_links')
          .update({ access_count: supabaseAdmin.rpc('increment', { x: 1 }) })
          .eq('id', link.id)

        // 4. Carregar dados do paciente
        const { data: patient } = await supabaseAdmin
          .from('patients')
          .select(`
            name, photo_url, birth_date, blood_type,
            health_insurance_name, health_insurance_number, preferred_hospital,
            patient_allergies!inner(allergy, severity),
            patient_conditions!inner(name, status),
            emergency_contacts!inner(name, relationship, phone, priority),
            medications!inner(name, generic_name, dosage, frequency, status),
            documents!inner(id, title, type, file_path, document_date)
          `)
          .eq('id', link.patient_id)
          .single()

        // 5. Gerar signed URLs para documentos (obrigatório usar supabaseAdmin — anon não pode)
        const docs = (patient?.documents ?? [])
          .filter((d: any) => d.file_path)
          .slice(0, 5)
        const document_urls = await Promise.all(
          docs.map(async (d: any) => {
            const { data: signed } = await supabaseAdmin.storage
              .from('medical-documents')
              .createSignedUrl(d.file_path, 3600)
            return { title: d.title, type: d.type, signed_url: signed?.signedUrl ?? null }
          })
        )

        return {
          ...patient,
          allergies: (patient?.patient_allergies ?? []).filter((a: any) => !a.deleted_at),
          medications: (patient?.medications ?? []).filter((m: any) => m.status === 'active'),
          conditions: (patient?.patient_conditions ?? []).filter((c: any) => c.status === 'active'),
          emergency_contacts: [...(patient?.emergency_contacts ?? [])].sort((a: any, b: any) => a.priority - b.priority),
          document_urls,
        }
      })

Chamar na página pública:
    import { logEmergencyAccess } from '~/functions/emergency.functions'

    const patientData = await logEmergencyAccess({
      data: { token, ip_address: '', user_agent: navigator.userAgent }
    })

NÃO usar supabase.functions.invoke() — não há Edge Functions neste stack.
A página pública NUNCA faz UPDATE direto. Sempre via esta Server Function.

## Critérios de aceite
- Página pública carrega em < 1,5 segundos
- Ordem das seções exatamente como especificado
- UPDATE de access_count APENAS via Server Function (logEmergencyAccess)
- Cache funciona mesmo offline
- QR Code disponível para download
- Link pode ser desativado pelo admin
```

---

## PROMPT 9 — Módulo de Família e Permissões

```
Crie o módulo de Família e Permissões do Amparo.

## Tela principal — Membros da família (/familia)

Card de membro: Avatar + nome + e-mail + badge do papel + "(você)" se for o próprio usuário
Ações via botão ⋮ (admin only): Alterar papel | Remover da família (soft delete)

4 papéis com tooltip explicativo:
- Admin: gerencia família, convida e remove membros, edita tudo
- Editor: adiciona e edita dados clínicos
- Visualizador: apenas visualiza
- Cuidador: acessa agenda, medicamentos e emergência

## Fluxo de convite

Tela /familia/convidar:
- Campo: E-mail do convidado (opcional — convite também por link)
- Papel a atribuir (select com 4 papéis)
- Ao gerar: INSERT em invitations (token, role, expires_at = now() + 7 dias)
- Exibir link + botão "Copiar" + botão "Compartilhar" (Web Share API)

## Página de aceite de convite (/convite/:token)

Branch 1 — Usuário logado:
- Verificar token válido e não expirado
- Mostrar nome da família + papel
- "Aceitar convite" → INSERT em family_members, UPDATE invitations status = 'accepted'
- Redirecionar para /dashboard

Branch 2 — Usuário não logado (qualquer caso):
- NUNCA verificar no frontend se o e-mail já existe no sistema — isso expõe existência de usuários
- Mostrar SEMPRE os dois botões:
  - Botão principal: "Criar conta" → /register?invite={token}
  - Botão secundário: "Já tenho conta → Entrar" → /login?invite={token}
- Token preservado via query param durante TODO o fluxo de registro/login
- Após criar conta ou fazer login: aceitar convite automaticamente e redirecionar para /dashboard

## Perfil do usuário (/perfil)

Acessível pelo avatar no header.

Campos editáveis: Foto (câmera/galeria) + Nome completo + Telefone

Fluxo de exclusão de conta:
1. Verificar com get_solo_admin_families RPC:
   const { data: soloAdminFamilies } = await supabase
     .rpc('get_solo_admin_families', { p_user_id: user.id })

2. Se for único admin:
   - NÃO mostrar modal de confirmação
   - Mostrar aviso: "Você é o único administrador da família [Nome]. Promova outro membro como administrador antes de excluir sua conta."
   - Botão: "Gerenciar família →"

3. Se não for único admin:
   - Modal: "Excluir sua conta? Todos os seus dados serão removidos. Esta ação não pode ser desfeita."
   - Campo de confirmação: digitar "EXCLUIR"
   - Botão: "Excluir conta permanentemente"

## Regras técnicas
- Ações de admin verificadas no servidor via RLS, não apenas no frontend
- Convites expiram após 7 dias
- Token do convite preservado via query param durante registro/login
- Remoção de membro: UPDATE status = 'removed', não DELETE físico
```

---

## PROMPT 10 — Perfil do Familiar (Paciente)

```
Crie a tela de perfil completo do familiar cuidado no Amparo.

## Tela principal (/paciente/{id})

Layout com tabs horizontais:
Dados gerais | Alergias | Condições | Medicamentos | Contatos

## Tab: Dados gerais

Exibe: Nome + data de nascimento + idade calculada + tipo sanguíneo + peso + altura
SEM cálculo ou exibição de IMC em nenhum campo.
Convênio + número da carteirinha + hospital de preferência + observações críticas.
Botão "Editar" abre formulário completo.

## Tab: Alergias

Lista com badge de severidade: Crítica=vermelho | Alta=laranja | Média=amarelo | Baixa=cinza
Botão "+" para adicionar.
Formulário: nome da alergia + severidade + observações.
Ação em alergia: botão ⋮ → Editar | Remover (soft delete).

## Tab: Condições médicas

Lista com status: Ativa=verde | Inativa=cinza | Desconhecida=branco.
Botão "+" para adicionar.
Formulário: nome + descrição + data do diagnóstico + status.

## Tab: Medicamentos

Lista resumida dos medicamentos ativos. Link "Ver todos →" para /medicamentos.

## Tab: Contatos de emergência

Lista ordenada por priority.
Cada contato: nome + parentesco + telefone (botão "Ligar") + badge de prioridade.

Reordenar prioridade: botões ↑ ↓ em cada contato — NUNCA drag-and-drop.
Ao tocar ↑: priority do contato sobe 1, priority do contato acima desce 1 (swap).

Botão "+" para adicionar. Formulário: nome (obrigatório) + parentesco + telefone + e-mail.
Ação: botão ⋮ → Editar | Remover (soft delete).

## Formulário de edição do perfil

Campos:
- Foto (câmera/galeria no mobile, drag-drop no desktop)
- Nome completo / Data de nascimento
- Tipo sanguíneo: select validado (A+, A-, B+, B-, AB+, AB-, O+, O-, Não sei)
- Peso (kg) / Altura (cm)
- Sem campo de IMC — nunca calcular ou exibir
- Convênio + número da carteirinha + hospital + observações críticas

## Regras técnicas
- Soft delete para patient_allergies e patient_conditions
- Reordenação de contatos: swap de priority entre dois registros
- Tipo sanguíneo validado pelo CHECK constraint — nunca enviar valor fora da lista
- Foto salva em Storage: patients/{patient_id}/profile/{filename}
- URL gerada via signed URL, nunca armazenada como file_url
```

---

## PROMPT 11 — Ajustes Finais, Performance e Polimento

```
Aplique os ajustes finais de performance, acessibilidade e polimento no Amparo.

## 1. Loading states globais

Em TODA tela que faz query ao banco:
- Skeleton loading enquanto carrega (nunca spinner isolado no meio da tela)
- Skeleton replica o layout real dos cards (mesma altura, mesma estrutura)
- Após carregamento: fade-in suave nos dados
- Estado de erro: mensagem clara + botão "Tentar novamente"

## 2. Cache na página de emergência

Após primeiro carregamento bem-sucedido: salvar no localStorage:
- Identificação (nome, foto, tipo sanguíneo) + Alergias + Medicamentos ativos
Se offline: mostrar dados do cache com banner "⚠ Você está offline. Estas informações podem não estar atualizadas."
Cache válido por 24 horas.

## 3. Acessibilidade mobile

- Mínimo de 44px de área de toque em todos os botões e ícones
- Fonte mínima de 16px em todos os inputs
- Labels visíveis em todos os campos (nunca só placeholder)
- Alto contraste: fundo branco + texto preto/cinza escuro
- Bottom sheet com handle visual (barra cinza no topo)
- Modais com botão X + fechar ao tocar fora

## 4. Disclaimer obrigatório

Adicionar em 3 locais:
1. Footer da página pública de emergência (/e/$token) — já implementado
2. Telas com IA ou resumo (P1)
3. Tela de medicamentos — footer abaixo da BottomNav, acima da nav

Texto padrão:
"O Amparo organiza informações e oferece apoio contextual. Ele não substitui médicos,
farmacêuticos, serviços de emergência ou orientação profissional de saúde."

## 5. Confirmação de exclusão de conta — único admin

Usar a função RPC get_solo_admin_families (criada no Prompt 1) — uma única query:

    const { data: soloAdminFamilies } = await supabase
      .rpc('get_solo_admin_families', { p_user_id: user.id })

    if (soloAdminFamilies && soloAdminFamilies.length > 0) {
      showSingleAdminWarning(soloAdminFamilies[0].family_id)
      return
    }
    // Só então mostrar modal de confirmação de exclusão

NÃO usar loop com múltiplas queries.

## 6. Tratamento de erros globais

- Erros de rede: toast "Sem conexão. Verifique sua internet."
- Erros de autenticação: redirecionar para /login
- Erros de permissão (RLS): toast "Você não tem permissão para esta ação."
- Erros de upload: toast com nome do arquivo + opção de tentar novamente
- Erros de validação: mensagem inline abaixo do campo, nunca modal

## 7. Otimizações de performance

- Lazy loading de imagens
- Paginação em listas longas (documentos, histórico): LIMIT/OFFSET ou cursor-based
- Imagens de paciente: thumbnail 80x80 no card, versão full só ao abrir perfil
- Prefetch das queries mais comuns ao fazer login

## 8. Validações client-side

- Campos obrigatórios em vermelho se vazios
- Datas: data de fim nunca antes de data de início
- Tipo sanguíneo: apenas valores da lista
- Arquivo: verificar tipo (JPEG, PNG, PDF) e tamanho (máximo 20MB) antes de subir

## 9. Resultado esperado

Ao concluir todos os 11 prompts, o Amparo deve:
- Ter banco com RLS ativo em todas as tabelas clínicas
- Ter soft delete funcionando em patients, medications, appointments, clinical_events, documents
- Ter upload correto (file_path, não file_url)
- Ter busca de documentos server-side via search_vector
- Ter página de emergência com cache e Server Function (createServerFn) para log
- Ter fluxo de convite com 3 branches
- Ter confirmação de realizado em 2 etapas
- Ter reordenação de contatos via botões ↑↓
- Não ter IMC em nenhuma tela
- Não ter swipe-to-reveal em nenhuma interação
- Ter FAB acima da bottom nav (bottom: 72px)
- Ter disclaimer em todos os locais corretos
- Ser funcional em celular com sinal fraco (pelo menos a emergência)
```

---

## Sequência de execução

| # | Prompt | O que cria | Testar antes de avançar |
|---|---|---|---|
| 0 | Contexto permanente | Configuração do projeto | — |
| 1 | Banco + Auth | Migration, RLS, triggers, estrutura | Verificar tabelas no Supabase |
| 2 | Onboarding | 5 passos de cadastro | Criar conta e família completos |
| 3 | Dashboard | Home com todos os blocos | Visualizar com dados do onboarding |
| 4 | Medicamentos | Lista + formulário + ações | Adicionar e arquivar medicamento |
| 5 | Agenda | Lista + formulário + 2 etapas | Criar e marcar consulta como realizada |
| 6 | Histórico | Linha do tempo + filtros | Registrar evento e filtrar |
| 7 | Documentos | Upload + busca + viewer | Subir foto e PDF, buscar |
| 8 | Emergência | Página pública + Edge Function | Testar link público sem login |
| 9 | Família | Convites + papéis + exclusão | Convidar membro pelo link |
| 10 | Perfil do paciente | Dados + alergias + contatos | Editar e reordenar contatos |
| 11 | Polimento | Cache, loading, acessibilidade | Testar offline na emergência |
