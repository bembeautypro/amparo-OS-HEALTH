# Amparo — Prompts para Lovable

Execute os prompts **em ordem**. Cada um constrói sobre o anterior.
Antes de começar: conecte o projeto Supabase no painel do Lovable
(Settings → Supabase → colar URL e anon key).

---

## PROMPT 1 — Fundação: Auth + Layout + Navegação

```
Crie um app React + TypeScript chamado Amparo. É um Family Health Hub
mobile-first para filhos adultos organizarem a saúde de pais idosos.

Stack obrigatória:
- Supabase Auth (email/senha + Google OAuth)
- Supabase Postgres (já configurado)
- Tailwind CSS
- shadcn/ui
- React Router DOM
- React Query para data fetching

Design:
- Mobile-first, mas responsivo até desktop
- Paleta: branco, cinza-50/100, azul-600 como cor primária,
  vermelho-500 apenas para emergência e alertas críticos
- Tipografia limpa, espaçamento generoso, sem poluição visual
- Tom humano, acolhedor e confiável — não clínico, não frio

Estrutura de rotas:
/ → redireciona para /login se não autenticado, /dashboard se autenticado
/login → tela de login (email/senha + botão Google)
/register → cadastro com nome completo, email, senha
/onboarding → fluxo de 5 passos (implementar depois)
/dashboard → home principal (implementar depois)
/familia/:familyId/* → rotas dos módulos (implementar depois)
/emergencia/:token → página pública de emergência (implementar depois)

Crie:
1. Cliente Supabase em src/integrations/supabase/client.ts usando
   VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY
2. AuthContext com useAuth() hook: user, session, signIn, signUp,
   signOut, loading
3. ProtectedRoute component que redireciona para /login se não autenticado
4. Layout principal com:
   - Bottom navigation bar no mobile (5 ícones: Home, Agenda,
     Documentos, Família, Perfil)
   - Sidebar colapsável no desktop com os mesmos itens
   - Header com nome do familiar ativo + avatar do usuário + botão
     de emergência vermelho no canto superior direito
5. Telas de /login e /register com validação de campos
6. Hook useFamilyContext() que mantém qual família e qual paciente
   estão selecionados no momento

Não implemente os módulos ainda, apenas a estrutura e navegação.
```

---

## PROMPT 2 — Onboarding (5 passos)

```
Implemente o fluxo de onboarding em /onboarding com 5 passos lineares.
Mostre barra de progresso no topo. Usuário não pode pular passos.
Ao concluir, redireciona para /dashboard.

Tabelas Supabase envolvidas: families, family_members, patients,
patient_conditions, patient_allergies, emergency_contacts, medications

Passo 1 — Boas-vindas:
  Título: "A saúde da sua família em um só lugar"
  Subtítulo: "Organize remédios, exames, consultas e histórico de
  quem você cuida."
  Botão único: "Começar organização"

Passo 2 — Criar família:
  Título: "Crie sua família"
  Campo: Nome da família (ex: "Família Silva")
  Select: Seu papel (filho(a), cônjuge, cuidador, outro)
  Ao avançar: INSERT em families + INSERT em family_members com
  role='admin' e status='active'

Passo 3 — Adicionar familiar cuidado:
  Título: "Quem você quer organizar primeiro?"
  Campos: Nome completo, Data de nascimento, Grau de parentesco,
  Upload de foto (opcional — bucket patient-photos)
  Ao avançar: INSERT em patients

Passo 4 — Dados críticos:
  Título: "Preencha o essencial para emergências"
  Campos:
  - Tipo sanguíneo (select: A+, A-, B+, B-, AB+, AB-, O+, O-, Não sei)
  - Alergias (tags input — INSERT em patient_allergies, severity='high')
  - Condições médicas (tags input — INSERT em patient_conditions)
  - Convênio: nome + número da carteirinha
  - Contato de emergência: nome + telefone (INSERT em emergency_contacts)
  Todos os campos são opcionais mas exibir label "Importante para
  emergências" nos campos de alergia e contato
  Ao avançar: UPDATE em patients + INSERTs nas tabelas acima

Passo 5 — Primeira ação:
  Título: "Quase pronto! O que você quer organizar agora?"
  4 opções com ícone em grid 2x2:
  - "Adicionar medicamento" → /familia/:id/medicamentos/novo
  - "Subir receita ou exame" → /familia/:id/documentos/novo
  - "Criar consulta" → /familia/:id/agenda/novo
  - "Ver meu painel" → /dashboard
```

