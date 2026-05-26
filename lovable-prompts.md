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
/convite/:token → página pública de convite (implementar depois)
/perfil → perfil do usuário logado (implementar depois)

Crie:
1. Cliente Supabase em src/integrations/supabase/client.ts usando
   VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY

2. AuthContext com useAuth() hook: user, session, signIn, signUp,
   signOut, loading

3. ProtectedRoute component que redireciona para /login se não autenticado

4. Layout principal com:
   - Bottom navigation bar no mobile com 5 ícones:
     Home | Medicamentos | Agenda | Documentos | Família
     (Perfil do usuário fica acessível pelo avatar no header, não na nav)
   - Sidebar colapsável no desktop com os mesmos 5 itens + link para Perfil
   - Header com:
     · Seletor do familiar ativo (nome + foto em miniatura) — sticky,
       visível em todas as telas do app
     · Avatar do usuário logado no canto superior direito
       (tap → menu: "Meu perfil" e "Sair")
     · NÃO incluir botão de emergência no header — ele fica apenas
       no dashboard para não criar duplicidade confusa

5. Telas de /login e /register com validação de campos

6. Hook useFamilyContext() que mantém qual família (familyId) e qual
   paciente (patientId) estão selecionados no momento — persiste no
   localStorage para sobreviver a reloads

Não implemente os módulos ainda, apenas a estrutura e navegação.
```

---

## PROMPT 2 — Onboarding (5 passos)

```
Implemente o fluxo de onboarding em /onboarding com 5 passos lineares.
Mostre barra de progresso numérica (ex: "Passo 2 de 5") no topo.

REGRA DE NAVEGAÇÃO:
- Passos 1, 2 e 3: obrigatórios, sem opção de pular
- Passos 4 e 5: mostrar link "Preencher depois" no canto inferior esquerdo
- Ao concluir (ou pular os passos opcionais): redireciona para /dashboard

Tabelas Supabase envolvidas: families, family_members, patients,
patient_conditions, patient_allergies, emergency_contacts

---

Passo 1 — Boas-vindas (obrigatório):
  Ilustração SVG simples centrada (família / coração / proteção — inline no código)
  Título: "A saúde da sua família em um só lugar"
  Subtítulo: "Organize remédios, exames, consultas e histórico de
  quem você cuida."
  Botão único: "Começar organização"

---

Passo 2 — Criar família (obrigatório):
  Título: "Crie sua família"
  Campo: Nome da família (ex: "Família Silva") — obrigatório
  Select: Seu papel → filho(a) | cônjuge | cuidador | outro
  Ao avançar: INSERT em families + INSERT em family_members com
  role='admin' e status='active'

---

Passo 3 — Adicionar familiar cuidado (obrigatório):
  Título: "Quem você quer organizar primeiro?"
  Campos:
  - Nome completo (obrigatório)
  - Data de nascimento (date picker)
  - Grau de parentesco (text: "pai", "mãe", "avó"...)
  - Foto (opcional — botão "Adicionar foto" que abre:
    · No mobile: escolha entre "Câmera" e "Galeria"
    · No desktop: file picker padrão
    Upload para bucket patient-photos)
  Ao avançar: INSERT em patients

---

Passo 4 — Dados críticos (opcional — exibir "Preencher depois"):
  Título: "Preencha o essencial para emergências"
  Subtítulo em cinza: "Esses dados aparecem na Central de Emergência.
  Você pode adicionar agora ou depois."

  Usar separadores visuais com títulos de seção:

  ── Para emergências ──────────────────────
  Tipo sanguíneo (select: A+, A-, B+, B-, AB+, AB-, O+, O-, Não sei)

  Alergias conhecidas (campo "Importante para emergências"):
    Input: digitar + pressionar Enter para adicionar como tag
    Cada alergia adicionada aparece como badge removível
    INSERT em patient_allergies com severity='high'
    Exemplo de placeholder: "Ex: Penicilina, AAS, amendoim..."

  Condições médicas:
    Mesmo padrão de tags
    INSERT em patient_conditions com status='active'
    Exemplo: "Ex: Hipertensão, Diabetes tipo 2..."

  ── Convênio ──────────────────────────────
  Nome do convênio (text)
  Número da carteirinha (text)

  ── Contato de emergência (Importante) ────
  Nome do contato (text)
  Telefone (text com máscara)
  INSERT em emergency_contacts com priority=1

  Todos os campos são opcionais neste passo.

---

Passo 5 — Primeira ação (opcional — exibir "Preencher depois"):
  Título: "Quase pronto! O que você quer organizar agora?"
  4 opções com ícone em grid 2x2:
  - "Adicionar medicamento" → /familia/:familyId/medicamentos/novo
  - "Subir receita ou exame" → /familia/:familyId/documentos/novo
  - "Criar consulta" → /familia/:familyId/agenda/novo
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

