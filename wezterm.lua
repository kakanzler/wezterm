-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- tabline.wez プラグイン（かっこいいタブ＆ステータスバー）
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
    config = wezterm.config_builder()
end


-- ここまでは定型文
-- この先でconfigに各種設定を書いていく

-- 同じ向きに並んだペインを均等サイズ（1:1:1...）に整える
-- ※ 一方向に並んだレイアウト（全部縦積み or 全部横並び）向け
-- AdjustPaneSize はアクティブペインにしか効かず、移動量も実挙動とズレやすいので、
-- 「毎回サイズを読み直して 1 境界ずつ補正」を複数パス繰り返して収束させる。
local function balance_panes(window)
    local tab0 = window:active_tab()
    if not tab0 then return end
    local infos0 = tab0:panes_with_info()
    if #infos0 < 2 then return end

    -- 元のアクティブペイン（最後にフォーカスを戻す）
    local active_pane
    for _, p in ipairs(infos0) do
        if p.is_active then active_pane = p.pane end
    end

    local function count(t)
        local c = 0
        for _ in pairs(t) do c = c + 1 end
        return c
    end

    -- 並びの向きを判定：top のばらつき＞left のばらつきなら縦積み（高さを均等化）
    local function is_vertical(infos)
        local tops, lefts = {}, {}
        for _, p in ipairs(infos) do
            tops[p.top] = true
            lefts[p.left] = true
        end
        return count(tops) >= count(lefts)
    end

    local passes = 4 -- 収束のための繰り返し回数

    -- 1 ティックにつき 1 境界だけ補正する（その都度サイズを読み直す）
    local function tick(remaining, border)
        local tab = window:active_tab()
        if not tab then return end
        local infos = tab:panes_with_info()
        local n = #infos
        if n < 2 then return end

        local vertical = is_vertical(infos)
        table.sort(infos, function(a, b)
            if vertical then return a.top < b.top else return a.left < b.left end
        end)

        local total = 0
        for _, p in ipairs(infos) do
            total = total + (vertical and p.height or p.width)
        end
        local target = total / n

        -- border 番号（1..n-1）の現在位置と目標位置の差を求める
        local cum = 0
        for i = 1, border do
            cum = cum + (vertical and infos[i].height or infos[i].width)
        end
        local desired = math.floor(border * target + 0.5)
        local delta = desired - cum
        if delta ~= 0 then
            if delta > 0 then
                -- 境界を後ろへ：手前(border)のペインを広げる
                infos[border].pane:activate()
                window:perform_action(
                    wezterm.action.AdjustPaneSize { (vertical and 'Down' or 'Right'), delta },
                    infos[border].pane)
            else
                -- 境界を前へ：次(border+1)のペインを広げる
                infos[border + 1].pane:activate()
                window:perform_action(
                    wezterm.action.AdjustPaneSize { (vertical and 'Up' or 'Left'), -delta },
                    infos[border + 1].pane)
            end
        end

        -- 次の境界へ。最後まで行ったら次のパスへ
        local next_border = border + 1
        local next_remaining = remaining
        if next_border > n - 1 then
            next_border = 1
            next_remaining = remaining - 1
        end
        if next_remaining > 0 then
            wezterm.time.call_after(0.03, function() tick(next_remaining, next_border) end)
        elseif active_pane then
            active_pane:activate() -- フォーカスを元に戻す
        end
    end

    tick(passes, 1)
end

-- 起動時のデフォルトシェルをPowerShellにする（デフォルトはコマンドプロンプト）
config.default_prog = { 'pwsh.exe', '-NoLogo' }

-- フォントサイズ（デフォルト13.0から2段階下げて11.0）
config.font_size = 11.0
-- 背景の非透過率（1なら完全に透過させない）
config.window_background_opacity = 0.93

-- 配色テーマ（ハッカーっぽい緑×黒のMatrix風）
config.colors = {
    foreground = '#00ff66', -- 文字色（鮮やかな緑）
    background = '#000000', -- 背景（ほぼ黒）
    cursor_bg = '#00ff66',  -- カーソルの色
    cursor_fg = '#0a0e0a',
    cursor_border = '#00ff66',
    selection_fg = '#0a0e0a',
    selection_bg = '#00aa44',
    -- 16色パレット（通常8色 / 明るい8色）
    ansi = {
        '#0a0e0a', -- black
        '#00aa44', -- red    → 緑系に寄せる
        '#00ff66', -- green
        '#33ff88', -- yellow → 黄緑
        '#140663', -- blue   → 暗緑  (フォルダの色)
        '#00cc55', -- magenta→ 緑
        '#00ffaa', -- cyan   → 緑シアン
        '#00ff66', -- white  → 緑
    },
    brights = {
        '#005522', -- bright black
        '#33ff77', -- bright red
        '#66ff99', -- bright green
        '#99ffbb', -- bright yellow
        '#00bb55', -- bright blue
        '#33ffaa', -- bright magenta
        '#66ffcc', -- bright cyan
        '#ccffdd', -- bright white
    },
}