---

## PROMPT 3 — Dashboard (Home)

```
Implemente a tela /dashboard como home principal do app.

Deve responder visualmente às 7 perguntas do usuário:
1. Quem está sendo cuidado?
2. Existe algo urgente?
3. Quais são os próximos compromissos?
4. Quais medicamentos estão ativos?
5. Há documentos recentes?
6. Existem pendências familiares?
7. Onde está o botão de emergência?

Layout mobile (cards empilhados verticalmente):

CARD 1 — Familiar ativo:
  Foto circular + Nome + Idade calculada + tipo sanguíneo
  Badges horizontais: alergias críticas (vermelho), condições ativas
  Botão vermelho proeminente "Emergência" com ícone de sirene
  Se família tem mais de 1 paciente: seletor de abas no topo

CARD 2 — Alertas (condicional, só aparece se houver):
  Fundo amarelo-50, borda amarela
  Exemplos: "Medicamento sem horário definido", "Perfil incompleto",
  "Consulta sem responsável"
  Query: montar lista de pendências cruzando dados das tabelas

CARD 3 — Próximos compromissos:
  Título "Agenda" + link "Ver tudo"
  Lista dos próximos 3 eventos da tabela appointments
  WHERE patient_id = ? AND scheduled_at > now() AND status != 'cancelled'
  ORDER BY scheduled_at ASC
  Cada item: ícone por tipo, data/hora, título, responsável (avatar)
  Se vazio: estado vazio com botão "Agendar consulta"

CARD 4 — Medicamentos ativos hoje:
  Título "Medicamentos de hoje" + link "Ver todos"
  Lista de medications WHERE status='active'
  Para cada um: nome, dosagem, horários do dia (do campo schedule jsonb)
  Badge "Tomado" / "Pendente" por horário via medication_logs
  Se vazio: estado vazio com botão "Cadastrar medicamento"

CARD 5 — Documentos recentes:
  Título "Documentos" + link "Ver todos"
  Lista dos últimos 3 da tabela documents ORDER BY created_at DESC
  Cada item: ícone por type, título, data
  Se vazio: estado vazio com botão "Subir documento"

CARD 6 — Família:
  Título "Família" + link "Gerenciar"
  Avatares em linha dos membros ativos (family_members WHERE status='active')
  Texto: "N membros com acesso"

FAB (Floating Action Button):
  Botão + fixo no canto inferior direito
  Ao clicar: bottom sheet com opções rápidas:
  "Novo medicamento", "Nova consulta", "Subir documento", "Novo evento"

Use React Query com useQuery para cada card independentemente
(carregam em paralelo). Mostrar skeleton loader enquanto carrega.
Não usar loading global — cada card carrega de forma independente.
```

---

## PROMPT 4 — Módulo Medicamentos

```
Implemente o módulo de medicamentos em /familia/:familyId/medicamentos

Tabelas: medications, medication_logs, medication_change_history

Tela principal /medicamentos:
  Abas: "Ativos" | "Pausados" | "Encerrados"
  Cada medicamento em card com:
  - Nome + dosagem + frequência
  - Próximos horários do dia (do schedule jsonb)
  - Status badge colorido
  - Botão de check "Marcar como tomado" para o horário atual
  - Swipe left no mobile para ações: Editar | Pausar | Encerrar
  Botão "+" no header para novo medicamento

Tela /medicamentos/novo e /medicamentos/:id/editar:
  Formulário em seções:
  Seção "Identificação":
    Nome do medicamento (text, obrigatório)
    Nome genérico/substituto (text, opcional)
    Dosagem (ex: "50mg") + Forma (comprimido, cápsula, gotas, etc)
    Upload de foto da caixa ou receita (bucket medication-photos)

  Seção "Posologia":
    Frequência: select (1x/dia, 2x/dia, 3x/dia, 4x/dia, conforme necessário, outro)
    Horários: para cada dose, time picker (gera array no campo schedule jsonb)
    Ex: frequência 2x/dia → 2 time pickers

  Seção "Período":
    Data de início (date picker, default hoje)
    Data de fim (date picker, opcional)
    Médico prescritor (text)

  Seção "Observações":
    Notas livres (textarea)

  Ao salvar edição: INSERT em medication_change_history registrando
  cada campo alterado (field_changed, old_value, new_value, changed_by)

Tela /medicamentos/:id:
  Detalhe completo do medicamento
  Seção "Histórico de tomadas": lista de medication_logs dos últimos 30 dias
  Calendário visual: dia verde = tomado, vermelho = perdido, cinza = futuro
  Seção "Histórico de alterações": medication_change_history em linha do tempo
  Botão "Encerrar medicamento" (status → 'ended') com confirmação
```

