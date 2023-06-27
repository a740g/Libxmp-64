'-----------------------------------------------------------------------------------------------------------------------
' Libxmp bindings for QB64-PE (minimalistic)
' Copyright (c) 2023 Samuel Gomes
'
' Most of the stuff here is from https://github.com/libxmp/libxmp/blob/master/include/xmp.h
'-----------------------------------------------------------------------------------------------------------------------

$IF LIBXMP64_BI = UNDEFINED THEN
    $LET LIBXMP64_BI = TRUE

    '-------------------------------------------------------------------------------------------------------------------
    ' METACOMMANDS
    '-------------------------------------------------------------------------------------------------------------------
    ' Check QB64-PE compiler version and complain if it does not meet minimum version requirement
    ' We do not support 32-bit versions. There are multiple roadblocks for supporting 32-bit platforms
    '   1. The TYPES below are aligned for x86-64 arch. Padded with extra bytes wherever needed
    '   2. 32-bit machines and OSes are not mainstream anymore
    '   3. I clearly lack the motivation for adding 32-bit support. If anyone wants to do it, then please open a PR!
    $IF VERSION < 3.8 OR 32BIT THEN
            $ERROR This requires the latest 64-bit version of QB64-PE from https://github.com/QB64-Phoenix-Edition/QB64pe/releases/latest
    $END IF
    '-------------------------------------------------------------------------------------------------------------------

    '-------------------------------------------------------------------------------------------------------------------
    ' CONSTANTS
    '-------------------------------------------------------------------------------------------------------------------
    CONST XMP_NAME_SIZE = 64 ' size of module name and type

    CONST XMP_PLAYER_INTERP = 2 ' interpolation type
    CONST XMP_PLAYER_DSP = 3 ' DSP effect flags
    CONST XMP_PLAYER_VOLUME = 7 ' player module volume

    CONST XMP_MAX_CHANNELS = 64 ' max number of channels in module

    CONST XMP_INTERP_SPLINE = 2 ' cubic spline

    CONST XMP_DSP_LOWPASS = 1 ' lowpass filter effect
    CONST XMP_DSP_ALL = XMP_DSP_LOWPASS

    CONST XMP_VOLUME_MAX = 100 ' max volume in percentage

    ' Helper constants. These must be in sync with the types below
    CONST XMP_CHANNEL_INFO_SIZE = 24 ' size of xmp_channel_info type
    CONST XMP_CHANNEL_INFO_ARRAY_SIZE = XMP_CHANNEL_INFO_SIZE * XMP_MAX_CHANNELS

    CONST XMP_SOUND_BUFFER_CHANNELS = 2 ' 2 channel (stereo)
    CONST XMP_SOUND_BUFFER_SAMPLE_SIZE = 2 ' 2 bytes (16-bits signed integer)
    CONST XMP_SOUND_BUFFER_FRAME_SIZE = XMP_SOUND_BUFFER_SAMPLE_SIZE * XMP_SOUND_BUFFER_CHANNELS
    CONST XMP_SOUND_BUFFER_TIME_DEFAULT = 0.2 ' we will check that we have this amount of time left in the QB64 sound pipe
    '-------------------------------------------------------------------------------------------------------------------

    '-------------------------------------------------------------------------------------------------------------------
    ' USER DEFINED TYPES
    '-------------------------------------------------------------------------------------------------------------------
    ' Info type used with xmp_test_module()
    TYPE xmp_test_info
        mod_name AS STRING * XMP_NAME_SIZE ' module title
        mod_type AS STRING * XMP_NAME_SIZE ' module format
    END TYPE

    TYPE xmp_event
        note AS _UNSIGNED _BYTE ' note number (0 means no note)
        ins AS _UNSIGNED _BYTE ' patch number
        vol AS _UNSIGNED _BYTE ' volume (0 to basevol)
        fxt AS _UNSIGNED _BYTE ' effect type
        fxp AS _UNSIGNED _BYTE ' effect parameter
        f2t AS _UNSIGNED _BYTE ' secondary effect type
        f2p AS _UNSIGNED _BYTE ' secondary effect parameter
        __flag AS _UNSIGNED _BYTE ' internal (reserved) flags
    END TYPE

    TYPE xmp_channel_info
        period AS _UNSIGNED LONG ' sample period (* 4096)
        position AS _UNSIGNED LONG ' sample position
        pitchbend AS INTEGER ' linear bend from base note
        note AS _UNSIGNED _BYTE ' current base note number
        instrument AS _UNSIGNED _BYTE ' current instrument number
        sample AS _UNSIGNED _BYTE ' current sample number
        volume AS _UNSIGNED _BYTE ' current volume
        pan AS _UNSIGNED _BYTE ' current stereo pan
        reserved AS _UNSIGNED _BYTE ' reserved
        event AS xmp_event ' current track event
    END TYPE

    ' Info type used with xmp_get_frame_info()
    TYPE xmp_frame_info
        position AS LONG ' current position
        pattern AS LONG ' current pattern
        row AS LONG ' current row in pattern
        num_rows AS LONG ' number of rows in current pattern
        frame AS LONG ' current frame
        speed AS LONG ' current replay speed
        bpm AS LONG ' current bpm
        time AS LONG ' current module time in ms
        total_time AS LONG ' estimated replay time in ms*/
        frame_time AS LONG ' frame replay time in us
        buffer AS _OFFSET ' pointer to sound buffer
        buffer_size AS LONG ' used buffer size
        total_size AS LONG ' total buffer size
        volume AS LONG ' current master volume
        loop_count AS LONG ' loop counter
        virt_channels AS LONG ' number of virtual channels
        virt_used AS LONG ' used virtual channels
        sequence AS LONG ' current sequence
        channel_info AS STRING * XMP_CHANNEL_INFO_ARRAY_SIZE ' current channel information
        __padding AS STRING * 4
    END TYPE

    ' QB64 specific stuff
    TYPE __XMPPlayerType
        context AS _OFFSET ' this is a libxmp context
        isPlaying AS _BYTE ' set to true if tune is playing
        isPaused AS _BYTE ' set to true if tune is paused
        isLooping AS _BYTE ' set to true if tune is looping
        frameInfo AS xmp_frame_info ' current frame info. This is used to check if we are looping or playback is done
        testInfo AS xmp_test_info ' this will have the MOD name and type
        errorCode AS LONG ' this hold the error code from a previous XMP function
        soundBuffer AS _MEM ' this is the buffer that holds the rendered samples from libxmp
        soundBufferBytes AS _UNSIGNED LONG ' size of the render buffer in bytes
        soundBufferFrames AS _UNSIGNED LONG ' size of the render buffer in frames
        soundHandle AS LONG ' the sound pipe that we wll use to play the rendered samples
    END TYPE
    '-------------------------------------------------------------------------------------------------------------------

    '-------------------------------------------------------------------------------------------------------------------
    ' EXTERNAL LIBRARIES
    '-------------------------------------------------------------------------------------------------------------------
    ' HELP NEEDED: macOS support is trivial but missing because I do not own an Apple system to compile a Libxmp .dylib
    $IF WINDOWS THEN
        DECLARE DYNAMIC LIBRARY "libxmp"
        $ELSEIF LINUX THEN
            DECLARE DYNAMIC LIBRARY "xmp" ' QB64 adds the 'lib' prefix on Linux & macOS
        $ELSEIF MACOSX THEN
            $ERROR macOS not supported yet
            DECLARE DYNAMIC LIBRARY "xmp"
        $ELSE
            $ERROR Unknown platform
            DECLARE DYNAMIC LIBRARY "xmp"
        $END IF
        FUNCTION xmp_create_context%&
        SUB xmp_free_context (BYVAL context AS _OFFSET)
        FUNCTION xmp_test_module& (path AS STRING, test_info AS xmp_test_info)
        FUNCTION xmp_test_module_from_memory& (buffer AS STRING, BYVAL size AS _UNSIGNED LONG, test_info AS xmp_test_info)
        FUNCTION xmp_load_module& (BYVAL context AS _OFFSET, path AS STRING)
        FUNCTION xmp_load_module_from_memory& (BYVAL context AS _OFFSET, buffer AS STRING, BYVAL size AS _UNSIGNED LONG)
        SUB xmp_release_module (BYVAL context AS _OFFSET)
        FUNCTION xmp_start_player& (BYVAL context AS _OFFSET, BYVAL rate AS LONG, BYVAL format AS LONG)
        SUB xmp_end_player (BYVAL context AS _OFFSET)
        FUNCTION xmp_play_buffer& (BYVAL context AS _OFFSET, BYVAL buffer AS _OFFSET, BYVAL size AS LONG, BYVAL loops AS LONG)
        SUB xmp_get_frame_info (BYVAL context AS _OFFSET, frame_info AS xmp_frame_info)
        FUNCTION xmp_get_player& (BYVAL context AS _OFFSET, BYVAL param AS LONG)
        FUNCTION xmp_set_player& (BYVAL context AS _OFFSET, BYVAL param AS LONG, BYVAL value AS LONG)
        FUNCTION xmp_next_position& (BYVAL context AS _OFFSET)
        FUNCTION xmp_prev_position& (BYVAL context AS _OFFSET)
        FUNCTION xmp_set_position& (BYVAL context AS _OFFSET, BYVAL posi AS LONG)
        SUB xmp_restart_module (BYVAL context AS _OFFSET)
        FUNCTION xmp_seek_time& (BYVAL context AS _OFFSET, BYVAL msecs AS LONG)
    END DECLARE
    '-------------------------------------------------------------------------------------------------------------------

    '-------------------------------------------------------------------------------------------------------------------
    ' GLOBAL VARIABLES
    '-------------------------------------------------------------------------------------------------------------------
    DIM __XMPPlayer AS __XMPPlayerType
    '-------------------------------------------------------------------------------------------------------------------
$END IF
'-----------------------------------------------------------------------------------------------------------------------
