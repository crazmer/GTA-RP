Config = {
    ServerName = 'BotRP',
    Version = '0.1.0',

    -- Qbox owns the persistent character data. This resource only provides
    -- the presentation/orchestration layer around Qbox's character callbacks.
    MaxVisibleCharacters = 6,
    DeleteCharacters = true,

    -- Keep the existing Qbox spawn stack instead of creating a second spawn system.
    PreferApartments = true,
    PreferQbxSpawn = true,

    -- Used only when neither qbx_apartments nor qbx_spawn is running.
    DefaultSpawn = vec4(-1037.76, -2737.88, 20.17, 329.46),

    UI = {
        Accent = '#21a8ff',
        AccentSoft = '#0d6fa8',
        Background = '#070b11',
        Card = '#0c121a',
    }
}
