const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');

const HTML_FILE = 'app.html';
const bundledHtmlPath = path.join(__dirname, HTML_FILE);

// ─── HTML path resolution ───
function getHtmlPath() {
    return bundledHtmlPath;
}

// ─── Window creation (圆角无框窗口) ───
let mainWindow;

function createWindow() {
    // Windows 11 风格圆角无框窗口
    mainWindow = new BrowserWindow({
        width: 1400,
        height: 900,
        frame: false,
        titleBarStyle: 'hidden',
        transparent: false,
        backgroundColor: '#ffffff',
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false,
            webSecurity: false
        },
        icon: path.join(__dirname, 'icon.ico')
    });

    mainWindow.loadFile(getHtmlPath());

    // IPC handlers for custom titlebar buttons
    ipcMain.on('window-minimize', () => mainWindow.minimize());
    ipcMain.on('window-maximize', () => {
        if (mainWindow.isMaximized()) {
            mainWindow.unmaximize();
        } else {
            mainWindow.maximize();
        }
    });
    ipcMain.on('window-close', () => mainWindow.close());

    mainWindow.on('maximize', () => {
        if (!mainWindow.isDestroyed()) {
            mainWindow.webContents.send('window-max-changed', true);
        }
    });
    mainWindow.on('unmaximize', () => {
        if (!mainWindow.isDestroyed()) {
            mainWindow.webContents.send('window-max-changed', false);
        }
    });

    mainWindow.on('focus', () => {
        if (!mainWindow.isDestroyed()) {
            mainWindow.webContents.send('window-active');
        }
    });
    mainWindow.on('blur', () => {
        if (!mainWindow.isDestroyed()) {
            mainWindow.webContents.send('window-inactive');
        }
    });
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