-- 行間・文字間を少し広げて緑文字を読みやすく
config.line_height = 1.1   -- 行の高さ（1.0が標準）
config.cell_width = 1.0    -- 文字幅（0.9〜1.1で調整可）

-- カーソルを点滅する四角に（レトロCRT風）
config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_rate = 500 -- 点滅速度(ms)。0で点滅オフ

-- 非アクティブなペインを少し暗く＆彩度を落とす（操作中のペインを目立たせる）
config.inactive_pane_hsb = {
    saturation = 0.8,
    brightness = 0.6,
}

-- スクロールバック行数を増やす（デフォルト3500行）
config.scrollback_lines = 10000

-- Neovim(smart-splits.nvim) 連携用ヘルパ
-- アクティブペインで nvim が動いているかを判定する
local function is_nvim(pane)
    -- 1) 最も確実: nvim が起動時に立てる user var(IS_NVIM) を見る。
    --    Windows でプロセス名判定が外れても、これがあれば確実に nvim へ転送できる。
    local vars = pane:get_user_vars()
    if vars and vars.IS_NVIM == 'true' then
        return true
    end
    -- 2) フォールバック: 前面プロセス名(nvim.exe 等)で判定
    local info = pane:get_foreground_process_info()
    local name = info and info.name or ''
    -- フルパス/拡張子付き(nvim.exe 等)でも拾えるよう小文字化して部分一致
    return name:lower():find('n?vim') ~= nil
end

-- Ctrl+HJKL: nvim なら同じキーを nvim に送り(=分割移動)、
-- そうでなければ Wezterm のペイン移動を行う。nvim 側が端に達したときは
-- smart-splits.nvim が Wezterm 側のペイン移動へ引き継ぐ。
local nav_directions = { h = 'Left', j = 'Down', k = 'Up', l = 'Right' }
local function split_nav(key)
    return {
        key = key,
        mods = 'CTRL',
        action = wezterm.action_callback(function(win, pane)
            if is_nvim(pane) then
                win:perform_action(wezterm.action.SendKey { key = key, mods = 'CTRL' }, pane)
            else
                win:perform_action(wezterm.action.ActivatePaneDirection(nav_directions[key]), pane)
            end
        end),
    }
end

-- キーバインド
config.keys = {
    -- Ctrl HJKL で nvim分割 ↔ Weztermペイン をシームレス移動（nvim連携）
    split_nav('h'),
    split_nav('j'),
    split_nav('k'),
    split_nav('l'),
    -- Ctrl Shift + でフォントサイズを大きくする
    {
        key = "+",
        mods = "CTRL|SHIFT",
        action = wezterm.action.IncreaseFontSize,
    },
    -- Ctrl Shift - でフォントサイズを小さくする
    {
        key = "_",
        mods = "CTRL|SHIFT",
        action = wezterm.action.DecreaseFontSize,
    },
    -- Ctrl Shift w でペインを閉じる（デフォルトではタブが閉じる）
    {
        key = "w",
        mods = "CTRL|SHIFT",
        action = wezterm.action.CloseCurrentPane { confirm = true },
    },
    -- Ctrl Shift d で左右に分割（横に並ぶ）
    {
        key = "d",
        mods = "CTRL|SHIFT",
        action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" },
    },
    -- Ctrl Shift e で上下に分割（縦に並ぶ）
    {
        key = "e",
        mods = "CTRL|SHIFT",
        action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" },
    },
    -- Ctrl Shift b でペインを均等サイズ（1:1:1...）に整える
    {
        key = "b",
        mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(window, pane)
            balance_panes(window)
        end),
    },
    -- Ctrl Shift o でペインの中身を入れ替える
    {
        key = "o",
        mods = "CTRL|SHIFT",
        action = wezterm.action.RotatePanes 'Clockwise'
    },
    -- Ctrl Shift hjkl でペインの移動
    {
        key = 'h',
        mods = 'CTRL|SHIFT',
        action = wezterm.action.ActivatePaneDirection 'Left',
    },
    {
        key = 'j',
        mods = 'CTRL|SHIFT',
        action = wezterm.action.ActivatePaneDirection 'Down',
    },
    {
        key = 'k',
        mods = 'CTRL|SHIFT',
        action = wezterm.action.ActivatePaneDirection 'Up',
    },
    {
        key = 'l',
        mods = 'CTRL|SHIFT',
        action = wezterm.action.ActivatePaneDirection 'Right',
    },
    -- Ctrl Alt hjkl でペイン境界の調整
    {
        key = 'h',
        mods = 'CTRL|ALT',
        action = wezterm.action.AdjustPaneSize { 'Left', 2 },
    },
    {
        key = 'j',
        mods = 'CTRL|ALT',
        action = wezterm.action.AdjustPaneSize { 'Down', 2 },
    },
    {
        key = 'k',
        mods = 'CTRL|ALT',
        action = wezterm.action.AdjustPaneSize { 'Up', 2 },
    },
    {
        key = 'l',
        mods = 'CTRL|ALT',
        action = wezterm.action.AdjustPaneSize { 'Right', 2 },
    },

}