SELETOR DE PACIENTE (sticky):
  Se a família tem mais de 1 paciente: exibir seletor ACIMA dos cards,
  fixo (sticky top) abaixo do header, visível mesmo ao rolar a página.
  Formato: abas horizontais com foto + nome curto de cada paciente.
  O seletor atualiza todos os cards ao trocar de paciente.
  Se só tem 1 paciente: não exibir o seletor (sem ocupar espaço).

Layout mobile (cards empilhados verticalmente com gap de 12px):

---

CARD 1 — Familiar ativo:
  Foto circular (80px) + Nome completo + Idade calculada + tipo sanguíneo
  Badges em linha: alergias críticas (fundo vermelho, texto branco),
  condições ativas (fundo azul-100, texto azul-800)
  Botão vermelho proeminente "🚨 Emergência" centralizado abaixo dos badges
  Este é o ÚNICO botão de emergência do app — não duplicar no header.

CARD 2 — Alertas (condicional — só renderizar se houver pendências):
  Fundo amarelo-50, borda esquerda amarela-400, ícone ⚠
  Lista de pendências geradas por query cruzada:
  - Medicamento ativo sem horário definido (schedule IS NULL)
  - Perfil sem contato de emergência
  - Consulta agendada sem responsável definido
  - Perfil sem tipo sanguíneo
  - Perfil sem alergias registradas
  Cada item clicável leva direto ao local de correção.

CARD 3 — Próximos compromissos:
  Header: "Agenda" + link "Ver tudo" (→ /familia/:id/agenda)
  Query: appointments WHERE patient_id = ? AND scheduled_at > now()
  AND status NOT IN ('cancelled', 'done') ORDER BY scheduled_at ASC LIMIT 3
  Cada item: ícone por tipo, data/hora formatada ("Amanhã, 14h" ou
  "Sex 23/05, 10h"), título, avatar do responsável
  Estado vazio: ícone + "Nenhum compromisso agendado" + botão "Agendar"

CARD 4 — Medicamentos de hoje:
  Header: "Medicamentos de hoje" + link "Ver todos"
  Query: medications WHERE patient_id = ? AND status = 'active'
  Para cada um: nome + dosagem + horários do dia (do schedule jsonb)
  Se schedule IS NULL: exibir badge "Sem horário" em amarelo
  Badge por horário: "Tomado" (verde) ou "Pendente" (cinza) via medication_logs
  Estado vazio: ícone + "Nenhum medicamento cadastrado" + botão "Cadastrar"

CARD 5 — Documentos recentes:
  Header: "Documentos" + link "Ver todos"
  Query: documents WHERE patient_id = ? ORDER BY created_at DESC LIMIT 3
  Cada item: ícone por type, título, data formatada
  Estado vazio: ícone + "Nenhum documento enviado" + botão "Subir documento"

CARD 6 — Família:
  Header: "Família" + link "Gerenciar"
  Avatares em linha (máx 5, depois "+N") dos family_members WHERE status='active'
  Texto: "N membros com acesso"

---

FAB (Floating Action Button):
  Botão "+" fixo, posicionado bottom: 72px (ACIMA da bottom nav), right: 16px
  Ao clicar: bottom sheet com 4 opções:
  "💊 Novo medicamento" | "📅 Nova consulta" |
  "📄 Subir documento" | "📋 Novo evento clínico"

---

Performance:
  useQuery para cada card independentemente (carregam em paralelo).
  Skeleton loader por card enquanto carrega.
  Não usar loading global — cada card carrega de forma independente.
```

---

## PROMPT 4 — Módulo Medicamentos

```
Implemente o módulo de medicamentos em /familia/:familyId/medicamentos

Tabelas: medications, medication_logs, medication_change_history

---

Tela principal /medicamentos:
  Abas: "Ativos" | "Pausados" | "Encerrados"
  Cada medicamento em card com:
  - Nome + dosagem + frequência
  - Próximos horários do dia (do schedule jsonb)
  - Status badge colorido
  - Botão de check "✓ Marcar como tomado" para o horário atual

  AÇÕES POR MEDICAMENTO:
  NÃO usar swipe (pouco intuitivo no mobile web).
  Usar botão "⋮" (três pontos verticais) no canto superior direito
  do card → abre bottom sheet com:
  - Editar
  - Pausar (status → 'paused')
  - Encerrar (status → 'ended', com confirmação)
  - Ver histórico completo

  Botão "+" no header para novo medicamento.

---

