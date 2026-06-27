import express from 'express';
import { createProxyMiddleware } from 'http-proxy-middleware';
import { spawn, execSync } from 'child_process';
import path from 'path';
import fs from 'fs';
import https from 'https';

const app = express();
const PORT = parseInt(process.env.PORT || '3000', 10);
const PYTHON_PORT = parseInt(process.env.PYTHON_PORT || '5000', 10);

console.log('Spawning Python Flask backend on port', PYTHON_PORT);

// Create a log stream to capture stdout/stderr of the Python process
const logStream = fs.createWriteStream(path.join(process.cwd(), 'python.log'), { flags: 'a' });

// Function to download get-pip.py
function downloadGetPip(): Promise<string> {
  return new Promise((resolve, reject) => {
    const dest = path.join(process.cwd(), 'get-pip.py');
    
    // First, try curl
    try {
      console.log('Attempting download with curl...');
      execSync(`curl -sSL https://bootstrap.pypa.io/get-pip.py -o "${dest}"`);
      if (fs.existsSync(dest) && fs.statSync(dest).size > 1000) {
        console.log('Downloaded get-pip.py successfully via curl');
        return resolve(dest);
      }
    } catch (e) {
      console.log('curl download failed, trying wget...');
    }

    // Try wget
    try {
      execSync(`wget -q https://bootstrap.pypa.io/get-pip.py -O "${dest}"`);
      if (fs.existsSync(dest) && fs.statSync(dest).size > 1000) {
        console.log('Downloaded get-pip.py successfully via wget');
        return resolve(dest);
      }
    } catch (e) {
      console.log('wget download failed, trying https.get with redirect handling...');
    }

    // Fallback to node https with redirect support
    const downloadWithNode = (url: string) => {
      https.get(url, (response) => {
        if (response.statusCode && response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
          downloadWithNode(response.headers.location);
          return;
        }
        const file = fs.createWriteStream(dest);
        response.pipe(file);
        file.on('finish', () => {
          file.close();
          resolve(dest);
        });
      }).on('error', (err) => {
        fs.unlink(dest, () => {});
        reject(err);
      });
    };

    downloadWithNode('https://bootstrap.pypa.io/get-pip.py');
  });
}

async function prepareEnvironment() {
  fs.appendFileSync(path.join(process.cwd(), 'python.log'), '\n--- Preparing Python Environment ---\n');
  
  // Resolve Python binary
  let pythonBin = 'python3';
  const venvPaths = [
    path.join(process.cwd(), 'venv', 'bin', 'python3'),
    path.join(process.cwd(), 'venv', 'bin', 'python'),
    path.join(process.cwd(), 'HVM-V7-main', 'venv', 'bin', 'python3'),
    path.join(process.cwd(), 'HVM-V7-main', 'venv', 'bin', 'python'),
    path.join(process.cwd(), 'venv', 'Scripts', 'python.exe'),
  ];
  for (const p of venvPaths) {
    if (fs.existsSync(p)) {
      pythonBin = p;
      console.log(`Using Python virtual environment: ${pythonBin}`);
      fs.appendFileSync(path.join(process.cwd(), 'python.log'), `Using Python virtual environment: ${pythonBin}\n`);
      break;
    }
  }

  // Check if main dependencies are already satisfied
  let needsInstall = false;
  try {
    execSync(`"${pythonBin}" -c "import requests, flask, flask_socketio, paramiko, hypercorn, PIL, cryptography"`, { stdio: 'ignore' });
    console.log('Python dependencies are already satisfied. Skipping installation.');
    fs.appendFileSync(path.join(process.cwd(), 'python.log'), 'Python dependencies already satisfied. Skipping installation.\n');
  } catch (e) {
    needsInstall = true;
  }

  if (needsInstall) {
    // 1. Ensure pip is installed
    try {
      console.log('Ensuring pip is installed via ensurepip...');
      execSync(`"${pythonBin}" -m ensurepip --default-pip`, { encoding: 'utf-8' });
      console.log('ensurepip succeeded');
      fs.appendFileSync(path.join(process.cwd(), 'python.log'), 'ensurepip succeeded\n');
    } catch (err: any) {
      console.log('ensurepip failed, downloading get-pip.py...');
      fs.appendFileSync(path.join(process.cwd(), 'python.log'), `ensurepip failed: ${err.message}\nDownloading get-pip.py...\n`);
      try {
        const getPipPath = await downloadGetPip();
        console.log('Downloaded get-pip.py. Installing pip...');
        const out = execSync(`"${pythonBin}" "${getPipPath}" --break-system-packages`, { encoding: 'utf-8' });
        fs.appendFileSync(path.join(process.cwd(), 'python.log'), `get-pip.py installation output: ${out}\n`);
        // Clean up
        fs.unlinkSync(getPipPath);
      } catch (err2: any) {
        console.error('get-pip.py fallback failed:', err2);
        fs.appendFileSync(path.join(process.cwd(), 'python.log'), `get-pip.py installation failed: ${err2.message}\n${err2.stderr || ''}\n`);
      }
    }

    // 2. Install requirements
    try {
      console.log('Installing Python dependencies from HVM-V7-main/requirements.txt...');
      fs.appendFileSync(path.join(process.cwd(), 'python.log'), 'Installing requirements.txt...\n');
      try {
        const installOut = execSync(`"${pythonBin}" -m pip install -r HVM-V7-main/requirements.txt --break-system-packages`, { encoding: 'utf-8' });
        console.log(installOut);
        fs.appendFileSync(path.join(process.cwd(), 'python.log'), installOut + '\n');
      } catch (err: any) {
        console.log('Retrying requirements install without --break-system-packages...');
        const installOut = execSync(`"${pythonBin}" -m pip install -r HVM-V7-main/requirements.txt`, { encoding: 'utf-8' });
        console.log(installOut);
        fs.appendFileSync(path.join(process.cwd(), 'python.log'), installOut + '\n');
      }
      console.log('Python dependencies installed successfully.');
    } catch (err: any) {
      console.error('Failed to install Python dependencies:', err);
      fs.appendFileSync(path.join(process.cwd(), 'python.log'), `Failed to install Python dependencies: ${err.message}\n${err.stderr || ''}\n`);
    }
  }
  // 3. Spawn Python backend
  console.log(`Spawning Python Flask backend via ${pythonBin}...`);
  const pythonProcess = spawn(pythonBin, [path.join(process.cwd(), 'HVM-V7-main', 'hvm.py')], {
    env: {
      ...process.env,
      PORT: String(PYTHON_PORT),
    },
    stdio: 'pipe'
  });

  pythonProcess.stdout.pipe(logStream);
  pythonProcess.stderr.pipe(logStream);

  pythonProcess.stdout.on('data', (data) => {
    console.log(`[Python STDOUT] ${data.toString().trim()}`);
  });

  pythonProcess.stderr.on('data', (data) => {
    console.error(`[Python STDERR] ${data.toString().trim()}`);
  });

  pythonProcess.on('error', (err) => {
    console.error('Failed to start Python backend:', err);
    fs.appendFileSync(path.join(process.cwd(), 'python.log'), `Failed to start Python backend: ${err.message}\n`);
  });

  pythonProcess.on('exit', (code) => {
    console.log(`Python backend exited with code ${code}`);
    fs.appendFileSync(path.join(process.cwd(), 'python.log'), `Python backend exited with code ${code}\n`);
  });
}

