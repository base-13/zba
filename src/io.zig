// LCD
// 0x4000000 => DISPCNT
// 0x4000004 => DISPSTAT
// 0x4000006 => VCOUNT
// 0x4000008 => BG0CNT
// 0x400000A => BG1CNT
// 0x400000C => BG2CNT
// 0x400000E => BG3CNT
// 0x4000010 => BG0HOFS
// 0x4000012 => BG0VOFS
// 0x4000014 => BG1HOFS
// 0x4000016 => BG1VOFS
// 0x4000018 => BG2HOFS
// 0x400001A => BG2VOFS
// 0x400001C => BG3HOFS
// 0x400001E => BG3VOFS
// 0x4000020 => BG2PA
// 0x4000022 => BG2PB
// 0x4000024 => BG2PC
// 0x4000026 => BG2PD
// 0x4000028 => BG2X
// 0x400002C => BG2Y
// 0x4000030 => BG3PA
// 0x4000032 => BG3PB
// 0x4000034 => BG3PC
// 0x4000036 => BG3PD
// 0x4000038 => BG3X
// 0x400003C => BG3Y
// 0x4000040 => WIN0H
// 0x4000042 => WIN1H
// 0x4000044 => WIN0V
// 0x4000046 => WIN1V
// 0x4000048 => WININ
// 0x400004A => WINOUT
// 0x400004C => MOSAIC
// 0x4000050 => BLDCNT
// 0x4000052 => BLDALPHA
// 0x4000054 => BLDY

// Sound
// 0x4000060 => SOUND1CNT_L
// 0x4000062 => SOUND1CNT_H
// 0x4000064 => SOUND1CNT_X
// 0x4000068 => SOUND2CNT_L
// 0x400006C => SOUND2CNT_H
// 0x4000070 => SOUND3CNT_L
// 0x4000072 => SOUND3CNT_H
// 0x4000074 => SOUND3CNT_X
// 0x4000078 => SOUND4CNT_L
// 0x400007C => SOUND4CNT_H
// 0x4000080 => SOUNDCNT_L
// 0x4000082 => SOUNDCNT_H
// 0x4000084 => SOUNDCNT_X
// 0x4000088 => SOUNDBIAS
// 0x4000090 => WAVE_RAM
// 0x40000A0 => FIFO_A
// 0x40000A4 => FIFO_B

// DMA
// 0x40000B0 => DMA0SAD
// 0x40000B4 => DMA0DAD
// 0x40000B8 => DMA0CNT_L
// 0x40000BA => DMA0CNT_H
// 0x40000BC => DMA1SAD
// 0x40000C0 => DMA1DAD
// 0x40000C4 => DMA1CNT_L
// 0x40000C6 => DMA1CNT_H
// 0x40000C8 => DMA2SAD
// 0x40000CC => DMA2DAD
// 0x40000D0 => DMA2CNT_L
// 0x40000D2 => DMA2CNT_H
// 0x40000D4 => DMA3SAD
// 0x40000D8 => DMA3DAD
// 0x40000DC => DMA3CNT_L
// 0x40000DE => DMA3CNT_H

// Timer
// 0x4000100 => TM0CNT_L
// 0x4000102 => TM0CNT_H
// 0x4000104 => TM1CNT_L
// 0x4000106 => TM1CNT_H
// 0x4000108 => TM2CNT_L
// 0x400010A => TM2CNT_H
// 0x400010C => TM3CNT_L
// 0x400010E => TM3CNT_H

// Serial 1
// 0x4000120 => SIODATA32
// 0x4000120 => SIOMULTI0
// 0x4000122 => SIOMULTI1
// 0x4000124 => SIOMULTI2
// 0x4000126 => SIOMULTI3
// 0x4000128 => SIOCNT
// 0x400012A => SIOMLT_SEND
// 0x400012A => SIODATA8

// Keypad
// 0x4000130 => KEYINPUT
// 0x4000132 => KEYCNT

// Serial
// 0x4000134 => RCNT
// 0x4000140 => JOYCNT
// 0x4000150 => JOY_RECV
// 0x4000154 => JOY_TRANS
// 0x4000158 => JOYSTAT