Tela /medicamentos/novo e /medicamentos/:id/editar:
  Formulário em seções com título de seção separador:

  ── Identificação ─────────────────────────
  Nome do medicamento (text, obrigatório)
  Nome genérico/substituto (text, opcional)
  Dosagem: campo de texto livre (ex: "50mg", "10 gotas")
  Forma: select (comprimido, cápsula, gotas, xarope, injeção,
  adesivo, outro)
  Upload de foto da caixa ou receita:
    · Mobile: "📷 Câmera" ou "🖼 Galeria" (input accept="image/*")
    · Desktop: file picker + preview
    Upload para bucket medication-photos

  ── Posologia ─────────────────────────────
  Frequência: select (1x/dia, 2x/dia, 3x/dia, 4x/dia,
  conforme necessário, outro)
  Horários: renderizar N time pickers baseado na frequência escolhida
    · 1x/dia → 1 time picker
    · 2x/dia → 2 time pickers
    · conforme necessário → nenhum time picker (schedule = null)
    · outro → input de texto livre para descrever
  Os horários são salvos como jsonb: [{"time": "08:00"}, {"time": "20:00"}]

  ── Período ───────────────────────────────
  Data de início (date picker, default: hoje)
  Data de fim (date picker, opcional — deixar em branco = uso contínuo)
  Médico prescritor (text)

  ── Observações ───────────────────────────
  Notas livres (textarea, placeholder: "Tomar com água, evitar sol...")

  Ao salvar EDIÇÃO (não criação): INSERT em medication_change_history
  para cada campo alterado:
  { field_changed, old_value, new_value, changed_by: auth.uid() }

---

Tela /medicamentos/:id:
  Nome + dosagem + todos os campos em modo leitura
  Botão "Editar" no header

  Seção "Histórico de tomadas — últimos 30 dias":
    Calendário visual compacto (grade de dias):
    · Verde: tomado (medication_logs.status = 'taken')
    · Vermelho: perdido (status = 'missed')
    · Cinza claro: sem registro ou futuro
    · Sem cor: antes do start_date do medicamento
    Abaixo do calendário: lista dos últimos 10 logs com horário e
    quem registrou (logged_by → profiles.full_name)

  Seção "Histórico de alterações":
    medication_change_history em linha do tempo
    Cada item: campo alterado, valor antigo → valor novo, quem alterou, quando

  Botão "Encerrar medicamento" (vermelho, ao final da tela):
    Modal de confirmação: "Encerrar [nome]? O histórico será preservado."
    Confirmar → status = 'ended'
```

---

## PROMPT 5 — Módulo Agenda Médica

```
Implemente o módulo de agenda em /familia/:familyId/agenda

Tabela: appointments (vinculação com documents, clinical_events)

---

Tela principal /agenda:
  Toggle no header: "Lista" | "Calendário"

  Visualização Lista:
    Seções agrupadas: "Hoje" | "Esta semana" | "Próximos" | "Realizados"
    Cada item: ícone por type, data/hora, título, especialidade,
    avatar do responsável, status badge
    Tap → detalhe

  Visualização Calendário:
    Calendário mensal, pontos coloridos nos dias com eventos
    Tap no dia → bottom sheet "peek" (meia tela) com lista dos eventos
    do dia; tap no evento → detalhe completo

  Filtro por tipo (chips horizontais roláveis abaixo do toggle):
  Todos | Consulta | Exame | Retorno | Procedimento | Vacina | Fisioterapia

---

Tela /agenda/novo e /agenda/:id/editar:
  Tipo (select com ícones): consulta, exame, retorno, procedimento,
  fisioterapia, vacina, outro

  Se type = 'return': mostrar campo adicional
  "Retorno de qual consulta?" (select de appointments WHERE status='done'
  do mesmo paciente, preenche parent_appointment_id)

  Título (text, obrigatório)
  Data e horário (datetime picker)
  Médico/profissional (text)
  Especialidade (text)
  Local — nome do local (text)
  Endereço (text)
  Link do mapa (URL — ao salvar, abrir com Google Maps)
  Responsável por acompanhar (select dos family_members com status='active')
  Notas (textarea)
  Documentos anexos (upload → bucket documents, INSERT em documents
  com appointment_id preenchido)

  NOTA: NÃO incluir campo "Status" no formulário de criação.
  Novos compromissos sempre começam como 'scheduled'.
  Status é alterado apenas na tela de detalhe.

---

Tela /agenda/:id:
  Todos os campos em modo leitura + botão "Editar" no header
  Seção de documentos anexos com preview/download

  Botão "Marcar como realizado":
    PASSO 1 — Confirmar (tap no botão):
      Modal simples: "Marcar [título] como realizado?"
      Confirmar → status = 'done', INSERT em clinical_events com
      type='consultation', appointment_id = this.id
      Toast: "Consulta registrada no histórico ✓"

    PASSO 2 — Opcional (banner após confirmação, NÃO bloqueia o usuário):
      Banner azul: "Quer registrar as orientações médicas desta consulta?"
      Botão "Registrar agora" → abre formulário de clinical_event
      pré-preenchido com appointment_id
      Botão "Agora não" → dismiss do banner

  Botão "Agendar retorno" (secundário):
    Abre /agenda/novo pré-preenchido com type='return' e
    parent_appointment_id = this.id