---

## PROMPT 5 — Módulo Agenda Médica

```
Implemente o módulo de agenda em /familia/:familyId/agenda

Tabela: appointments (e vinculação com documents, clinical_events)

Tela principal /agenda:
  Alternância de visualização: Lista | Calendário (toggle no header)

  Visualização Lista:
    Seções: "Hoje", "Esta semana", "Próximos", "Realizados"
    Cada item: ícone por type, data/hora, título, especialidade,
    responsável (avatar), status badge
    Tap no item → detalhe

  Visualização Calendário:
    Calendário mensal com pontos coloridos nos dias com eventos
    Tap no dia → lista de eventos do dia em bottom sheet

  Filtro por tipo (chips horizontais roláveis):
  Todos | Consulta | Exame | Retorno | Procedimento | Vacina

Tela /agenda/novo e /agenda/:id/editar:
  Campos:
  - Tipo (select com ícones): consulta, exame, retorno, procedimento,
    fisioterapia, vacina, outro
  - Título (text)
  - Data e horário (datetime picker)
  - Médico/profissional (text)
  - Especialidade (text)
  - Local (nome do local)
  - Endereço (text) + Link do mapa (URL, abre Google Maps)
  - Responsável por acompanhar (select dos family_members ativos)
  - Status: agendado | confirmado | realizado | cancelado | remarcado
  - Notas (textarea)
  - Documentos anexos (upload → bucket documents, INSERT em documents
    com appointment_id preenchido)

  Se type='return': mostrar select "Retorno de qual consulta?"
  (busca appointments realizados do mesmo paciente, preenche
  parent_appointment_id)

Tela /agenda/:id:
  Detalhe completo
  Seção de documentos anexos com preview/download
  Botão "Marcar como realizado" → abre modal para registrar:
    Orientações médicas recebidas, próximo retorno (cria novo appointment
    com parent_appointment_id), INSERT em clinical_events com
    type='consultation'
  Botão "Criar evento clínico" vinculado a esta consulta
```

---

## PROMPT 6 — Módulo Histórico Clínico

```
Implemente o histórico clínico em /familia/:familyId/historico

Tabela: clinical_events (com joins em documents, appointments)

Tela principal /historico:
  Linha do tempo vertical (timeline) ordenada por event_date DESC
  Cada evento na timeline:
    Ícone colorido por tipo (ex: cirurgia=vermelho, vacina=verde,
    consulta=azul, sintoma=amarelo)
    Data à esquerda
    Card à direita: título, descrição resumida, badge de severidade
    se severity = 'high' ou 'critical': borda colorida no card
    Documentos vinculados como thumbnails clicáveis

  Filtros (chips roláveis):
    Por tipo | Por severidade | Por data (range picker)

  Barra de busca: busca em title e description

  Botão "+" para novo evento

Tela /historico/novo e /historico/:id/editar:
  Campos:
  - Data do evento (date picker, default hoje)
  - Tipo (select com ícones):
    consulta, exame, internação, cirurgia, sintoma relevante,
    queda/acidente, alteração de medicamento, diagnóstico,
    retorno médico, crise, vacina, observação familiar, outro
  - Título (text, obrigatório)
  - Descrição (textarea)
  - Gravidade (select): baixa | média | alta | crítica
    Mostrar como color swatch: verde/amarelo/laranja/vermelho
  - Médico relacionado (text)
  - Tags (input de tags livre)
  - Vincular à consulta (select de appointments, opcional)
  - Documentos (upload → bucket documents, INSERT em documents
    com clinical_event_id preenchido)

Tela /historico/:id:
  Visualização completa do evento
  Galeria de documentos vinculados
  Info de "Registrado por" + data/hora do created_at
  Botão editar (apenas para admin e editor)
```

---

## PROMPT 7 — Módulo Documentos

