      if (fs.existsSync(hitosPath)) {
        context += `# HITOS DEL PROYECTO\n${fs.readFileSync(hitosPath, 'utf-8')}\n\n`;
      }

      if (!context) {
        return { error: 'No se encontró documentación del proyecto' };
      }

      // Construir prompt
      const prompt = `Eres un asistente que ayuda a Claude a trabajar en proyectos.

DOCUMENTACIÓN DEL PROYECTO:
${context}

PREGUNTA: ${question}

INSTRUCCIONES:
- Responde de forma concisa y precisa
- Cita secciones específicas de la documentación
- Si no encuentras la información, dilo claramente
- Responde en español

RESPUESTA:`;

      const result = await this.model.generateContent(prompt);
      const response = await result.response;
      
      return {
        success: true,
        answer: response.text(),
        tokensUsed: response.usageMetadata || {}
      };
    } catch (error) {
      return {
        error: error.message
      };
    }
  }
}

module.exports = GeminiClient;
'@
Set-Content -Path "$installDir\scripts\gemini\gemini-client.js" -Value $geminiClient
Write-Success "gemini-client.js creado"

# Auto-logger
$autoLogger = @'
const fs = require('fs');
const path = require('path');

class ErrorLogger {
  constructor(projectPath = process.cwd()) {
    this.projectPath = projectPath;
    this.errorsFile = path.join(projectPath, 'errores.md');
  }

  log(error, context = {}) {
    const timestamp = new Date().toISOString().split('T')[0];
    const title = context.title || 'Error detectado';