```

---

## PROMPT 6 — Módulo Histórico Clínico

```
Implemente o histórico clínico em /familia/:familyId/historico

Tabela: clinical_events (com joins em documents, appointments)

---

Tela principal /historico:
  Barra de busca no topo (sempre visível)
  Busca server-side com debounce de 300ms em title e description

  Botão "Filtrar" ao lado da busca → abre bottom sheet com:
  - Por tipo (checkboxes múltiplos)
  - Por severidade (checkboxes múltiplos)
  - Por período (range picker de datas)
  - Botão "Aplicar filtros"
  (Não usar chips permanentes — economizam espaço vertical)

  Linha do tempo vertical abaixo da busca:
  Layout: data curta à esquerda (ex: "15 mar") + card à direita
  Ícone colorido por tipo no início do card:
    cirurgia=vermelho, vacina=verde, consulta=azul,
    internação=roxo, sintoma=amarelo, queda=laranja, outro=cinza
  Card: título, descrição resumida (máx 2 linhas), badge de severidade
  Se severity = 'high' ou 'critical': borda esquerda colorida no card
  Thumbnails clicáveis de documentos vinculados abaixo da descrição

  Botão "+" fixo, bottom: 72px, right: 16px para novo evento

---

Tela /historico/novo e /historico/:id/editar:
  Data do evento (date picker, default: hoje)
  Tipo (select com ícones):
    consulta, exame, internação, cirurgia, sintoma relevante,
    queda/acidente, alteração de medicamento, diagnóstico,
    retorno médico, crise, vacina, observação familiar, outro
  Título (text, obrigatório)
  Descrição (textarea)
  Gravidade — exibir como 4 botões com cor de fundo:
    [🟢 Baixa] [🟡 Média] [🟠 Alta] [🔴 Crítica]
    (não usar select — a visualização de cor ajuda na escolha)
  Médico relacionado (text)
  Tags (input: digitar + Enter para adicionar como badge removível)
  Vincular à consulta (select de appointments, opcional)
  Documentos:
    · Mobile: "📷 Câmera" | "🖼 Galeria" | "📄 Arquivo"
    · Desktop: drag & drop + file picker
    Upload → bucket documents com clinical_event_id preenchido

---

Tela /historico/:id:
  Visualização completa com todos os campos
  Galeria de documentos vinculados em grid 2 colunas
  Rodapé: "Registrado por [nome]" + data/hora do created_at
  Botão "Editar" visível apenas para roles: admin, editor
```

---

## PROMPT 7 — Módulo Documentos

```
Implemente o módulo de documentos em /familia/:familyId/documentos

Tabela: documents
Storage bucket: documents (path: {family_id}/{patient_id}/{uuid}.{ext})

---

Tela principal /documentos:
  Barra de busca no topo — busca SERVER-SIDE com debounce de 300ms.
  Query Supabase: filtrar em title, doctor_name, institution e tags
  NÃO fazer busca local — carregar todos os documentos e filtrar no
  cliente é inviável com volume crescente.

  Botão "Filtrar" ao lado da busca → bottom sheet com:
  - Por tipo: Receita | Exame | Laudo | Pedido médico | Carteirinha |
    Documento pessoal | Alta hospitalar | Vacina | Outro
  - Por período (range picker)
  - Por médico/instituição (text)

  Visualização padrão: LISTA no mobile (1 coluna)
    Cada item: ícone por tipo, título, data, badge de tipo
  Visualização opcional: GRID (2 colunas no mobile, 3 no desktop)
    Cada card: thumbnail para imagens, ícone de PDF para PDFs
  Toggle lista/grid no header

  Botão "+" para upload

---

Tela /documentos/novo (2 passos):

  PASSO 1 — Upload:
    No MOBILE: exibir 3 botões grandes empilhados:
      [📷 Tirar foto com câmera]
        input: type="file" accept="image/*" capture="environment"
      [🖼 Escolher da galeria]
        input: type="file" accept="image/*,application/pdf"
      [📄 Selecionar arquivo]
        input: type="file" accept="image/*,application/pdf,.tiff"

    No DESKTOP: área de drag & drop grande +
    botão "Selecionar arquivo" centralizado

    Limite: 50MB. Mostrar preview:
    - Imagem: img com max-height: 200px
    - PDF: ícone de PDF + nome do arquivo + tamanho
    Progress bar durante upload para bucket documents
    Após upload bem-sucedido: salvar file_path, file_mime_type,
    file_size_bytes → avançar para Passo 2

  PASSO 2 — Classificar:
    Campos OBRIGATÓRIOS (sempre visíveis):
    - Título (text — obrigatório)
    - Tipo (select com ícones — obrigatório)

    Campos OPCIONAIS (inicialmente colapsados — link "Adicionar mais detalhes"):
    - Data do documento (date picker)
    - Médico/profissional (text)
    - Instituição/clínica (text)
    - Validade (date picker — campo expiry_date)
    - Tags (input de tags)
    - Observações (textarea)
    - Vincular a consulta (select de appointments)
    - Vincular a evento clínico (select de clinical_events)

    Ao salvar: INSERT em documents com todos os campos preenchidos