prepareEnvironment();

// Proxy middleware to forward all requests to Python Flask backend
const proxy = createProxyMiddleware({
  target: `http://127.0.0.1:${PYTHON_PORT}`,
  changeOrigin: true,
  ws: true, // Enable WebSocket proxying for Socket.IO console, etc.
  logger: console,
  on: {
    error: (err: any, req, res: any) => {
      if (err.code === 'ECONNREFUSED' || err.code === 'EPIPE' || err.code === 'ECONNRESET') {
        console.warn(`[Proxy Connection Handled] Backend not ready or connection reset (${err.code}).`);
      } else {
        console.error('[Proxy Error]', err);
      }
      if (res && typeof res.writeHead === 'function' && !res.headersSent) {
        res.writeHead(502, { 'Content-Type': 'text/html' });
        res.end(`
          <!DOCTYPE html>
          <html>
          <head>
            <title>DICOT Panel - Preparing Environment</title>
            <meta http-equiv="refresh" content="3">
            <style>
              body { 
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; 
                background: #0b0f19; 
                color: #f8fafc; 
                display: flex; 
                align-items: center; 
                justify-content: center; 
                height: 100vh; 
                margin: 0; 
                text-align: center; 
              }
              .card { 
                background: rgba(15, 23, 42, 0.6); 
                padding: 3rem; 
                border-radius: 1.5rem; 
                border: 1px solid rgba(6, 182, 212, 0.15); 
                box-shadow: 0 0 40px rgba(6, 182, 212, 0.1);
                max-width: 460px; 
              }
              h1 { 
                color: #22d3ee; 
                font-size: 1.5rem; 
                margin-top: 1rem;
                margin-bottom: 0.5rem;
                font-weight: 700;
                letter-spacing: -0.025em;
              }
              p { 
                color: #94a3b8; 
                font-size: 0.875rem; 
                line-height: 1.6; 
                margin-bottom: 0;
              }
              .loader { 
                border: 3px solid rgba(6, 182, 212, 0.1); 
                border-top: 3px solid #22d3ee; 
                border-radius: 50%; 
                width: 32px; 
                height: 32px; 
                animation: spin 1s linear infinite; 
                margin: 0 auto; 
              }
              @keyframes spin { 
                0% { transform: rotate(0deg); } 
                100% { transform: rotate(360deg); } 
              }
            </style>
          </head>
          <body>
            <div class="card">
              <div class="loader"></div>
              <h1>Booting DICOT Panel Engine</h1>
              <p>The system is currently setting up and preparing the background server. This will take a few moments. We are automatically reloading the page for you...</p>
            </div>
          </body>
          </html>
        `);
      }
    }
  }
});

app.use('/', proxy);

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Proxy server running on http://0.0.0.0:${PORT}`);
});

// Handle WebSocket upgrade requests
server.on('upgrade', (req, socket, head) => {
  socket.on('error', (err) => {
    console.debug('[WS Socket Handled]', err.message);
  });
  proxy.upgrade(req, socket as any, head);
});
