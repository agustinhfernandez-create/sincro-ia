${error.message || error}

### 📋 Contexto
- Archivo: ${context.file || 'N/A'}
- Línea: ${context.line || 'N/A'}
- Función: ${context.function || 'N/A'}

### ❌ Stack trace
\`\`\`
${error.stack || 'No disponible'}
\`\`\`

### ✅ Solución
${context.solution || '[Pendiente - Claude completará esto]'}

### 💡 Lección aprendida
${context.lesson || '[Pendiente]'}

---
`;

    // Crear archivo si no existe
    if (!fs.existsSync(this.errorsFile)) {
      fs.writeFileSync(this.errorsFile, '# ERRORES CONOCIDOS Y SOLUCIONES\n\n');
    }

    // Agregar entrada
    fs.appendFileSync(this.errorsFile, errorEntry);
    
    console.log(`✅ Error registrado en errores.md: ${title}`);
    return errorEntry;
  }

  getRecentErrors(limit = 5) {
    if (!fs.existsSync(this.errorsFile)) {
      return [];
    }

    const content = fs.readFileSync(this.errorsFile, 'utf-8');
    const errorBlocks = content.split('---').filter(b => b.trim());
    
    return errorBlocks.slice(-limit);
  }
}

module.exports = ErrorLogger;
'@
Set-Content -Path "$installDir\scripts\automation\error-logger.js" -Value $autoLogger
Write-Success "error-logger.js creado"

# Auto-hitos
$autoHitos = @'
const fs = require('fs');
const path = require('path');