---

Tela /documentos/:id:
  Visualizador de documento:
    IMAGEM: img com pinch-to-zoom (usar biblioteca de zoom touch)
    PDF: usar biblioteca react-pdf para renderizar inline
      Em caso de falha no render: mostrar botão "Abrir PDF"
      que executa window.open(signedUrl, '_blank') como fallback
    Gerar URL via Supabase Storage createSignedUrl (expiração: 1 hora)

  Metadados em painel abaixo (mobile) ou lateral (desktop):
    Tipo, data, médico, instituição, tags, validade

  Ações (botões no rodapé):
    "⬇ Baixar" — gerar nova signed URL e iniciar download
    "✏ Editar dados" — abre formulário inline de metadados
    "🗑 Excluir" — apenas admin, modal de confirmação, soft delete
      (não remover do storage imediatamente — marcar como deleted_at)
```

---

## PROMPT 8 — Central de Emergência

```
Implemente a Central de Emergência. Este é o módulo mais crítico do app.

Tabelas: emergency_links, access_logs
Dados de: patients, patient_allergies, patient_conditions,
emergency_contacts, medications (WHERE status='active')

---

PARTE A — Modal interno (usuário autenticado):

O botão vermelho "🚨 Emergência" do dashboard abre um MODAL FULL-SCREEN
(não bottom sheet — em pânico o usuário não pode perder tempo em UI parcial).

O modal tem duas abas no topo: "Resumo" | "Compartilhar"

ABA "Resumo" — informações críticas do paciente:
  Layout otimizado para leitura rápida, fonte grande:

  ┌──────────────────────────────────────────┐
  │ [Foto] João Silva  80 anos  O+           │
  ├──────────────────────────────────────────┤
  │ ⚠ ALERGIAS                              │
  │   • Penicilina (GRAVE)                  │
  │   • AAS (ALTA)                          │
  ├──────────────────────────────────────────┤
  │ 💊 MEDICAMENTOS ATIVOS                  │
  │   • Losartana 50mg                      │
  │   • Metformina 850mg                    │
  ├──────────────────────────────────────────┤
  │ 🏥 Unimed · 0123456789                  │
  │ 🏨 Hospital das Clínicas               │
  ├──────────────────────────────────────────┤
  │ 📞 Maria (filha) · (11) 99999-9999     │
  │    [Ligar agora]                        │
  │ 📞 Dr. Carlos · (11) 88888-8888        │
  │    [Ligar agora]                        │
  └──────────────────────────────────────────┘

  Botão "Ligar agora" usa href="tel:+5511..." para iniciar chamada direta.

ABA "Compartilhar" — gerar link e QR Code:
  Se já existe link ativo: exibir direto com opções de compartilhamento.
  Se não existe: botão "Gerar link de emergência".

  Ao gerar:
    INSERT em emergency_links
    (token gerado pelo banco via DEFAULT, expires_at = now() + 7 days)
    IMPORTANTE: usar expires_at = 7 dias como padrão — 24h é insuficiente
    para internações. O usuário pode ajustar.

  Exibir link gerado + opções de expiração:
    [24 horas] [72 horas] [7 dias] [Sem expiração] ← seleção por chip

  Botões de ação:
    [📋 Copiar link]
    [💬 Compartilhar no WhatsApp]
      → href="https://wa.me/?text=Informações+de+emergência+de+[nome]:+[url]"
    [⬇ Baixar QR Code como PNG]
    [🖨 Imprimir QR Code]

  QR Code gerado com biblioteca qrcode.react.
  QR Code deve ser grande o suficiente para ser lido a distância (min 200x200px).

---

PARTE B — Página pública /emergencia/:token (SEM autenticação):

Esta página é acessível por qualquer pessoa com o link.
Otimizada para mobile e para conexão ruim.

