#Requires AutoHotkey v2.0
#SingleInstance Force

; WezTerm のパス（環境に合わせて変更可）
weztermPath := "D:\Program Files\WezTerm\wezterm-gui.exe"
; 対象ウィンドウの識別子
weztermWin := "ahk_exe wezterm-gui.exe"

; Ctrl + Alt + Space でトグル
^!Space::
{
    global weztermPath, weztermWin
    if WinExist(weztermWin)
    {
        if WinActive(weztermWin)
        {
            ; 表示中（アクティブ）なら最小化
            WinMinimize(weztermWin)
        }
        else
        {
            ; 最小化されていれば元に戻してから最前面へ
            if WinGetMinMax(weztermWin) = -1
                WinRestore(weztermWin)
            WinActivate(weztermWin)
        }
    }
    else
    {
        ; 未起動なら起動
        Run('"' weztermPath '"')
    }
}