```
Implemente o módulo de documentos em /familia/:familyId/documentos

Tabela: documents
Storage bucket: documents (path: {family_id}/{patient_id}/{uuid}.{ext})

Tela principal /documentos:
  Grid de cards (2 colunas no mobile, 3 no desktop)
  Cada card: thumbnail (PDF mostra ícone de PDF), título, tipo badge,
  data do documento

  Filtros laterais (desktop) / bottom sheet (mobile):
    Por tipo: Receita | Exame | Laudo | Pedido médico | Carteirinha |
    Documento pessoal | Alta hospitalar | Vacina | Outro
    Por data: range picker
    Por médico/instituição: text filter

  Barra de busca: busca em title, doctor_name, institution, tags
  (busca local nos dados já carregados)

  Botão "+" para upload

Tela /documentos/novo:
  Passo 1 — Upload:
    Área de drag & drop grande + botão "Selecionar arquivo"
    Aceitar: PDF, JPG, PNG, WEBP, TIFF
    Limite: 50MB
    Mostrar preview do arquivo selecionado
    Progress bar durante upload para bucket documents
    Após upload: salvar file_path, file_mime_type, file_size_bytes

  Passo 2 — Classificar:
    Campos auto-preenchidos se OCR disponível (implementar depois):
    - Título (text, obrigatório)
    - Tipo (select com ícones)
    - Data do documento (date picker)
    - Médico/profissional (text)
    - Instituição/clínica (text)
    - Validade (date picker, opcional — campo expiry_date)
    - Tags (input de tags)
    - Observações (textarea)
    - Vincular a consulta (select de appointments, opcional)
    - Vincular a evento clínico (select de clinical_events, opcional)

  Ao salvar: INSERT em documents com todos os campos

Tela /documentos/:id:
  Visualizador de documento:
    PDF: iframe ou react-pdf
    Imagem: img com zoom
  Painel lateral com todos os metadados
  Botão download (gerar signed URL via Supabase Storage)
  Botão compartilhar (gerar link temporário)
  Botão editar metadados
  Botão excluir (soft delete — apenas admin)
```

---

## PROMPT 8 — Central de Emergência

```
Implemente a Central de Emergência. Este é o módulo mais crítico do app.

Tabelas: emergency_links, access_logs
Dados exibidos de: patients, patient_allergies, patient_conditions,
emergency_contacts, medications (WHERE status='active'), documents

PARTE A — Botão e modal interno (usuário autenticado):

O botão vermelho "Emergência" no header abre um bottom sheet/modal com:
  Card de resumo emergencial do paciente selecionado:
  ┌──────────────────────────────────────┐
  │ [Foto] João Silva · 80 anos · O+     │
  │ ⚠ ALERGIAS: Penicilina (grave)      │
  │ 🏥 Unimed · 0123456789              │
  │ 🏨 Hospital das Clínicas            │
  │ 💊 Losartana 50mg · Metformina 850mg│
  │ 📞 Maria (filha): (11) 99999-9999   │
  │ 📞 Dr. Carlos: (11) 88888-8888      │
  └──────────────────────────────────────┘

  Abaixo do card:
  Botão primário: "Gerar link de emergência"
  Botão secundário: "Gerar QR Code"
  Link de acesso rápido se já existir link ativo

  Ao clicar "Gerar link":
    INSERT em emergency_links (token gerado pelo banco via default,
    expires_at = now() + 24h, is_active=true)
    Mostrar URL: https://app.amparo.com.br/emergencia/{token}
    Botão "Copiar link" + "Compartilhar via WhatsApp"
    Opção de alterar expiração: 24h | 72h | 7 dias | Sem expiração

  Ao clicar "Gerar QR Code":
    Gerar QR Code da URL de emergência com a lib qrcode.react
    Opção de baixar como PNG ou imprimir

PARTE B — Página pública /emergencia/:token (sem autenticação):

Esta página é acessível sem login. Ao carregar:
  1. Buscar emergency_links WHERE token = :token
  2. Validar: is_active=true AND (expires_at IS NULL OR expires_at > now())
  3. Se inválido: mostrar tela "Link expirado ou inválido"
  4. Se válido: buscar todos os dados do patient_id relacionado
  5. INSERT em access_logs (patient_id, emergency_link_id, action='emergency_view',
     ip_address via header)
  6. UPDATE emergency_links: access_count+1, last_accessed_at=now()

  Layout da página pública (otimizado para mobile, fundo branco limpo):

  TOPO — Banner vermelho:
    "⚠ INFORMAÇÕES DE EMERGÊNCIA — Amparo"
    Nome do paciente em fonte grande

  SEÇÃO 1 — Identificação:
    Foto + Nome + Idade + Tipo sanguíneo (destaque grande)

  SEÇÃO 2 — ⚠ Alergias (se existir — fundo vermelho-50):
    Lista com severidade

  SEÇÃO 3 — Condições médicas ativas

  SEÇÃO 4 — 💊 Medicamentos ativos:
    Nome + dosagem de cada um

  SEÇÃO 5 — 🏥 Convênio:
    Nome + número da carteirinha

  SEÇÃO 6 — 📞 Contatos de emergência:
    Nome + relação + telefone (botão de ligação direto)
    Médico principal

  SEÇÃO 7 — 🏨 Hospital de preferência

  RODAPÉ:
    "Informações fornecidas pelo sistema Amparo"
    Data/hora de geração do link
    Disclaimer: "Este resumo é para uso emergencial. Consulte
    sempre um profissional de saúde."

  A página deve carregar rápido mesmo com conexão ruim.
  Não usar carregamento lazy nos dados críticos.
  CSS inline ou crítico embutido para não depender de bundle grande.
```