Ao carregar:
  1. Buscar emergency_links WHERE token = :token
  2. Validar: is_active = true AND (expires_at IS NULL OR expires_at > now())
  3. Se inválido: tela "Link expirado ou inválido" com instruções para
     pedir novo link ao familiar responsável
  4. Se válido: carregar TODOS os dados do patient_id de uma vez
     (não usar lazy loading nesta página)

  5. Registrar acesso via Supabase Edge Function:
     POST /functions/v1/log-emergency-access
     Body: { token }
     A Edge Function (service_role) faz:
     - INSERT em access_logs com action='emergency_view'
     - UPDATE emergency_links: access_count+1, last_accessed_at=now()
     (Não fazer UPDATE direto do client — RLS bloquearia)

Layout da página pública:

  BANNER TOPO — fundo vermelho-600, texto branco:
    "⚠ INFORMAÇÕES DE EMERGÊNCIA"
    Nome do paciente em fonte grande (24px+)

  As seções devem seguir ordem de prioridade médica:

  SEÇÃO 1 — Identificação básica:
    Foto circular + Nome + Idade + Tipo sanguíneo em badge grande

  SEÇÃO 2 — ⚠ ALERGIAS (fundo vermelho-50, borda vermelha):
    Exibir PRIMEIRO e em destaque — é a info mais crítica antes
    de qualquer medicação ser administrada.
    Se não há alergias: "Nenhuma alergia registrada" em verde.

  SEÇÃO 3 — 💊 Medicamentos ativos:
    Nome + dosagem de cada um

  SEÇÃO 4 — Condições médicas ativas

  SEÇÃO 5 — 🏥 Convênio:
    Nome + número da carteirinha (fonte grande, fácil de copiar)

  SEÇÃO 6 — 📞 Contatos de emergência:
    Nome + relação + botão "Ligar" (href="tel:...") para cada contato
    Médico principal com botão de ligação

  SEÇÃO 7 — 🏨 Hospital de preferência

  RODAPÉ:
    "Gerado via Amparo · [data/hora de geração do link]"
    "Este resumo é para uso emergencial. Não substitui avaliação médica."

  PERFORMANCE:
    Não usar lazy loading.
    Embutir CSS crítico (Tailwind purged) no bundle mínimo.
    Página deve renderizar em menos de 2s em 3G.
```

---

## PROMPT 9 — Módulo Família e Permissões

```
Implemente o módulo de família em /familia/:familyId/membros

Tabelas: family_members, invitations, profiles, access_logs

---

Tela principal /membros:
  Lista de membros com status='active':
    Avatar + Nome (de profiles.full_name) + role badge + status
    Roles com cores:
      Admin=roxo | Editor=azul | Visualizador=cinza |
      Cuidador=verde | Médico=teal

  Seção separada "Convites pendentes":
    invitations WHERE status='pending' AND expires_at > now()
    Cada item: email, papel convidado, data de expiração
    Botão "Reenviar" e "Cancelar" por convite

  Tap em membro → bottom sheet com opções (apenas admin vê as opções de gestão):
    "Alterar papel" (select) — apenas admin
    "Remover da família" — apenas admin, modal de confirmação
    "Ver atividade recente" — abre log filtrado por esse membro

  Botão "Convidar pessoa" no header

---

Modal "Convidar pessoa":
  Campo: Email (obrigatório)
  Select: Papel
    Admin — Gerencia tudo
    Editor — Adiciona e edita dados
    Visualizador — Apenas consulta
    Cuidador — Rotina, medicamentos e agenda
    Médico — Acesso temporário a resumo e documentos

  Ao confirmar:
    INSERT em invitations (email, role, invited_by, expires_at = now() + 7 dias)
    Exibir link do convite + botão:
      [📋 Copiar link]
      [💬 Compartilhar no WhatsApp]
        → href="https://wa.me/?text=Você foi convidado para o Amparo:+[url]"

---

Tela pública /convite/:token (SEM autenticação):
  Buscar invitation WHERE token = :token AND status='pending'
  AND expires_at > now()

  Se inválido: "Convite expirado ou inválido"
    Texto: "Peça ao familiar que te envie um novo convite."

  Se válido: mostrar nome da família + papel que receberá

  TRÊS branches de ação (não apenas dois):

  1. Usuário está logado:
     Botão "Aceitar convite" →
     INSERT em family_members + UPDATE invitation status='accepted'
     Redireciona para /dashboard

  2. Usuário não tem conta:
     Botão "Criar conta e aceitar" →
     Redireciona para /register?invite=:token
     Após registro: aceitar convite automaticamente

  3. Usuário tem conta mas não está logado:
     Botão "Entrar na minha conta e aceitar" →
     Redireciona para /login?invite=:token
     Após login: aceitar convite automaticamente

  Detectar o estado correto verificando a sessão Supabase atual.

---

Tela /membros/atividade:
  Log de atividade da família
  Query: access_logs WHERE family_id = ? ORDER BY created_at DESC
  Paginação com "Carregar mais" (não scroll infinito)
  Filtro por membro (select) e por tipo de ação (select)
  Cada item: avatar, descrição legível da ação, data/hora relativa
  (ex: "há 2 horas", "ontem às 15h")
  Visível apenas para admins.
