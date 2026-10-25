#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <stdio.h>
#include <wchar.h>
#include <wctype.h>

static void error(const wchar_t *message) {
    MessageBoxW(NULL, message, L"SENZ Zelda — Pelancar", MB_OK | MB_ICONERROR);
}
int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR args, int show) {
    wchar_t root[32768], script[32768], exe[32768], log[32768], command[32768];
    DWORD n=GetModuleFileNameW(NULL,root,32768);
    if (!n || n>=32768) {error(L"Laluan pelancar terlalu panjang.");return 1;}
    wchar_t *slash=wcsrchr(root,L'\\');
    if (!slash) return 1;
    *slash=0;
    if (wcslen(root)>14000) {error(L"Pindahkan folder game ke laluan lebih pendek.");return 1;}
    swprintf(script,32768,L"%ls\\Launcher.ps1",root);
    if (GetFileAttributesW(script)==INVALID_FILE_ATTRIBUTES) {
        error(L"Fail pelancar tidak lengkap. Ekstrak SEMUA kandungan ZIP dahulu. Kekalkan EXE bersama folder engine dan fail sokongan.");return 2;
    }
    DWORD hash=2166136261u;
    for (wchar_t *p=root;*p;++p) hash=(hash^(DWORD)towlower(*p))*16777619u;
    wchar_t mutexName[80];swprintf(mutexName,80,L"Local\\SENZ-Zelda-%08lx",hash);
    HANDLE mutex=CreateMutexW(NULL,FALSE,mutexName);
    if (mutex && GetLastError()==ERROR_ALREADY_EXISTS) {
        MessageBoxW(NULL,L"Pelancar sudah dibuka. Pilih SENZ Zelda pada taskbar.",L"SENZ Zelda",MB_OK|MB_ICONINFORMATION);
        CloseHandle(mutex);return 0;
    }
    if (!GetSystemDirectoryW(exe,32768)) {error(L"Windows PowerShell tidak ditemui.");return 3;}
    wcscat(exe,L"\\WindowsPowerShell\\v1.0\\powershell.exe");
    swprintf(command,32768,L"\"%ls\" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \"%ls\"",exe,script);
    swprintf(log,32768,L"%ls\\launcher-error.log",root);
    SECURITY_ATTRIBUTES sa={sizeof(sa),NULL,TRUE};
    HANDLE output=CreateFileW(log,GENERIC_WRITE,FILE_SHARE_READ,&sa,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL);
    if(output==INVALID_HANDLE_VALUE){error(L"Folder tidak boleh ditulis. Ekstrak game ke folder milik anda, contohnya Desktop atau D:\\Games.");if(mutex)CloseHandle(mutex);return 4;}
    HANDLE input=CreateFileW(L"NUL",GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE,&sa,OPEN_EXISTING,0,NULL);
    STARTUPINFOW si={0};PROCESS_INFORMATION pi={0};si.cb=sizeof(si);
    si.dwFlags=STARTF_USESHOWWINDOW|STARTF_USESTDHANDLES;si.wShowWindow=SW_HIDE;
    si.hStdOutput=output;si.hStdError=output;si.hStdInput=input;
    BOOL ok=CreateProcessW(exe,command,NULL,NULL,TRUE,CREATE_NO_WINDOW,NULL,root,&si,&pi);
    DWORD winError=GetLastError();
    if(input!=INVALID_HANDLE_VALUE)CloseHandle(input);
    CloseHandle(output);
    if(!ok){wchar_t message[512];swprintf(message,512,L"Pelancar tidak dapat dimulakan (ralat Windows %lu). Pastikan Windows PowerShell tersedia.",winError);error(message);if(mutex)CloseHandle(mutex);return 5;}
    CloseHandle(pi.hThread);
    WaitForSingleObject(pi.hProcess,INFINITE);
    DWORD code=1;GetExitCodeProcess(pi.hProcess,&code);CloseHandle(pi.hProcess);
    if(mutex)CloseHandle(mutex);
    if(code){error(L"Pelancar berhenti dengan ralat. Hantar fail launcher-error.log dalam folder game untuk pemeriksaan.");}
    return (int)code;
}
