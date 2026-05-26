-- Amparo — seed data para desenvolvimento local
-- Rode após: supabase db reset

-- Família de exemplo
insert into families (id, name, created_by) values
  ('00000000-0000-0000-0000-000000000001', 'Família Silva', '00000000-0000-0000-0000-000000000099');

-- Familiar cuidado de exemplo
insert into patients (id, family_id, created_by, name, birth_date, blood_type, health_insurance_name) values
  ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000099', 'João Silva', '1945-03-15', 'O+', 'Unimed');

-- Condição médica de exemplo
insert into patient_conditions (patient_id, created_by, name, status, diagnosed_at) values
  ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000099',
   'Hipertensão arterial', 'active', '2010-01-01');

-- Alergia de exemplo
insert into patient_allergies (patient_id, created_by, allergy, severity) values
  ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000099',
   'Penicilina', 'high');

-- Medicamento ativo de exemplo
insert into medications (patient_id, created_by, name, dosage, frequency, schedule, start_date, status) values
  ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000099',
   'Losartana', '50mg', 'daily',
   '[{"time": "08:00"}]'::jsonb,
   '2020-06-01', 'active');
