const fs = require('fs');
const path = require('path');

// 1. CONFIGURACION DE RUTAS
// La raiz del workspace se detecta automaticamente. Se puede forzar con la
// variable de entorno SINCRO_ROOT si se ejecuta desde otra ubicacion.
const ROOT_DIR = process.env.SINCRO_ROOT || process.cwd();
const ENV_PATH = path.join(ROOT_DIR, '.env');
const PROJECTS_DIR = path.join(ROOT_DIR, 'Workspace/Proyectos');

function getApiKey() {
    try {
        if (!fs.existsSync(ENV_PATH)) return null;
        const envContent = fs.readFileSync(ENV_PATH, 'utf-8');
        // Limpieza profunda de la clave (ignora espacios, comillas y saltos de linea)
        const match = envContent.match(/GEMINI_API_KEY\s*=\s*["']?([A-Za-z0-9_-]+)["']?/);
        return match ? match[1] : null;
    } catch (e) {
        return null;
    }
}

async function ejecutar() {
    const proyecto = process.argv[2];
    const query = process.argv.slice(3).join(" ") || "Hola";
    const apiKey = getApiKey();

    if (!apiKey) {
        console.error(`ERROR: No se encontro GEMINI_API_KEY en ${ENV_PATH}`);
        console.error('Carga tu API key de Gemini en el archivo .env de la raiz del entorno.');
        process.exit(1);
    }

    if (!proyecto) {
        console.error("ERROR: Debes especificar el nombre del proyecto.");
        console.error("Uso: node scripts/gemini/gemini-client.js <Proyecto> \"<consulta>\"");
        process.exit(1);
    }

    // 2. RECOPILAR CONTEXTO DE LOS ARCHIVOS .MD DEL PROYECTO
    const pathProyecto = path.join(PROJECTS_DIR, proyecto);
    const pathMemory = path.join(pathProyecto, 'MEMORY_PROYECTO.md');
    const pathErrores = path.join(pathProyecto, 'errores.md');

    const memory = fs.existsSync(pathMemory) ? fs.readFileSync(pathMemory, 'utf-8') : "";
    const errores = fs.existsSync(pathErrores) ? fs.readFileSync(pathErrores, 'utf-8') : "";

    // 3. LLAMADA A LA API
    // Modelo configurable via GEMINI_MODEL (default: gemini-3.1-flash-lite)
    const modelo = process.env.GEMINI_MODEL || "gemini-3.1-flash-lite";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent?key=${apiKey}`;

    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{
                    parts: [{
                        text: `Contexto del Proyecto ${proyecto}:\n${memory}\n\nErrores conocidos:\n${errores}\n\nUsuario dice: ${query}`
                    }]
                }]
            })
        });

        const data = await response.json();

        if (data.error) {
            console.error(`Error de Google: ${data.error.message}`);
            return;
        }

        // 4. IMPRIMIR RESPUESTA
        if (data.candidates && data.candidates[0].content) {
            console.log("\n--- GEMINI RESPONDE ---");
            console.log(data.candidates[0].content.parts[0].text);
            console.log("------------------------\n");
        }

    } catch (e) {
        console.error("Error tecnico:", e.message);
    }
}

ejecutar();