```

---

## PROMPT 10 — Perfil do Familiar (Página completa)

```
Implemente a página de perfil completo do familiar em
/familia/:familyId/pacientes/:patientId

Tabelas: patients, patient_conditions, patient_allergies, emergency_contacts

Layout: seções expansíveis (accordion) com header clicável.
Cada seção tem botão "Editar" no header da seção que ativa
edição inline — apenas os campos daquela seção ficam editáveis.
Botão "Salvar" e "Cancelar" aparecem ao entrar em modo edição.
Mostrar "Atualizado [data relativa]" em cinza no header de cada seção.

---

SEÇÃO 1 — Identificação (aberta por padrão):
  Foto circular (100px) — clicável para trocar:
    · Mobile: "📷 Câmera" ou "🖼 Galeria"
    · Desktop: file picker
    Upload para bucket patient-photos
  Nome completo (text)
  Data de nascimento → idade calculada e exibida (ex: "80 anos")
  Tipo sanguíneo (select com enum: A+, A-, B+, B-, AB+, AB-, O+, O-)
  Altura em cm (number)
  Peso em kg (number)
  NÃO calcular nem exibir IMC — não é relevante para o contexto clínico
  do app e pode ser constrangedor para o familiar que preenche.
  Observações críticas (textarea)

---

SEÇÃO 2 — Convênio e hospital:
  Nome do convênio (text)
  Número da carteirinha (text)
  Hospital de preferência (text)
  Médico principal (text)

---

SEÇÃO 3 — Alergias:
  Lista de patient_allergies com badges de severidade:
    Crítica=vermelho | Alta=laranja | Média=amarelo | Baixa=cinza
  Botão "+ Adicionar alergia" → abre inline form:
    Nome da alergia + select de severidade → INSERT
  Tap em alergia existente: editar severidade ou remover (com confirmação)

---

SEÇÃO 4 — Condições médicas:
  Lista de patient_conditions
  Cada item: nome + status badge (ativa/inativa) + data de diagnóstico
  Botão "+ Adicionar condição" → inline form: nome + status + diagnosed_at
  Tap em condição: editar ou marcar como inativa

---

SEÇÃO 5 — Contatos de emergência:
  Lista ordenada por priority
  Cada contato: nome, relação, telefone (botão "Ligar"), email

  REORDENAÇÃO DE PRIORIDADE:
  NÃO usar drag-and-drop (difícil no mobile web).
  Usar botões ↑ e ↓ ao lado de cada contato para mover na lista.
  UPDATE priority dos contatos afetados ao mover.

  Botão "+ Adicionar contato" → inline form

---

SEÇÃO 6 — Prévia de emergência (read-only, sempre fechada por padrão):
  Card compacto mostrando exatamente o que aparecerá na tela pública
  de emergência — útil para o usuário verificar o que está exposto.
  Botão "Abrir tela de emergência" → abre modal da emergência

---

Todas as edições:
  INSERT em access_logs com action='patient_update',
  resource_type='patient', resource_id=patientId
```

---

## PROMPT 11 — Polimentos finais, PWA e estados vazios

```
Aplique os seguintes polimentos no app Amparo:

---

1. ESTADOS VAZIOS:
   Cada módulo sem dados deve ter:
   - Ilustração SVG simples e acolhedora (inline, sem dependência externa)
   - Texto encorajador em cinza-600
   - Botão de ação primária

   Exemplos:
   - Medicamentos: "Nenhum medicamento cadastrado ainda." + "Cadastrar primeiro"
   - Agenda: "Nenhuma consulta agendada." + "Agendar consulta"
   - Documentos: "Sua biblioteca está vazia. Suba o primeiro documento." + "Subir agora"
   - Histórico: "Nenhum evento clínico registrado." + "Registrar primeiro evento"

---

2. FEEDBACK DE AÇÕES:
   Instalar biblioteca sonner para toast notifications.
   - Sucesso: verde, 3 segundos, ícone ✓
   - Erro: vermelho, 5 segundos, botão "Tentar novamente"
     O botão "Tentar novamente" deve re-executar a mesma mutation do React Query.
     Passar o callback da action para o toast ao dispará-lo.
   - Loading: spinner inline substituindo texto do botão durante requisição.
     Nunca desabilitar botão sem feedback visual de loading.

---

3. CONFIRMAÇÕES DESTRUTIVAS:
   Para: deletar, remover membro, encerrar medicamento, cancelar consulta:
   - Modal com título descritivo: "Excluir [nome do item]?"
   - Texto: "Esta ação não pode ser desfeita."
   - Botão confirmar: vermelho, texto "Sim, excluir"
   - Botão cancelar: secundário, texto "Voltar"