-- マウス操作の挙動設定
config.mouse_bindings = {
    -- 右クリックでクリップボードから貼り付け
    {
        event = { Down = { streak = 1, button = 'Right' } },
        mods = 'NONE',
        action = wezterm.action.PasteFrom 'Clipboard',
    },
}

-- タブを下に表示（デフォルトでは上にある）
config.tab_bar_at_bottom = true

-- 起動時にウィンドウを画面の左半分いっぱいに配置する（タスクバーには被らない）
wezterm.on('gui-startup', function(cmd)
    -- 画面下のタスクバーの高さ（環境に合わせて調整可）
    local taskbar_height = 48
    -- タイトルバー等のウィンドウ装飾の高さ（set_inner_size は内側のみ指定するため差し引く）
    local window_chrome = 40
    local screen = wezterm.gui.screens().active
    local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
    local gui = window:gui_window()
    -- 画面の左上に移動
    gui:set_position(screen.x, screen.y)
    -- 幅は画面の半分、高さは画面からタスクバー分と装飾分を引いた高さ
    gui:set_inner_size(screen.width / 2, screen.height - taskbar_height - window_chrome)
end)

-- tabline.wez の設定（タブ＆ステータスバーを自動描画。手書きの format-tab-title /
-- update-right-status はこれが置き換えるため不要）
tabline.setup({
    options = {
        -- 緑×黒のMatrix配色（tablineはこのカラースキームから自動で緑系テーマを生成する）
        theme = {
            foreground = '#00ff66',
            background = '#000000',
            cursor = { bg = '#005522' },
            -- tabline が参照するのは主に ansi[1,3,4,5,6]。全部緑系で固める
            ansi = {
                '#005522', -- 1: 区画bの背景に使われる
                '#00aa44', -- 2
                '#33ff88', -- 3: 検索モードのアクセント
                '#00aa44', -- 4: コピーモードのアクセント
                '#00ff66', -- 5: 一番目立つアクセント（モード/アクティブタブ）
                '#00cc55', -- 6: ホバー
                '#00ffaa', -- 7
                '#00ff66', -- 8
            },
        },
        -- アクティブタブを明るい緑×黒文字で強調
        theme_overrides = {
            tab = {
                active = { fg = '#000000', bg = '#00ff66' },
            },
        },
        section_separators = {
            left = wezterm.nerdfonts.ple_upper_left_triangle,
            right = wezterm.nerdfonts.ple_lower_right_triangle,
        },
        component_separators = {
            left = wezterm.nerdfonts.ple_forwardslash_separator,
            right = wezterm.nerdfonts.ple_forwardslash_separator,
        },
        tab_separators = {
            left = wezterm.nerdfonts.ple_upper_left_triangle,
            right = wezterm.nerdfonts.ple_lower_right_triangle,
        },
    },
    sections = {
        -- 左端：モード表示
        tabline_a = { 'mode' },
        tabline_b = { 'workspace' },
        tabline_c = { ' ' },
        -- 各タブ：番号 + プロセス名 + フォルダ
        tab_active = {
            'index',
            { 'process', padding = { left = 0, right = 1 } },
            { 'cwd', padding = { left = 1, right = 0 } },
            { 'zoomed', padding = 0 },
        },
        tab_inactive = {
            'index',
            { 'process', padding = { left = 0, right = 1 } },
        },
        -- 右側：Gitブランチ + ディレクトリ + バッテリー + 時計
        tabline_x = { 'ram', 'cpu' },
        tabline_y = { 'battery', 'datetime' },
        tabline_z = { 'domain' },
    },
})
-- tabline の設定を config に反映（use_fancy_tab_bar=false 等を設定）
tabline.apply_to_config(config)
-- タブバーは下に表示（tabline 適用後に再指定して優先させる）
config.tab_bar_at_bottom = true

return config