---

## PROMPT 9 — Módulo Família e Permissões

```
Implemente o módulo de família em /familia/:familyId/membros

Tabelas: family_members, invitations, profiles, access_logs

Tela principal /membros:
  Lista de membros ativos com:
    Avatar + Nome (de profiles) + role badge + status
    Roles com cores: Admin=roxo, Editor=azul, Visualizador=cinza,
    Cuidador=verde, Médico=teal
  Botão "Convidar pessoa" no header
  Seção separada "Convites pendentes" (invitations WHERE status='pending')

  Tap em membro → bottom sheet com opções:
    Alterar papel (select) — apenas admin pode
    Remover da família — apenas admin pode, com confirmação
    Ver atividade recente (access_logs)

Tela modal "Convidar pessoa":
  Campo: Email
  Select: Papel que terá acesso
    Admin — Gerencia tudo
    Editor — Adiciona e edita dados
    Visualizador — Apenas consulta
    Cuidador — Rotina, medicamentos e agenda
    Médico — Acesso temporário a resumo e documentos

  Ao confirmar:
    INSERT em invitations (email, role, invited_by, expires_at=+7 dias)
    Exibir link do convite para copiar/compartilhar no WhatsApp
    (rota: /convite/:token)

Tela pública /convite/:token:
  Buscar invitation WHERE token = :token AND status='pending'
  AND expires_at > now()
  Se inválido: "Convite expirado"
  Se válido: mostrar nome da família + papel que receberá
  Botão "Aceitar convite":
    Se usuário já logado: INSERT em family_members + UPDATE invitation status='accepted'
    Se não logado: redirecionar para /register?invite=:token
    (após registro, aceitar automaticamente)

Tela /membros/atividade:
  Log de atividade da família
  Busca em access_logs WHERE family_id = ?
  ORDER BY created_at DESC
  Filtro por membro e por tipo de ação
  Cada item: avatar do usuário, descrição da ação, data/hora
```

---

## PROMPT 10 — Perfil do Familiar (Página completa)

```
Implemente a página de perfil completo do familiar em
/familia/:familyId/pacientes/:patientId

Tabelas: patients, patient_conditions, patient_allergies, emergency_contacts

Layout em abas ou seções expansíveis:

SEÇÃO 1 — Identificação:
  Foto (clicável para trocar — upload para bucket patient-photos)
  Nome completo (editável inline)
  Data de nascimento → idade calculada em tempo real
  Tipo sanguíneo (badge colorido)
  Altura e peso (com IMC calculado automaticamente)
  Observações críticas (textarea)

SEÇÃO 2 — Convênio e hospital:
  Nome do convênio + número da carteirinha
  Hospital de preferência
  Médico principal
  Campos editáveis com ícone de lápis

SEÇÃO 3 — Alergias:
  Lista de patient_allergies com badges de severidade:
    Crítica=vermelho, Alta=laranja, Média=amarelo, Baixa=cinza
  Botão "+" para adicionar nova alergia
  Tap em alergia: editar/remover

SEÇÃO 4 — Condições médicas:
  Lista de patient_conditions com status (ativa/inativa)
  Data de diagnóstico
  Botão "+" para adicionar

SEÇÃO 5 — Contatos de emergência:
  Lista ordenada por priority
  Cada contato: nome, relação, telefone (botão ligar), email
  Drag to reorder para alterar prioridade
  Botão "+" para adicionar

SEÇÃO 6 — Resumo rápido (read-only):
  Card compacto mostrando o que aparecerá na tela de emergência
  Botão "Ver emergência completa"

Todas as seções:
  Edição inline com botão "Salvar" por seção (não salvar tudo de uma vez)
  Mostrar "Última atualização: X" em cada seção
  Registrar em access_logs action='patient_update' a cada edição
```

