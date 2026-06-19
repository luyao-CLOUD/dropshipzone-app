const { app, BrowserWindow, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const https = require('https');

const HTML_FILE = 'Dropshipzone全品类上架模板_v6.9_批量上架版.html';
const VERSION_URL = 'https://raw.githubusercontent.com/luyao-CLOUD/dropshipzone-app/main/version.json';

// Local storage paths (always writable)
const userDataDir = app.getPath('userData');
const localVersionPath = path.join(userDataDir, 'version.json');
const localHtmlPath = path.join(userDataDir, 'latest.html');
const bundledHtmlPath = path.join(__dirname, HTML_FILE);

// ─── HTTP helpers ───
function fetchJSON(url) {
    return new Promise((resolve, reject) => {
        const req = https.get(url, { headers: { 'Cache-Control': 'no-cache', 'Pragma': 'no-cache' } }, (res) => {
            if (res.statusCode === 301 || res.statusCode === 302) {
                return fetchJSON(res.headers.location).then(resolve).catch(reject);
            }
            if (res.statusCode !== 200) { reject(new Error('HTTP ' + res.statusCode)); return; }
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try { resolve(JSON.parse(data)); } catch (e) { reject(e); }
            });
        });
        req.on('error', reject);
        req.setTimeout(10000, () => { req.destroy(); reject(new Error('timeout')); });
    });
}

function downloadFile(url, destPath) {
    return new Promise((resolve, reject) => {
        const encodedUrl = encodeURI(url);
        const req = https.get(encodedUrl, { headers: { 'Cache-Control': 'no-cache', 'Pragma': 'no-cache' } }, (res) => {
            if (res.statusCode === 301 || res.statusCode === 302) {
                return downloadFile(res.headers.location, destPath).then(resolve).catch(reject);
            }
            if (res.statusCode !== 200) { reject(new Error('HTTP ' + res.statusCode)); return; }
            const tmpPath = destPath + '.tmp';
            const file = fs.createWriteStream(tmpPath);
            res.pipe(file);
            file.on('finish', () => {
                file.close(() => {
                    fs.renameSync(tmpPath, destPath);
                    resolve();
                });
            });
            file.on('error', (e) => {
                try { fs.unlinkSync(tmpPath); } catch (_) {}
                reject(e);
            });
        });
        req.on('error', reject);
        req.setTimeout(30000, () => { req.destroy(); reject(new Error('timeout')); });
    });
}

// ─── Version management ───
function getLocalVersion() {
    try {
        if (fs.existsSync(localVersionPath)) {
            const data = JSON.parse(fs.readFileSync(localVersionPath, 'utf-8'));
            return data.version || '0';
        }
    } catch (e) {}
    return '0';
}

function saveLocalVersion(version, updateDate) {
    try {
        fs.writeFileSync(localVersionPath, JSON.stringify({
            version,
            updateDate,
            localSavedAt: new Date().toISOString()
        }, null, 2));
    } catch (e) {}
}

// ─── HTML path resolution ───
function getHtmlPath() {
    // Use downloaded (updated) HTML if available, otherwise use bundled
    if (fs.existsSync(localHtmlPath)) {
        return localHtmlPath;
    }
    return bundledHtmlPath;
}

// ─── Auto-update check ───
async function checkForUpdate(mainWindow) {
    try {
        const remote = await fetchJSON(VERSION_URL);
        const local = getLocalVersion();

        if (remote.version && remote.version !== local) {
            // New version available — download
            const downloadUrl = remote.url || (VERSION_URL.replace('version.json', HTML_FILE));
            await downloadFile(downloadUrl, localHtmlPath);
            saveLocalVersion(remote.version, remote.updateDate);

            if (mainWindow && !mainWindow.isDestroyed()) {
                dialog.showMessageBox(mainWindow, {
                    type: 'info',
                    title: '✅ 更新成功',
                    message: '已更新到 V' + remote.version,
                    detail: (remote.updateNotes || '应用已自动更新到最新版本。\n点击确定后自动重新加载。') +
                            '\n\n更新日期: ' + (remote.updateDate || 'N/A'),
                    buttons: ['确定']
                }).then(() => {
                    mainWindow.reload();
                });
            }
        }
    } catch (e) {
        // Silently fail — use local/bundled HTML
        console.log('[AutoUpdate] Check failed:', e.message);
    }
}

// ─── Window creation ───
function createWindow() {
    const win = new BrowserWindow({
        width: 1400,
        height: 900,
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false,
            webSecurity: false
        }
    });

    win.loadFile(getHtmlPath());

    // Check for updates after window loads (non-blocking)
    win.webContents.on('did-finish-load', () => {
        checkForUpdate(win);
    });

    // win.webContents.openDevTools();
}

app.on('ready', () => {
    createWindow();
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
