const fs = require('fs');
const path = require('path');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function initProject() {
  console.log('\n🚀 Inicializar nuevo proyecto\n');

  const projectName = await question('Nombre del proyecto: ');
  const description = await question('Descripción breve: ');
  const stack = await question('Stack (ej: Supabase + Cloudflare): ');

  const projectsPath = process.env.PROJECTS_PATH || path.join(process.cwd(), 'Workspace', 'Proyectos');
  const projectPath = path.join(projectsPath, projectName);

  if (fs.existsSync(projectPath)) {
    console.error(`❌ El proyecto "${projectName}" ya existe`);
    rl.close();
    return;
  }

  // Crear estructura
  fs.mkdirSync(projectPath, { recursive: true });
  fs.mkdirSync(path.join(projectPath, 'src'));
  fs.mkdirSync(path.join(projectPath, '.claude', 'agents'), { recursive: true });

  // Copiar agentes
  const templateAgents = path.join(projectsPath, '.template', '.claude', 'agents');
  if (fs.existsSync(templateAgents)) {
    const agents = fs.readdirSync(templateAgents);
    agents.forEach(agent => {
      fs.copyFileSync(
        path.join(templateAgents, agent),
        path.join(projectPath, '.claude', 'agents', agent)
      );
    });
  }

  // Copiar CLAUDE_INSTRUCTIONS.md
  const templateInstructions = path.join(projectsPath, '.template', 'CLAUDE_INSTRUCTIONS.md');
  if (fs.existsSync(templateInstructions)) {
    fs.copyFileSync(templateInstructions, path.join(projectPath, 'CLAUDE_INSTRUCTIONS.md'));
  }

  // Crear PROYECTO_CONFIG.md
  const config = `# CONFIG: ${projectName}

> Claude: Este archivo se lee AUTOMÁTICAMENTE al abrir el proyecto

## 🎯 Descripción
${description}

## 🛠️ Stack
${stack}

## 🤖 Agentes disponibles
- **@sql** → Bases de datos, queries, RLS
- **@html** → Markup, formularios, componentes
- **@security** → Auditoría, pentesting, vulnerabilidades
- **@design** → UI/UX, landing pages
- **@pdf** → Generación de reportes
- **@general** → Coordinador general

## 🔧 Herramientas activas
- **Gemini API** → Consultas automáticas de docs
- **Error Logger** → Registro automático de errores
- **Hitos Manager** → Tracking de progreso

## 📋 Flujo de trabajo automático

### Al recibir solicitud:
1. CONSULTAR Gemini sobre MEMORY_PROYECTO.md
2. CONSULTAR Gemini sobre errores.md
3. LLAMAR agente especializado
4. GENERAR código
5. SI hay error → Registrar en errores.md
6. SI completaste feature → Actualizar hitos.md
7. SI cambiaste arquitectura → Actualizar MEMORY_PROYECTO.md

## 🚨 Reglas estrictas
1. NUNCA generar código sin consultar Gemini primero
2. SIEMPRE registrar errores en errores.md
3. SIEMPRE actualizar hitos.md al completar features
4. SIEMPRE usar el agente correcto
5. NUNCA hardcodear API keys
`;

  fs.writeFileSync(path.join(projectPath, 'PROYECTO_CONFIG.md'), config);

  // Crear MEMORY_PROYECTO.md
  const memory = `# MEMORY: ${projectName}

> Última actualización: ${new Date().toISOString().split('T')[0]}

## 📋 Información General

**Descripción:** ${description}

**Stack tecnológico:**
${stack}

**URLs:**
- Producción: 
- Desarrollo: 
- Repositorio: 

---

## 🎯 Objetivo del Proyecto

[Describe el objetivo y problema que resuelve]

---

## 🏗️ Arquitectura

### Estructura de archivos
\`\`\`
${projectName}/
├── src/
├── .claude/agents/
├── PROYECTO_CONFIG.md
├── MEMORY_PROYECTO.md
├── errores.md
└── hitos.md
\`\`\`

---

## 🔐 Configuración

### Variables de entorno
\`\`\`
[Variables necesarias]
\`\`\`

---

## 📝 Funcionalidades

### Implementadas
- [ ] Feature 1

### Pendientes
- [ ] Feature 2

---

## 📚 Decisiones Técnicas

[Registrar decisiones importantes aquí]
`;

  fs.writeFileSync(path.join(projectPath, 'MEMORY_PROYECTO.md'), memory);

  // Crear errores.md
  const errors = `# ERRORES CONOCIDOS Y SOLUCIONES

> Registro automático de errores y sus soluciones

---
`;
  fs.writeFileSync(path.join(projectPath, 'errores.md'), errors);

  // Crear hitos.md
  const hitos = `# HITOS DEL PROYECTO

> Registro cronológico de avances

---

## ${new Date().toISOString().split('T')[0]} - Proyecto inicializado

**Tipo:** setup  
**Descripción:** Estructura base del proyecto creada

---
`;
  fs.writeFileSync(path.join(projectPath, 'hitos.md'), hitos);

  console.log(`\n✅ Proyecto "${projectName}" creado en:`);
  console.log(`   ${projectPath}\n`);
  console.log('Archivos creados:');
  console.log('  - CLAUDE_INSTRUCTIONS.md (Claude Code lee esto)');
  console.log('  - PROYECTO_CONFIG.md');
  console.log('  - MEMORY_PROYECTO.md');
  console.log('  - errores.md');
  console.log('  - hitos.md');
  console.log('  - .claude/agents/ (6 agentes especializados)\n');

  rl.close();
}

initProject().catch(console.error);