---

4. OFFLINE / ERRO DE REDE:
   Detectar via navigator.onLine + evento 'offline'.
   Quando offline: banner fixo no topo (amarelo, abaixo do header):
   "Sem conexão — exibindo dados salvos. Alterações serão sincronizadas ao reconectar."
   Dados já carregados permanecem visíveis via React Query cache.
   Ao reconectar: dismiss do banner + refetch automático.

---

5. RESPONSIVIDADE — testar nos breakpoints:
   - 375px (iPhone SE) — breakpoint crítico, tudo deve caber sem scroll horizontal
   - 390px (iPhone 14)
   - 768px (iPad) — sidebar aparece, bottom nav some
   - 1280px (desktop)

---

6. ACESSIBILIDADE BÁSICA:
   - Todos os botões de ícone: aria-label descritivo
   - Contraste mínimo 4.5:1 em texto normal, 3:1 em texto grande
   - Fontes: mínimo 16px para corpo, 14px para labels secundários
   - Tap targets: mínimo 44×44px (usar min-h-11 min-w-11 no Tailwind)
   - Inputs com htmlFor/id corretos para acessibilidade

---

7. PÁGINA DE PERFIL DO USUÁRIO (/perfil):
   Acessível pelo avatar no header.
   Campos:
   - Nome completo (editável — UPDATE em profiles)
   - Foto (upload — mesmo padrão mobile/desktop dos outros módulos)
   - Email (read-only — vem do auth, não editável aqui)
   - Telefone (editável — UPDATE em profiles)

   Botão "Sair":
     Modal de confirmação simples → signOut() → redireciona para /login

   Botão "Excluir minha conta" (vermelho, ao final):
     ANTES de mostrar confirmação: verificar se o usuário é o único
     admin de alguma família.
     Se for único admin:
       Mostrar aviso bloqueante:
       "Você é o único administrador da família '[nome]'.
       Promova outro membro a admin antes de excluir sua conta."
       Botão: "Gerenciar família" → /familia/:id/membros
       NÃO mostrar opção de excluir enquanto for único admin.
     Se não for único admin:
       Dupla confirmação:
       1ª: Modal "Tem certeza? Todos os seus dados serão removidos."
       2ª: Pedir digitar email para confirmar → então executar exclusão.

---

8. PWA — Progressive Web App:
   Criar public/manifest.json:
   {
     "name": "Amparo",
     "short_name": "Amparo",
     "description": "A central de saúde da sua família",
     "start_url": "/",
     "display": "standalone",
     "background_color": "#ffffff",
     "theme_color": "#2563eb",
     "icons": [
       { "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png" },
       { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png" },
       { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png",
         "purpose": "maskable" }
     ]
   }

   Criar ícones placeholder em public/icons/ (192×192 e 512×512 PNG)
   com fundo azul-600 e letra "A" branca centralizada.

   Adicionar no index.html:
   <link rel="manifest" href="/manifest.json">
   <meta name="theme-color" content="#2563eb">
   <meta name="apple-mobile-web-app-capable" content="yes">
   <meta name="apple-mobile-web-app-status-bar-style" content="default">

   META TAGS SEO no index.html:
   <title>Amparo — A central de saúde da sua família</title>
   <meta name="description" content="Organize remédios, exames, consultas
   e histórico médico de quem você cuida. Compartilhe com a família.">
```

---

## Ordem de execução recomendada

| # | Prompt | O que entrega |
|---|--------|---------------|
| 1 | Fundação | Auth, layout, navegação correta |
| 2 | Onboarding | Primeiro acesso com passos opcionais |
| 3 | Dashboard | Home com seletor sticky e FAB posicionado |
| 4 | Medicamentos | Cadastro, logs, histórico |
| 5 | Agenda | Lista + calendário, fluxo de 2 passos |
| 6 | Histórico | Timeline com filtros em bottom sheet |
| 7 | Documentos | Upload mobile-first, busca server-side |
| **8** | **Emergência** | **Módulo diferencial — validar RLS antes de publicar** |
| 9 | Família | Convites com 3 branches, log de atividade |
| 10 | Perfil do familiar | Seções editáveis, sem IMC, reordenação com ↑↓ |
| 11 | Polimentos | Estados vazios, PWA, proteção de único admin |

## Dicas para usar no Lovable

- Execute **um prompt por vez** e valide o resultado antes de avançar
- Use o chat do Lovable para ajustes pontuais antes de ir ao próximo prompt
- Após os prompts 1–3, já é possível mostrar para usuários beta
- No prompt 8, a Edge Function de log de acesso precisa ser criada
  no painel do Supabase antes de testar a página pública de emergência
- Antes de publicar o prompt 8, valide que a página /emergencia/:token
  é acessível sem login mas não expõe dados de outros pacientes