// Interrupt, Waitstate, and Power-Down Control
// 0x4000200 => IE
// 0x4000202 => IF
// 0x4000204 => WAITCNT
// 0x4000208 => IME
// 0x4000300 => POSTFLG
// 0x4000301 => HALTCNT

pub const IORegisters = struct {
    // LCD
    DISPCNT: [2]u8, // LCD Control
    DISPSTAT: [2]u8, // General LCD Status (STAT,LYC)
    VCOUNT: [2]u8, // Vertical Counter (LY)
    BG0CNT: [2]u8, // BG0 Control
    BG1CNT: [2]u8, // BG1 Control
    BG2CNT: [2]u8, // BG2 Control
    BG3CNT: [2]u8, // BG3 Control
    BG0HOFS: [2]u8, // BG0 X-Offset
    BG0VOFS: [2]u8, // BG0 Y-Offset
    BG1HOFS: [2]u8, // BG1 X-Offset
    BG1VOFS: [2]u8, // BG1 Y-Offset
    BG2HOFS: [2]u8, // BG2 X-Offset
    BG2VOFS: [2]u8, // BG2 Y-Offset
    BG3HOFS: [2]u8, // BG3 X-Offset
    BG3VOFS: [2]u8, // BG3 Y-Offset
    BG2PA: [2]u8, // BG2 Rotation/Scaling Parameter A (dx)
    BG2PB: [2]u8, // BG2 Rotation/Scaling Parameter B (dmx)
    BG2PC: [2]u8, // BG2 Rotation/Scaling Parameter C (dy)
    BG2PD: [2]u8, // BG2 Rotation/Scaling Parameter D (dmy)
    BG2X: [4]u8, // BG2 Reference Point X-Coordinate
    BG2Y: [4]u8, // BG2 Reference Point Y-Coordinate
    BG3PA: [2]u8, // BG3 Rotation/Scaling Parameter A (dx)
    BG3PB: [2]u8, // BG3 Rotation/Scaling Parameter B (dmx)
    BG3PC: [2]u8, // BG3 Rotation/Scaling Parameter C (dy)
    BG3PD: [2]u8, // BG3 Rotation/Scaling Parameter D (dmy)
    BG3X: [4]u8, // BG3 Reference Point X-Coordinate
    BG3Y: [4]u8, // BG3 Reference Point Y-Coordinate
    WIN0H: [2]u8, // Window 0 Horizontal Dimensions
    WIN1H: [2]u8, // Window 1 Horizontal Dimensions
    WIN0V: [2]u8, // Window 0 Vertical Dimensions
    WIN1V: [2]u8, // Window 1 Vertical Dimensions
    WININ: [2]u8, // Inside of Window 0 and 1
    WINOUT: [2]u8, // Inside of OBJ Window & Outside of Windows
    MOSAIC: [2]u8, // Mosaic Size
    BLDCNT: [2]u8, // Color Special Effects Selection
    BLDALPHA: [2]u8, // Alpha Blending Coefficients
    BLDY: [2]u8, // Brightness (Fade-In/Out) Coefficient

    // Sound
    SOUND1CNT_L: [2]u8, // Channel 1 Sweep register       (NR10)
    SOUND1CNT_H: [2]u8, // Channel 1 Duty/Length/Envelope (NR11, NR12)
    SOUND1CNT_X: [2]u8, // Channel 1 Frequency/Control    (NR13, NR14)
    SOUND2CNT_L: [2]u8, // Channel 2 Duty/Length/Envelope (NR21, NR22)
    SOUND2CNT_H: [2]u8, // Channel 2 Frequency/Control    (NR23, NR24)
    SOUND3CNT_L: [2]u8, // Channel 3 Stop/Wave RAM select (NR30)
    SOUND3CNT_H: [2]u8, // Channel 3 Length/Volume        (NR31, NR32)
    SOUND3CNT_X: [2]u8, // Channel 3 Frequency/Control    (NR33, NR34)
    SOUND4CNT_L: [2]u8, // Channel 4 Length/Envelope      (NR41, NR42)
    SOUND4CNT_H: [2]u8, // Channel 4 Frequency/Control    (NR43, NR44)
    SOUNDCNT_L: [2]u8, // Control Stereo/Volume/Enable   (NR50, NR51)
    SOUNDCNT_H: [2]u8, // Control Mixing/DMA Control
    SOUNDCNT_X: [2]u8, // Control Sound on/off           (NR52)
    SOUNDBIAS: [2]u8, // Sound PWM Control
    WAVE_RAM: [16]u8, // Channel 3 Wave Pattern RAM (2 banks!!)
    FIFO_A: [2]u8, // Channel A FIFO, Data 0-3
    FIFO_B: [2]u8, // Channel B FIFO, Data 0-3

    // DMA
    DMA0SAD: [4]u8, // DMA 0 Source Address
    DMA0DAD: [4]u8, // DMA 0 Destination Address
    DMA0CNT_L: [2]u8, // DMA 0 Word Count
    DMA0CNT_H: [2]u8, // DMA 0 Control
    DMA1SAD: [4]u8, // DMA 1 Source Address
    DMA1DAD: [4]u8, // DMA 1 Destination Address
    DMA1CNT_L: [2]u8, // DMA 1 Word Count
    DMA1CNT_H: [2]u8, // DMA 1 Control
    DMA2SAD: [4]u8, // DMA 2 Source Address
    DMA2DAD: [4]u8, // DMA 2 Destination Address
    DMA2CNT_L: [2]u8, // DMA 2 Word Count
    DMA2CNT_H: [2]u8, // DMA 2 Control
    DMA3SAD: [4]u8, // DMA 3 Source Address
    DMA3DAD: [4]u8, // DMA 3 Destination Address
    DMA3CNT_L: [2]u8, // DMA 3 Word Count
    DMA3CNT_H: [2]u8, // DMA 3 Control

    // Timer
    TM0CNT_L: [2]u8, // Timer 0 Counter/Reload
    TM0CNT_H: [2]u8, // Timer 0 Control
    TM1CNT_L: [2]u8, // Timer 1 Counter/Reload
    TM1CNT_H: [2]u8, // Timer 1 Control
    TM2CNT_L: [2]u8, // Timer 2 Counter/Reload
    TM2CNT_H: [2]u8, // Timer 2 Control
    TM3CNT_L: [2]u8, // Timer 3 Counter/Reload
    TM3CNT_H: [2]u8, // Timer 3 Control

    // Serial 1
    SIODATA32: [4]u8, // SIO Data (Normal-32bit Mode; shared with below)
    SIOMULTI0: [2]u8, // SIO Data 0 (Parent)    (Multi-Player Mode)
    SIOMULTI1: [2]u8, // SIO Data 1 (1st Child) (Multi-Player Mode)
    SIOMULTI2: [2]u8, // SIO Data 2 (2nd Child) (Multi-Player Mode)
    SIOMULTI3: [2]u8, // SIO Data 3 (3rd Child) (Multi-Player Mode)
    SIOCNT: [2]u8, // SIO Control Register
    SIOMLT_SEND: [2]u8, // SIO Data (Local of MultiPlayer; shared below)
    SIODATA8: [2]u8, // SIO Data (Normal-8bit and UART Mode)

    // Keypad
    KEYINPUT: [2]u8, // Key Status
    KEYCNT: [2]u8, // Key Interrupt Control

    // Serial 2
    RCNT: [2]u8, // SIO Mode Select/General Purpose Data
    JOYCNT: [2]u8, // SIO JOY Bus Control
    JOY_RECV: [4]u8, // SIO JOY Bus Receive Data
    JOY_TRANS: [4]u8, // SIO JOY Bus Transmit Data
    JOYSTAT: [2]u8, // SIO JOY Bus Receive Status

    // Interrupt, Waitstate, and Power-Down Control
    IE: [2]u8, // Interrupt Enable Register
    IF: [2]u8, // Interrupt Request Flags / IRQ Acknowledge
    WAITCNT: [2]u8, // Game Pak Waitstate Control
    IME: [2]u8, // Interrupt Master Enable Register
    POSTFLG: [1]u8, // Undocumented - Post Boot Flag
    HALTCNT: [1]u8, // Undocumented - Power Down Control
};