---

## PROMPT 11 — Polimentos finais e estados vazios

```
Aplique os seguintes polimentos no app Amparo:

1. ESTADOS VAZIOS:
   Cada módulo sem dados deve ter uma ilustração simples (SVG inline)
   e texto encorajador + botão de ação primária.
   Exemplos:
   - Medicamentos vazios: "Nenhum medicamento cadastrado ainda.
     Adicione o primeiro para começar a organizar."
   - Agenda vazia: "Nenhum compromisso agendado."
   - Documentos vazios: "Sua biblioteca de documentos está vazia.
     Suba o primeiro exame ou receita."

2. FEEDBACK DE AÇÕES:
   Toast notifications (sonner ou react-hot-toast) para:
   - Sucesso: verde, 3 segundos
   - Erro: vermelho, 5 segundos com botão "Tentar novamente"
   - Loading: spinner inline nos botões durante requisição
   Nunca desabilitar botão sem mostrar estado de loading.

3. CONFIRMAÇÕES DESTRUTIVAS:
   Qualquer ação de deletar/remover/encerrar:
   Modal de confirmação com texto descritivo do que será removido.
   Botão de confirmação em vermelho.

4. OFFLINE / ERRO DE REDE:
   Banner amarelo no topo: "Sem conexão — algumas funções podem
   não estar disponíveis"
   Dados já carregados permanecem visíveis (React Query cache)

5. RESPONSIVIDADE:
   Testar e ajustar breakpoints para:
   - Mobile 375px (iPhone SE)
   - Mobile 390px (iPhone 14)
   - Tablet 768px (iPad)
   - Desktop 1280px

6. ACESSIBILIDADE BÁSICA:
   - Todos os botões com aria-label descritivo
   - Contraste mínimo 4.5:1 nos textos
   - Fontes mínimas: 16px para corpo, 14px para labels
   - Tap targets mínimos: 44x44px

7. PÁGINA DE PERFIL DO USUÁRIO (/perfil):
   Nome completo (editável — UPDATE em profiles)
   Foto (upload)
   Email (read-only — vem do auth)
   Telefone
   Botão "Sair" com confirmação
   Botão "Excluir minha conta" (vermelho, dupla confirmação)

8. SEO / META TAGS:
   - Título: "Amparo — A central de saúde da sua família"
   - Description: "Organize remédios, exames, consultas e histórico
     médico de quem você cuida."
   - Favicon e ícones PWA
   - manifest.json para instalação como PWA no celular
```

---

## Ordem de execução recomendada

| # | Prompt | O que entrega |
|---|--------|---------------|
| 1 | Fundação | Auth, layout, navegação |
| 2 | Onboarding | Primeiro acesso e cadastro |
| 3 | Dashboard | Home com todos os cards |
| 4 | Medicamentos | Módulo completo |
| 5 | Agenda | Módulo completo |
| 6 | Histórico | Linha do tempo clínica |
| 7 | Documentos | Upload e biblioteca |
| 8 | Emergência | Módulo diferencial do MVP |
| 9 | Família | Convites e permissões |
| 10 | Perfil do familiar | Página detalhada do paciente |
| 11 | Polimentos | Estados vazios, toasts, PWA |

## Dicas para usar no Lovable

- Execute um prompt por vez e valide o resultado antes de avançar
- Se algo não ficar correto, use o chat do Lovable para ajustar
  antes de ir para o próximo prompt
- Após os prompts 1-3, já é possível mostrar para usuários beta
- O prompt 8 (Emergência) é o mais sensível — valide bem o RLS
  da página pública antes de publicar
