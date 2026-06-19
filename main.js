const { app, BrowserWindow, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const https = require('https');

const HTML_FILE = 'app.html';
const VERSION_URL = 'https://raw.githubusercontent.com/luyao-CLOUD/dropshipzone-app/main/version.json';
const BASE_RAW_URL = 'https://raw.githubusercontent.com/luyao-CLOUD/dropshipzone-app/main/';

// Local storage paths (always writable)
const userDataDir = app.getPath('userData');
const localVersionPath = path.join(userDataDir, 'version.json');
const localHtmlPath = path.join(userDataDir, 'latest.html');
const bundledHtmlPath = path.join(__dirname, HTML_FILE);
// Updated files stored locally (applied on next restart)
const updateDir = path.join(userDataDir, 'pending_update');

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

// ─── Apply pending updates (from previous run) ───
function applyPendingUpdates() {
    try {
        if (!fs.existsSync(updateDir)) return false;
        
        const appDir = __dirname;
        let updated = false;
        
        // Copy each file from pending_update to app directory
        const files = fs.readdirSync(updateDir);
        for (const file of files) {
            const src = path.join(updateDir, file);
            const dest = path.join(appDir, file);
            const stat = fs.statSync(src);
            if (stat.isFile()) {
                try {
                    // Backup old file
                    if (fs.existsSync(dest)) {
                        fs.copyFileSync(dest, dest + '.bak');
                    }
                    fs.copyFileSync(src, dest);
                    console.log('[AutoUpdate] Applied update:', file);
                    updated = true;
                } catch (e) {
                    console.log('[AutoUpdate] Failed to apply', file, ':', e.message);
                }
            }
        }
        
        // Clean up
        try { fs.rmSync(updateDir, { recursive: true, force: true }); } catch (_) {}
        
        return updated;
    } catch (e) {
        console.log('[AutoUpdate] applyPendingUpdates error:', e.message);
        return false;
    }
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
            // New version available
            const version = remote.version;
            const updateNotes = remote.updateNotes || '应用已自动更新到最新版本。';
            const updateDate = remote.updateDate || 'N/A';

            // Create pending update directory
            if (!fs.existsSync(updateDir)) {
                fs.mkdirSync(updateDir, { recursive: true });
            }

            // 1. Download app.html (HTML content - applied immediately)
            const htmlUrl = remote.htmlFile ? (BASE_RAW_URL + remote.htmlFile) : (BASE_RAW_URL + 'app.html');
            try {
                await downloadFile(htmlUrl, localHtmlPath);
                console.log('[AutoUpdate] Downloaded app.html');
            } catch (e) {
                console.log('[AutoUpdate] Failed to download HTML:', e.message);
            }

            // 2. Download main.js (saved to pending - applied on next restart)
            try {
                const mainJsUrl = BASE_RAW_URL + 'main.js';
                await downloadFile(mainJsUrl, path.join(updateDir, 'main.js'));
                console.log('[AutoUpdate] Downloaded main.js (pending)');
            } catch (e) {
                console.log('[AutoUpdate] Failed to download main.js:', e.message);
            }

            // 3. Download package.json (saved to pending - applied on next restart)
            try {
                const pkgUrl = BASE_RAW_URL + 'package.json';
                await downloadFile(pkgUrl, path.join(updateDir, 'package.json'));
                console.log('[AutoUpdate] Downloaded package.json (pending)');
            } catch (e) {
                console.log('[AutoUpdate] Failed to download package.json:', e.message);
            }

            // Save version
            saveLocalVersion(version, updateDate);

            if (mainWindow && !mainWindow.isDestroyed()) {
                const result = await dialog.showMessageBox(mainWindow, {
                    type: 'info',
                    title: '✅ 更新成功',
                    message: '已更新到 V' + version,
                    detail: updateNotes +
                            '\n\n更新日期: ' + updateDate +
                            '\n\n🌐 HTML 已立即生效（点击确定后自动刷新）' +
                            '\n📦 软件程序(main.js)将在下次启动时自动应用' +
                            '\n\n建议重启软件以完成全部更新',
                    buttons: ['确定并刷新', '稍后重启']
                });

                if (result.response === 0) {
                    // Reload to apply HTML changes
                    mainWindow.reload();
                }
            }
        } else {
            console.log('[AutoUpdate] Already up to date (v' + local + ')');
        }
    } catch (e) {
        // Silently fail — use local/bundled HTML
        console.log('[AutoUpdate] Check failed:', e.message);
    }
}

// ─── Window creation ───
function createWindow() {
    // Apply pending updates before creating window
    const hadPending = applyPendingUpdates();

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
        
        // If we applied pending updates, notify user
        if (hadPending) {
            dialog.showMessageBox(win, {
                type: 'info',
                title: '📦 软件程序已更新',
                message: '检测到并已应用程序更新',
                detail: '软件程序文件(main.js, package.json)已更新到最新版本。\n当前运行的是更新后的代码。',
                buttons: ['确定']
            });
        }
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
