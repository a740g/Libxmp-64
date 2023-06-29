'-----------------------------------------------------------------------------------------------------------------------
' Libxmp bindings for QB64-PE (minimalistic)
' Copyright (c) 2023 Samuel Gomes
'
' This mostly has the glue code that make working with Libxmp and QB64-PE easy
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'Libxmp64.bi'
'-----------------------------------------------------------------------------------------------------------------------

$IF LIBXMP64_BAS = UNDEFINED THEN
    $LET LIBXMP64_BAS = TRUE
    '-------------------------------------------------------------------------------------------------------------------
    ' FUNCTIONS & SUBROUTINES
    '-------------------------------------------------------------------------------------------------------------------
    ' Rounds a number down to a power of 2 (this time the non-noobie way :)
    FUNCTION __XMP_RoundDownToPowerOf2~& (i AS _UNSIGNED LONG)
        DIM j AS _UNSIGNED LONG
        j = i
        j = j OR _SHR(j, 1)
        j = j OR _SHR(j, 2)
        j = j OR _SHR(j, 4)
        j = j OR _SHR(j, 8)
        j = j OR _SHR(j, 16)
        __XMP_RoundDownToPowerOf2 = j - _SHR(j, 1)
    END FUNCTION


    ' Returns a BASIC string (bstring) from NULL terminated C string (cstring)
    FUNCTION __XMP_ToBString$ (s AS STRING)
        DIM zeroPos AS LONG: zeroPos = INSTR(s, CHR$(0))
        IF zeroPos > 0 THEN __XMP_ToBString = LEFT$(s, zeroPos - 1) ELSE __XMP_ToBString = s
    END FUNCTION


    ' This an internal fuction and should be called right after the module is loaded
    ' These are things that are common after loading a module
    FUNCTION __XMP_DoPostInit%%
        SHARED __XMPPlayer AS __XMPPlayerType

        ' Exit if module loading failed
        IF __XMPPlayer.errorCode <> 0 THEN
            ' Free the context
            xmp_free_context __XMPPlayer.context
            __XMPPlayer.context = 0
            EXIT FUNCTION
        END IF

        ' Initialize the player
        __XMPPlayer.errorCode = xmp_start_player(__XMPPlayer.context, _SNDRATE, 0)

        ' Exit if starting player failed
        IF __XMPPlayer.errorCode <> 0 THEN
            xmp_release_module __XMPPlayer.context
            xmp_free_context __XMPPlayer.context
            __XMPPlayer.context = 0
            EXIT FUNCTION
        END IF

        ' Allocate the mixer buffer
        __XMPPlayer.soundBufferFrames = __XMP_RoundDownToPowerOf2(_SNDRATE * XMP_SOUND_BUFFER_TIME_DEFAULT * XMP_SOUND_BUFFER_TIME_DEFAULT) ' 40 ms buffer round down to power of 2
        __XMPPlayer.soundBufferBytes = __XMPPlayer.soundBufferFrames * XMP_SOUND_BUFFER_FRAME_SIZE ' power of 2 above is required by most FFT functions
        __XMPPlayer.soundBuffer = _MEMNEW(__XMPPlayer.soundBufferBytes)

        ' Exit if memory was not allocated
        IF __XMPPlayer.soundBuffer.SIZE = 0 THEN
            xmp_end_player __XMPPlayer.context
            xmp_release_module __XMPPlayer.context
            xmp_free_context __XMPPlayer.context
            __XMPPlayer.context = 0
            EXIT FUNCTION
        END IF

        ' Set some player properties
        ' These makes the sound quality much better when devices have sample rates other than 44100
        __XMPPlayer.errorCode = xmp_set_player(__XMPPlayer.context, XMP_PLAYER_INTERP, XMP_INTERP_SPLINE)
        __XMPPlayer.errorCode = xmp_set_player(__XMPPlayer.context, XMP_PLAYER_DSP, XMP_DSP_ALL)

        ' Allocate a sound pipe
        __XMPPlayer.soundHandle = _SNDOPENRAW

        ' Exit if failed to allocate sound handle
        IF __XMPPlayer.soundHandle < 1 THEN
            _MEMFREE __XMPPlayer.soundBuffer
            xmp_end_player __XMPPlayer.context
            xmp_release_module __XMPPlayer.context
            xmp_free_context __XMPPlayer.context
            __XMPPlayer.context = 0
            EXIT FUNCTION
        END IF

        ' Get the frame information
        xmp_get_frame_info __XMPPlayer.context, __XMPPlayer.frameInfo

        ' Set default player state
        __XMPPlayer.isPlaying = 0
        __XMPPlayer.isLooping = 0
        __XMPPlayer.isPaused = __XMPPlayer.context <> 0 ' true

        __XMP_DoPostInit = __XMPPlayer.context <> 0 ' true
    END FUNCTION


    ' Loads the MOD tune from a file and prepares all required gobals
    FUNCTION XMP_LoadTuneFromFile%% (fileName AS STRING)
        SHARED __XMPPlayer AS __XMPPlayerType

        ' Check if the file exists
        IF NOT _FILEEXISTS(fileName) THEN EXIT FUNCTION

        ' If a song is already loaded then unload and free resources
        IF __XMPPlayer.context <> 0 THEN XMP_Stop

        ' Check if the file is a valid module music
        __XMPPlayer.errorCode = xmp_test_module(fileName + CHR$(0), __XMPPlayer.testInfo)
        IF __XMPPlayer.errorCode <> 0 THEN EXIT FUNCTION

        ' Initialize the player
        __XMPPlayer.context = xmp_create_context

        ' Exit if context creation failed
        IF __XMPPlayer.context = 0 THEN EXIT FUNCTION

        ' Load the module file
        __XMPPlayer.errorCode = xmp_load_module(__XMPPlayer.context, fileName + CHR$(0))

        XMP_LoadTuneFromFile = __XMP_DoPostInit
    END FUNCTION


    ' Loads the MOD tune from a memory and prepares all required gobals
    FUNCTION XMP_LoadTuneFromMemory%% (buffer AS STRING)
        SHARED __XMPPlayer AS __XMPPlayerType
        ' Check if the buffer is empty
        IF LEN(buffer) = 0 THEN EXIT FUNCTION

        ' If a song is already loaded then unload and free resources
        IF __XMPPlayer.context <> 0 THEN XMP_Stop

        ' Check if the file is a valid module music
        __XMPPlayer.errorCode = xmp_test_module_from_memory(buffer, LEN(buffer), __XMPPlayer.testInfo)
        IF __XMPPlayer.errorCode <> 0 THEN EXIT FUNCTION

        ' Initialize the player
        __XMPPlayer.context = xmp_create_context

        ' Exit if context creation failed
        IF __XMPPlayer.context = 0 THEN EXIT FUNCTION

        ' Load the module file
        __XMPPlayer.errorCode = xmp_load_module_from_memory(__XMPPlayer.context, buffer, LEN(buffer))

        XMP_LoadTuneFromMemory = __XMP_DoPostInit
    END FUNCTION


    ' Return the name of the tune
    FUNCTION XMP_GetTuneName$
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 THEN
            XMP_GetTuneName = _TRIM$(__XMP_ToBString(__XMPPlayer.testInfo.mod_name))
        END IF
    END FUNCTION


    ' Returns the tune format
    FUNCTION XMP_GetTuneType$
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 THEN
            XMP_GetTuneType = _TRIM$(__XMP_ToBString(__XMPPlayer.testInfo.mod_type))
        END IF
    END FUNCTION


    ' Kickstarts playback
    SUB XMP_Play
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 THEN
            __XMPPlayer.isPaused = 0 ' false
            __XMPPlayer.isPlaying = (__XMPPlayer.context <> 0) ' true
        END IF
    END SUB


    ' Stops the player and frees all allocated resources
    SUB XMP_Stop
        SHARED __XMPPlayer AS __XMPPlayerType

        ' Free the player and loaded module
        IF __XMPPlayer.context <> 0 THEN
            ' Set default player state
            __XMPPlayer.isPlaying = 0
            __XMPPlayer.isLooping = 0
            __XMPPlayer.isPaused = __XMPPlayer.context <> 0 ' true

            ' Free the sound pipe
            _SNDRAWDONE __XMPPlayer.soundHandle ' Sumbit whatever is remaining in the raw buffer for playback
            _SNDCLOSE __XMPPlayer.soundHandle ' Close QB64 sound pipe

            ' Free the mixer buffer
            _MEMFREE __XMPPlayer.soundBuffer

            ' Cleanup XMP
            xmp_end_player __XMPPlayer.context
            xmp_release_module __XMPPlayer.context
            xmp_free_context __XMPPlayer.context
            __XMPPlayer.context = 0
        END IF
    END SUB


    ' Restarts playback
    SUB XMP_Replay
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 AND __XMPPlayer.isPlaying AND NOT __XMPPlayer.isPaused THEN
            xmp_restart_module __XMPPlayer.context
        END IF
    END SUB


    ' Jumps to the next position
    SUB XMP_GoToNextPosition
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 AND __XMPPlayer.isPlaying AND NOT __XMPPlayer.isPaused THEN
            __XMPPlayer.errorCode = xmp_next_position&(__XMPPlayer.context)
        END IF
    END SUB


    ' Jumps to the previous position
    SUB XMP_GoToPreviousPosition
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 AND __XMPPlayer.isPlaying AND NOT __XMPPlayer.isPaused THEN
            __XMPPlayer.errorCode = xmp_prev_position&(__XMPPlayer.context)
        END IF
    END SUB


    ' Just to a specific position
    SUB XMP_SetPosition (position AS LONG)
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 AND __XMPPlayer.isPlaying AND NOT __XMPPlayer.isPaused THEN
            __XMPPlayer.errorCode = xmp_set_position&(__XMPPlayer.context, position)
        END IF
    END SUB


    ' Just to a specific time
    SUB XMP_SeekToTime (timeMs AS LONG)
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 AND __XMPPlayer.isPlaying AND NOT __XMPPlayer.isPaused THEN
            __XMPPlayer.errorCode = xmp_seek_time&(__XMPPlayer.context, timeMs)
        END IF
    END SUB


    ' This handles playback and keeping track of the render buffer
    ' You can call this as frequenctly as you want. The routine will simply exit if nothing is to be done
    SUB XMP_Update (bufferTimeSecs AS SINGLE)
        SHARED __XMPPlayer AS __XMPPlayerType

        ' If song is done, paused or we already have enough samples to play then exit
        IF __XMPPlayer.context = 0 OR NOT __XMPPlayer.isPlaying OR __XMPPlayer.isPaused OR _SNDRAWLEN(__XMPPlayer.soundHandle) > bufferTimeSecs THEN EXIT SUB

        ' Clear the render buffer
        _MEMFILL __XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET, __XMPPlayer.soundBufferBytes, 0 AS _BYTE

        ' Render some samples to the buffer
        __XMPPlayer.errorCode = xmp_play_buffer(__XMPPlayer.context, __XMPPlayer.soundBuffer.OFFSET, __XMPPlayer.soundBufferBytes, 0)

        ' Get the frame information
        xmp_get_frame_info __XMPPlayer.context, __XMPPlayer.frameInfo

        ' Set playing flag to false if we are not looping and loop count > 0
        IF __XMPPlayer.isLooping THEN
            __XMPPlayer.isPlaying = __XMPPlayer.isLooping
        ELSE
            __XMPPlayer.isPlaying = (__XMPPlayer.frameInfo.loop_count < 1)
            ' Exit before any samples are queued
            IF NOT __XMPPlayer.isPlaying THEN EXIT SUB
        END IF

        ' Push the samples to the sound pipe
        DIM i AS _UNSIGNED LONG
        FOR i = 0 TO __XMPPlayer.soundBufferBytes - XMP_SOUND_BUFFER_SAMPLE_SIZE STEP XMP_SOUND_BUFFER_FRAME_SIZE
            _SNDRAW _MEMGET(__XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET + i, INTEGER) / 32768!, _MEMGET(__XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET + i + XMP_SOUND_BUFFER_SAMPLE_SIZE, INTEGER) / 32768!, __XMPPlayer.soundHandle
        NEXT
    END SUB


    ' Sets the master volume (0 - 100)
    SUB XMP_SetVolume (volume AS LONG)
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 AND __XMPPlayer.isPlaying THEN
            IF volume < 0 THEN
                __XMPPlayer.errorCode = xmp_set_player(__XMPPlayer.context, XMP_PLAYER_VOLUME, 0)
            ELSEIF volume > 100 THEN
                __XMPPlayer.errorCode = xmp_set_player(__XMPPlayer.context, XMP_PLAYER_VOLUME, 100)
            ELSE
                __XMPPlayer.errorCode = xmp_set_player(__XMPPlayer.context, XMP_PLAYER_VOLUME, volume)
            END IF
        END IF
    END SUB


    ' Gets the master volume
    FUNCTION XMP_GetVolume&
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 AND __XMPPlayer.isPlaying THEN
            XMP_GetVolume = xmp_get_player(__XMPPlayer.context, XMP_PLAYER_VOLUME)
        END IF
    END FUNCTION


    ' Pauses / unpauses playback
    SUB XMP_Pause (state AS _BYTE)
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 THEN
            __XMPPlayer.isPaused = state <> 0
        END IF
    END SUB


    ' Returns true if player is paused
    FUNCTION XMP_IsPaused%%
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 THEN
            XMP_IsPaused = __XMPPlayer.isPaused
        END IF
    END FUNCTION


    ' Enables / disables playback looping
    SUB XMP_Loop (state AS _BYTE)
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 THEN
            __XMPPlayer.isLooping = state <> 0
        END IF
    END SUB


    ' Returns true if playback is looping
    FUNCTION XMP_IsLooping%%
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 THEN
            XMP_IsLooping = __XMPPlayer.isLooping
        END IF
    END FUNCTION


    ' Returns true if music is playing
    FUNCTION XMP_IsPlaying%%
        SHARED __XMPPlayer AS __XMPPlayerType

        IF __XMPPlayer.context <> 0 THEN
            XMP_IsPlaying = __XMPPlayer.isPlaying
        END IF
    END FUNCTION
    '-------------------------------------------------------------------------------------------------------------------
$END IF
'-----------------------------------------------------------------------------------------------------------------------
